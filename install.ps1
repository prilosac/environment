#requires -Version 5.1
<#
.SYNOPSIS
Install environment configs for native Windows. WSL should use install.sh.
.EXAMPLE
.\install.ps1 -Profile personal -Yes
.EXAMPLE
.\install.ps1 -Only nvim,nvim-ai -Copy -DryRun
.EXAMPLE
.\install.ps1 -Render opencode2 -Profile work
#>
[CmdletBinding()]
param(
    [ValidateSet('personal', 'work')][string]$Profile,
    [string[]]$Only = @(),
    [string[]]$Skip = @(),
    [switch]$DryRun,
    [switch]$Copy,
    [switch]$Link,
    [switch]$Yes,
    [switch]$List,
    [ValidateSet('opencode', 'opencode2')][string]$Render
)

$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Use install.sh on Linux/macOS/WSL.' }
$RepoDir = $PSScriptRoot
$UserHome = $env:USERPROFILE
$LocalAppData = $env:LOCALAPPDATA
$ConfigHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $UserHome '.config' }
$StateHome = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { $LocalAppData }
$StateDir = Join-Path $StateHome 'environment'
$NvimHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { $LocalAppData }
$NvimName = if ($env:NVIM_APPNAME) { $env:NVIM_APPNAME } else { 'nvim' }
$NvimDir = Join-Path $NvimHome $NvimName
$OpenCodeDir = Join-Path $ConfigHome 'opencode'
$BackupRoot = Join-Path $UserHome '.environment-backups'
$BackupDir = Join-Path $BackupRoot (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
$Mode = if ($Copy) { 'Copy' } else { 'SymbolicLink' }
$CanPrompt = -not $Yes -and -not $DryRun -and -not [Console]::IsInputRedirected
$Modules = [ordered]@{
    'nvim' = 'Neovim core config + environment overrides'
    'nvim-ai' = 'Neovim AI plugins (Copilot)'
    'opencode' = 'OpenCode 1 config'
    'opencode2' = 'OpenCode 2 config + terminal settings'
    'agents-skills' = 'Shared agent skills'
    'claude-skills' = 'Claude skill links to shared skills'
}
$Defaults = @('nvim', 'nvim-ai', 'opencode2', 'agents-skills', 'claude-skills')
$Changed = 0
$Unchanged = 0
$Backups = 0

function Write-Record($Status, $Destination, $Detail = '') {
    if ($Status -eq 'unchanged') { $script:Unchanged++ }
    elseif ($Status -ne 'backup') { $script:Changed++ }
    Write-Host ('  {0,-10} {1} {2}' -f $Status, $Destination, $Detail)
}

function New-Directory($Path) {
    [void][IO.Directory]::CreateDirectory($Path)
}

function Get-InstalledItem($Path) {
    Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Test-Link($Item) {
    $null -ne $Item -and $Item.LinkType -in 'SymbolicLink', 'Junction'
}

function Test-SameContent($Source, $Destination) {
    $src = Get-Item -LiteralPath $Source -Force
    $dest = Get-InstalledItem $Destination
    if (-not $dest -or (Test-Link $dest) -or $src.PSIsContainer -ne $dest.PSIsContainer) { return $false }
    if (-not $src.PSIsContainer) {
        return $src.Length -eq $dest.Length -and
            (Get-FileHash -LiteralPath $Source).Hash -eq (Get-FileHash -LiteralPath $Destination).Hash
    }
    $children = @(Get-ChildItem -LiteralPath $Source -Force)
    if ($children.Count -ne @(Get-ChildItem -LiteralPath $Destination -Force).Count) { return $false }
    foreach ($child in $children) {
        if (-not (Test-SameContent $child.FullName (Join-Path $Destination $child.Name))) { return $false }
    }
    return $true
}

function Backup-Item($Path) {
    $relative = if ($Path.StartsWith($UserHome.TrimEnd('\') + '\', [StringComparison]::OrdinalIgnoreCase)) {
        $Path.Substring($UserHome.TrimEnd('\').Length + 1)
    } else {
        Join-Path 'external' ($Path.Replace(':', '').TrimStart('\', '/'))
    }
    $backup = Join-Path $BackupDir $relative
    Write-Record 'backup' $Path "-> $backup"
    if (-not $DryRun) {
        New-Directory (Split-Path -Parent $backup)
        # Moving preserves directory contents and nested links without traversing them.
        Move-Item -LiteralPath $Path -Destination $backup
    }
    $script:Backups++
    if ($Backups -eq 1) {
        $old = @(Get-ChildItem -LiteralPath $BackupRoot -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{8}-\d{6}(-\d{3})?$' -and $_.FullName -ne $BackupDir -and -not (Test-Link $_) } |
            Sort-Object Name -Descending | Select-Object -Skip 4)
        foreach ($dir in $old) {
            Write-Record 'prune' $dir.FullName '(keeping 5 most recent backups)'
            if (-not $DryRun) { Remove-Tree $dir.FullName }
        }
    }
}

# Recursive Directory.Delete can mistake junctions for volume mount points on older .NET.
# Delete each link directly, without traversing its target.
function Remove-Tree($Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        foreach ($child in Get-ChildItem -LiteralPath $Path -Force) { Remove-Tree $child.FullName }
    }
    $item.Delete()
}

function Prepare-Destination($Destination) {
    for ($parent = Split-Path -Parent $Destination; $parent; $parent = Split-Path -Parent $parent) {
        if (Test-Link (Get-InstalledItem $parent)) {
            throw "Cannot replace files through linked directory '$parent'. Replace that directory link with a real directory first."
        }
    }
    $item = Get-InstalledItem $Destination
    if (Test-Link $item) {
        if (-not $DryRun) { $item.Delete() }
    } elseif ($item) {
        Backup-Item $Destination
    }
    if (-not $DryRun) { New-Directory (Split-Path -Parent $Destination) }
}

function New-Link($Source, $Destination, $Kind) {
    # Older New-Item versions treat link targets as wildcards. mklink uses literal paths.
    $flag = if ($Kind -eq 'Junction') { '/J' } elseif ([IO.Directory]::Exists($Source)) { '/D' } else { '' }
    $info = [Diagnostics.ProcessStartInfo]::new($env:ComSpec)
    $info.UseShellExecute = $false
    $info.RedirectStandardOutput = $true
    # Expand paths once from the child environment, keeping %, &, and ! literal.
    $info.EnvironmentVariables['ENVIRONMENT_LINK'] = $Destination
    $info.EnvironmentVariables['ENVIRONMENT_TARGET'] = $Source
    $info.Arguments = '/d /v:off /c mklink ' + $flag + ' "%ENVIRONMENT_LINK%" "%ENVIRONMENT_TARGET%"'
    $process = [Diagnostics.Process]::Start($info)
    try {
        [void]$process.StandardOutput.ReadToEnd()
        $process.WaitForExit()
        if ($process.ExitCode -ne 0) { throw "Could not create $Kind at '$Destination'." }
    } finally { $process.Dispose() }
}

function Install-Path($Source, $Destination, $Kind = $Mode) {
    if ($Source -eq $Destination) { throw "Source and destination are the same: $Source" }
    $item = Get-InstalledItem $Destination
    $same = if ($Kind -eq 'Copy') {
        Test-SameContent $Source $Destination
    } else {
        (Test-Link $item) -and $item.LinkType -eq $Kind -and @($item.Target)[0] -eq $Source
    }
    if ($same) { Write-Record 'unchanged' $Destination; return }
    Prepare-Destination $Destination
    if (-not $DryRun) {
        if ($Kind -eq 'Copy') {
            Copy-Item -LiteralPath $Source -Destination $Destination -Recurse -Force
        } else {
            New-Link $Source $Destination $Kind
        }
    }
    Write-Record $Kind.ToLowerInvariant() $Destination "<- $Source"
}

function Write-Utf8($Path, $Content) {
    New-Directory (Split-Path -Parent $Path)
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
}

function Read-Jsonc($Path) {
    $json = [regex]::Replace([IO.File]::ReadAllText($Path), '(?m)^\s*//.*$', '')
    # V1 has distinct keys such as "git branch -d*" and "git branch -D*".
    # PSCustomObject cannot represent both. Use case-sensitive dictionaries.
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return ConvertFrom-Json -InputObject $json -AsHashtable
    }
    Add-Type -AssemblyName System.Web.Extensions
    return ,([Web.Script.Serialization.JavaScriptSerializer]::new().DeserializeObject($json))
}

function Merge-Json($Base, $Overlay) {
    foreach ($name in $Overlay.Keys) {
        if ($Base[$name] -is [Collections.IDictionary] -and $Overlay[$name] -is [Collections.IDictionary]) {
            Merge-Json $Base[$name] $Overlay[$name]
        } else {
            $Base[$name] = $Overlay[$name]
        }
    }
}

function Render-OpenCode($Version) {
    $basePath = Join-Path $RepoDir ".config/$Version/base.jsonc"
    if ($Profile -eq 'personal') { return [IO.File]::ReadAllText($basePath) }
    $base = Read-Jsonc $basePath
    $overlay = Read-Jsonc (Join-Path $RepoDir ".config/$Version/work.jsonc")
    if ($Version -eq 'opencode2') {
        # V2 permission arrays append; other arrays replace, as in install.sh.
        $permissions = @(@($base.permissions) + @($overlay.permissions) | Where-Object { $null -ne $_ })
        $overlay['permissions'] = $permissions
        foreach ($name in $overlay.agents.Keys) {
            $original = if ($base.agents) { $base.agents[$name] }
            if ($null -ne $original.permissions -and $null -ne $overlay.agents[$name].permissions) {
                $overlay.agents[$name]['permissions'] = @($original.permissions) + @($overlay.agents[$name].permissions)
            }
        }
    }
    Merge-Json $base $overlay
    return "// GENERATED by environment/install.ps1 from base.jsonc + work.jsonc`n" +
        "// Edit those files in the environment repo, not this one.`n" +
        ($base | ConvertTo-Json -Depth 100) + "`n"
}

function Install-OpenCode($Version) {
    $dest = Join-Path $OpenCodeDir 'opencode.jsonc'
    if ($Profile -eq 'personal') {
        Install-Path (Join-Path $RepoDir ".config/$Version/base.jsonc") $dest
    } else {
        $content = Render-OpenCode $Version
        $last = Join-Path $StateDir "rendered-$Version.jsonc"
        $item = Get-InstalledItem $dest
        if ($item -and -not (Test-Link $item) -and -not $item.PSIsContainer -and [IO.File]::ReadAllText($dest) -ceq $content) {
            Write-Record 'unchanged' $dest
        } else {
            if ($item -and -not (Test-Link $item) -and -not $item.PSIsContainer -and (Test-Path -LiteralPath $last)) {
                if ([IO.File]::ReadAllText($dest) -cne [IO.File]::ReadAllText($last)) {
                    Write-Warning 'opencode.jsonc was hand-edited. Backing it up; edit the repo JSONC files instead.'
                }
            }
            Prepare-Destination $dest
            if (-not $DryRun) { Write-Utf8 $dest $content }
            Write-Record 'write' $dest '(merged base + work)'
        }
        if (-not $DryRun) { Write-Utf8 $last $content }
    }
    if ($Version -eq 'opencode2') {
        Install-Path (Join-Path $RepoDir '.config/opencode2/cli.json') (Join-Path $OpenCodeDir 'cli.json')
    }
}

function Resolve-Selection {
    if ($Enabled -contains 'opencode' -and $Enabled -contains 'opencode2') {
        throw 'opencode and opencode2 are mutually exclusive: both install opencode.jsonc.'
    }
    if ($Enabled -contains 'claude-skills' -and $Enabled -notcontains 'agents-skills') {
        Write-Host 'note: claude-skills requires agents-skills - enabling it'
        $script:Enabled += 'agents-skills'
    }
    if (-not $Enabled.Count) { throw 'Nothing selected.' }
}

function Show-Modules {
    Write-Host "environment installer - profile: $Profile, mode: $Mode"
    $i = 0
    foreach ($name in $Modules.Keys) {
        $i++
        $mark = if ($Enabled -contains $name) { 'x' } else { ' ' }
        Write-Host ('  {0}) [{1}] {2,-14} {3}' -f $i, $mark, $name, $Modules[$name])
    }
}

function Invoke-Install {
    Resolve-Selection
    $script:Changed = 0; $script:Unchanged = 0; $script:Backups = 0
    if ($DryRun) { Write-Host 'DRY RUN - nothing will be modified' }
    foreach ($name in $Modules.Keys) {
        if ($Enabled -notcontains $name) { continue }
        Write-Host "[$name]"
        switch ($name) {
            'nvim' {
                $format = $Profile -eq 'personal'
                if ($CanPrompt -and -not $DryRun) {
                    $hint = if ($format) { '[Y/n]' } else { '[y/N]' }
                    $answer = Read-Host "Enable personal Python formatting (isort + black)? $hint"
                    if ($answer) { $format = $answer -match '^[Yy]' }
                }
                $variant = if ($format) { 'with' } else { 'without' }
                Install-Path (Join-Path $RepoDir '.config/nvim/init.lua') (Join-Path $NvimDir 'init.lua')
                Install-Path (Join-Path $RepoDir ".config/nvim/overrides/$variant-python-formatting.lua") (Join-Path $NvimDir 'lua/local/overrides.lua')
            }
            'nvim-ai' {
                Install-Path (Join-Path $RepoDir '.config/nvim/lua/plugins/ai.lua') (Join-Path $NvimDir 'lua/plugins/ai.lua')
            }
            { $_ -in 'opencode', 'opencode2' } { Install-OpenCode $name }
            { $_ -in 'agents-skills', 'claude-skills' } {
                foreach ($skill in Get-ChildItem -LiteralPath (Join-Path $RepoDir 'agents/skills') -Directory) {
                    $shared = Join-Path $UserHome ".agents/skills/$($skill.Name)"
                    if ($name -eq 'agents-skills') {
                        Install-Path $skill.FullName $shared
                    } else {
                        $kind = if ($Copy) { 'Junction' } else { 'SymbolicLink' }
                        Install-Path $shared (Join-Path $UserHome ".claude/skills/$($skill.Name)") $kind
                    }
                }
            }
        }
    }
    Write-Host "done - $Changed change(s), $Unchanged unchanged"
    if (-not $DryRun) { Write-Utf8 (Join-Path $StateDir 'profile') $Profile }
}

function Quote-PowerShell([string]$Value) {
    "'" + [Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($Value) + "'"
}

function Invoke-Elevated {
    # EncodedCommand avoids native argument quoting issues (spaces, quotes, Unicode).
    # Preserve the installing user's paths even if UAC uses another admin account.
    $command = ''
    foreach ($name in 'USERPROFILE', 'LOCALAPPDATA', 'XDG_CONFIG_HOME', 'XDG_STATE_HOME', 'NVIM_APPNAME') {
        $command += '$env:' + $name + ' = ' + (Quote-PowerShell ([Environment]::GetEnvironmentVariable($name))) + ";`n"
    }
    $command += '& ' + (Quote-PowerShell $PSCommandPath) + ' -Profile ' + (Quote-PowerShell $Profile) +
        ' -Only ' + (Quote-PowerShell ($Enabled -join ',')) + ' -Link'
    if (-not $CanPrompt) { $command += ' -Yes' }
    $command += "`n`$code = `$LASTEXITCODE"
    if ($CanPrompt) { $command += "`nRead-Host 'Press Enter to close the installer'" }
    $command += "`nexit `$code"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    try {
        $process = Start-Process -FilePath (Get-Process -Id $PID).Path -Verb RunAs -Wait -PassThru `
            -ArgumentList "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
    } catch {
        throw "Elevation was cancelled or could not start. No configs were installed. $($_.Exception.Message)"
    }
    if ($process.ExitCode -ne 0) { throw "Elevated installer exited with code $($process.ExitCode)." }
}

try {
    if ($Copy -and $Link) { throw 'Choose either -Copy or -Link.' }
    if (-not $Profile) {
        $saved = Join-Path $StateDir 'profile'
        $Profile = if (Test-Path -LiteralPath $saved) { [IO.File]::ReadAllText($saved).Trim() } else { 'personal' }
    }
    $Only = @($Only -split ',' | Where-Object { $_ })
    $Skip = @($Skip -split ',' | Where-Object { $_ })
    foreach ($name in @($Only) + @($Skip)) {
        if (-not $Modules.Contains($name)) { throw "Unknown module '$name'. Available: $($Modules.Keys -join ', ')" }
    }
    $Enabled = if ($Only.Count) { @($Only | Select-Object -Unique) } else { $Defaults }
    $Enabled = @($Enabled | Where-Object { $Skip -notcontains $_ })
    if ($Render) { Write-Output (Render-OpenCode $Render); return }
    if ($List) { Show-Modules; return }
    if ($CanPrompt -and -not $Only.Count -and -not $Skip.Count) {
        :menu while ($true) {
            Show-Modules
            $choice = Read-Host 'toggle 1-6 / (a)ll / (n)one / (d)ry-run / Enter=install / (q)uit'
            switch ($choice) {
                '' { break menu }
                'q' { return }
                'a' { $Enabled = $Defaults }
                'n' { $Enabled = @() }
                'd' {
                    $DryRun = $true
                    try { Invoke-Install } catch { Write-Host $_.Exception.Message }
                    finally { $DryRun = $false }
                }
                { $_ -match '^[1-6]$' } {
                    $name = @($Modules.Keys)[[int]$choice - 1]
                    if ($Enabled -contains $name) {
                        $Enabled = @($Enabled | Where-Object { $_ -ne $name })
                    } else {
                        if ($name -in 'opencode', 'opencode2') { $Enabled = @($Enabled | Where-Object { $_ -notin 'opencode', 'opencode2' }) }
                        $Enabled += $name
                    }
                }
                default { Write-Host "Unrecognized: $choice" }
            }
        }
    }
    Resolve-Selection
    if (-not $Copy -and -not $DryRun) {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            Invoke-Elevated
            return
        }
    }
    Invoke-Install
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
