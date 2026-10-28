# Run in an elevated Windows PowerShell 5.1 or PowerShell 7 process.
# All installed files, source fixtures, and backups stay in a temporary directory.
$ErrorActionPreference = 'Stop'
$root = Join-Path ([IO.Path]::GetTempPath()) ('environment-test-' + [guid]::NewGuid())
$source = Split-Path -Parent $PSScriptRoot
$repo = Join-Path $root ("repo with spaces [test] 'quote'" + [char]0x2019)
$powershell = (Get-Process -Id $PID).Path
$savedEnv = @{}
foreach ($name in 'USERPROFILE', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'NVIM_APPNAME') {
    $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name)
}

function Assert($Condition, $Message) {
    if (-not $Condition) { throw $Message }
}

function Run-Installer([string[]]$Arguments, [int]$ExpectedCode = 0) {
    # Native stderr is expected for invalid selections; inspect the exit code ourselves.
    $ErrorActionPreference = 'Continue'
    $output = & $powershell -NoProfile -ExecutionPolicy Bypass -File $installer @Arguments 2>&1
    Assert ($LASTEXITCODE -eq $ExpectedCode) "Installer exit $LASTEXITCODE, expected $ExpectedCode`: $output"
    return $output -join "`n"
}

function Read-Jsonc($Path) {
    [regex]::Replace([IO.File]::ReadAllText($Path), '(?m)^\s*//.*$', '') | ConvertFrom-Json
}

try {
    [void][IO.Directory]::CreateDirectory($repo)
    foreach ($name in 'install.ps1', '.config', 'agents') {
        Copy-Item -LiteralPath (Join-Path $source $name) -Destination $repo -Recurse
    }
    $installer = Join-Path $repo 'install.ps1'
    $env:USERPROFILE = Join-Path $root "user [test] 'quote'"
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
    $env:XDG_CONFIG_HOME = ''; $env:XDG_STATE_HOME = ''; $env:NVIM_APPNAME = ''
    $nvim = Join-Path $env:LOCALAPPDATA 'nvim'
    $config = Join-Path $env:USERPROFILE '.config/opencode/opencode.jsonc'
    $shared = Join-Path $env:USERPROFILE '.agents/skills/audit-for-simplicity'
    $claude = Join-Path $env:USERPROFILE '.claude/skills/audit-for-simplicity'
    $backups = Join-Path $env:USERPROFILE '.environment-backups'
    $original = (Get-FileHash -LiteralPath (Join-Path $repo '.config/nvim/init.lua')).Hash

    $plan = Run-Installer @('-Profile', 'work', '-DryRun')
    Assert ($plan -match 'DRY RUN' -and $plan -notmatch '\[tmux\]') 'Wrong Windows plan'
    Run-Installer @('-Only', 'opencode,opencode2', '-DryRun') 1 | Out-Null
    Run-Installer @('-Only', 'tmux', '-DryRun') 1 | Out-Null
    Run-Installer @('-Copy', '-Link', '-DryRun') 1 | Out-Null
    Run-Installer @('-List', '-Skip', 'nvim-ai') | Out-Null
    $created = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Recurse -Force -ErrorAction SilentlyContinue)
    Assert (-not (Test-Path -LiteralPath $env:USERPROFILE)) "Read-only commands wrote files: $($created.FullName -join ', ')"

    Run-Installer @('-Profile', 'personal', '-Copy', '-Yes') | Out-Null
    Assert ((Get-Item -LiteralPath $claude).LinkType -eq 'Junction') 'Copy mode must use Claude junctions'
    Assert ((Get-FileHash -LiteralPath (Join-Path $nvim 'init.lua')).Hash -eq $original) 'Wrong Neovim config'
    Assert ((Run-Installer @('-Copy', '-Yes')) -match 'done - 0 change\(s\)') 'Copy rerun changed files'

    # Back up a modified file and a directory containing a junction without touching its target.
    $protected = Join-Path $root 'protected'
    [void][IO.Directory]::CreateDirectory($protected)
    [IO.File]::WriteAllText((Join-Path $protected 'keep.txt'), 'keep')
    [IO.File]::WriteAllText((Join-Path $nvim 'init.lua'), '-- local edit')
    New-Item -ItemType Junction -Path (Join-Path $shared 'nested') -Value $protected | Out-Null
    Run-Installer @('-Link', '-Yes') | Out-Null
    Assert ((Get-Item -LiteralPath (Join-Path $nvim 'init.lua')).LinkType -eq 'SymbolicLink') 'Missing file symlink'
    Assert ((Get-Item -LiteralPath $shared).LinkType -eq 'SymbolicLink') 'Missing skill symlink'
    Assert ((Get-Item -LiteralPath $claude).LinkType -eq 'SymbolicLink') 'Missing Claude symlink'
    $backup = @(Get-ChildItem -LiteralPath $backups -Directory)[0].FullName
    Assert ([IO.File]::ReadAllText((Join-Path $backup 'AppData/Local/nvim/init.lua')) -eq '-- local edit') 'Backup lost local edit'
    Assert ((Run-Installer @('-Yes')) -match 'done - 0 change\(s\)') 'Link rerun changed files'

    # Replace a dangling link, then convert everything back to self-contained copies.
    $dangling = Join-Path $root 'missing.lua'
    [IO.File]::WriteAllText($dangling, '-- temporary')
    (Get-Item -LiteralPath (Join-Path $nvim 'init.lua')).Delete()
    New-Item -ItemType SymbolicLink -Path (Join-Path $nvim 'init.lua') -Value $dangling | Out-Null
    [IO.File]::Delete($dangling)
    Run-Installer @('-Only', 'nvim', '-Yes') | Out-Null
    Run-Installer @('-Copy', '-Yes') | Out-Null
    Assert (-not (Get-Item -LiteralPath (Join-Path $nvim 'init.lua')).LinkType) 'Copy wrote through a link'
    Assert ((Get-FileHash -LiteralPath (Join-Path $repo '.config/nvim/init.lua')).Hash -eq $original) 'Source config was overwritten'
    Assert ((Get-Item -LiteralPath $claude).LinkType -eq 'Junction') 'Symlink was not converted to junction'

    # A pre-existing whole-config junction must not cause writes into the source checkout.
    [IO.Directory]::Delete($nvim, $true)
    New-Item -ItemType Junction -Path $nvim -Value (Join-Path $repo '.config/nvim') | Out-Null
    Run-Installer @('-Only', 'nvim', '-Yes') 1 | Out-Null
    Assert ((Get-FileHash -LiteralPath (Join-Path $repo '.config/nvim/init.lua')).Hash -eq $original) 'Linked parent damaged the source'
    (Get-Item -LiteralPath $nvim).Delete()
    Run-Installer @('-Only', 'nvim', '-Copy', '-Yes') | Out-Null

    # Exercise recursive merging and ordered V2 permission-array concatenation.
    $overlayPath = Join-Path $repo '.config/opencode2/work.jsonc'
    $overlay = Read-Jsonc $overlayPath
    $overlay.agents | Add-Member -NotePropertyName plan -NotePropertyValue ([pscustomobject]@{
        permissions = @([pscustomobject]@{ action = 'shell'; resource = 'test-command'; effect = 'ask' })
    })
    [IO.File]::WriteAllText($overlayPath, ($overlay | ConvertTo-Json -Depth 100))
    Run-Installer @('-Profile', 'work', '-Only', 'opencode2', '-Yes') | Out-Null
    $merged = Read-Jsonc $config
    $base = Read-Jsonc (Join-Path $repo '.config/opencode2/base.jsonc')
    Assert ($merged.permissions.Count -eq $base.permissions.Count + $overlay.permissions.Count) 'V2 rules were replaced'
    Assert ($merged.agents.plan.permissions[0].effect -eq 'deny') 'Inherited agent rule missing'
    Assert ($merged.agents.plan.permissions[-1].resource -eq 'test-command') 'Agent rule was not appended'
    Assert ($merged.providers.'amazon-bedrock'.settings.region -eq 'us-west-2') 'Work provider missing'
    Assert ((Run-Installer @('-Only', 'opencode2', '-Yes')) -match 'done - 0 change\(s\)') 'Generated config rerun changed files'
    [IO.File]::AppendAllText($config, "`n// hand edit")
    Assert ((Run-Installer @('-Only', 'opencode2', '-Yes')) -match 'hand-edited') 'Hand edit was not detected'
    $v1 = Run-Installer @('-Render', 'opencode', '-Profile', 'work')
    # jq is available on the Windows CI runner and independently checks case-sensitive keys.
    $v1 = [regex]::Replace($v1, '(?m)^\s*//.*$', '')
    $query = Join-Path $root 'check.jq'
    [IO.File]::WriteAllText($query, '.permission.bash["git status *"], .provider["amazon-bedrock"].options.region, (.permission.bash | has("git branch -d*") and has("git branch -D*"))')
    $values = @($v1 | jq -r -f $query)
    Assert ($LASTEXITCODE -eq 0 -and ($values -join ',') -eq 'allow,us-west-2,true') 'V1 merge or case-sensitive keys failed'

    # Pruning must not follow a junction in an old backup or remove unrelated directories.
    foreach ($day in 1..6) {
        $old = Join-Path $backups ('200001{0:00}-000000' -f $day)
        [void][IO.Directory]::CreateDirectory($old)
        New-Item -ItemType Junction -Path (Join-Path $old 'nested') -Value $protected | Out-Null
    }
    [void][IO.Directory]::CreateDirectory((Join-Path $backups 'keep'))
    Run-Installer @('-Profile', 'work', '-Only', 'nvim', '-Copy', '-Yes') | Out-Null
    Assert (@(Get-ChildItem -LiteralPath $backups -Directory | Where-Object { $_.Name -match '^\d{8}-' }).Count -eq 5) 'Backup retention failed'
    Assert (Test-Path -LiteralPath (Join-Path $backups 'keep')) 'Pruned unrelated directory'
    Assert ([IO.File]::ReadAllText((Join-Path $protected 'keep.txt')) -eq 'keep') 'Pruning traversed junction target'

    # Skills dependency and alternate native config roots.
    $env:USERPROFILE = Join-Path $root 'other-user'
    $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
    $env:XDG_CONFIG_HOME = Join-Path $env:USERPROFILE 'config'
    $env:XDG_STATE_HOME = Join-Path $env:USERPROFILE 'state'
    $env:NVIM_APPNAME = 'custom-nvim'
    Run-Installer @('-Only', 'claude-skills,nvim,opencode2', '-Copy', '-Yes') | Out-Null
    Assert (Test-Path -LiteralPath (Join-Path $env:XDG_CONFIG_HOME 'custom-nvim/init.lua')) 'NVIM_APPNAME/XDG path ignored'
    Assert (Test-Path -LiteralPath (Join-Path $env:USERPROFILE '.agents/skills/audit-for-simplicity/SKILL.md')) 'Skill dependency missing'
    Assert (Test-Path -LiteralPath (Join-Path $env:XDG_STATE_HOME 'environment/profile')) 'State path ignored'

    # Exercise the actual elevation handoff without opening a UAC dialog in CI.
    & {
        . $installer -Only nvim,nvim-ai -Profile work -List -Yes
        function Start-Process {
            param($FilePath, $Verb, [switch]$Wait, [switch]$PassThru, $ArgumentList)
            Assert ($Verb -eq 'RunAs' -and $Wait -and $PassThru) 'Wrong elevation invocation'
            $encoded = ($ArgumentList -split ' ')[-1]
            $command = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
            $tokens = $null; $errors = $null
            [void][Management.Automation.Language.Parser]::ParseInput($command, [ref]$tokens, [ref]$errors)
            Assert (-not $errors) 'Elevation command quoting is invalid'
            Assert ($command.Contains("-Only 'nvim,nvim-ai' -Link -Yes")) 'Elevation lost selected options'
            Assert ($command.Contains((Quote-PowerShell $env:XDG_CONFIG_HOME))) 'Elevation lost original paths'
            return [pscustomobject]@{ ExitCode = 0 }
        }
        Invoke-Elevated
        function Start-Process { throw 'UAC cancelled' }
        $cancelled = $false
        try { Invoke-Elevated } catch { $cancelled = $_.Exception.Message -match 'cancelled' }
        Assert $cancelled 'Elevation cancellation was swallowed'
    }
    Write-Host "PASS: Windows installer ($($PSVersionTable.PSVersion))"
} finally {
    foreach ($name in $savedEnv.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name]) }
    if (Test-Path -LiteralPath $root) { [IO.Directory]::Delete($root, $true) }
}
