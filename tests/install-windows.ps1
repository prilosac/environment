# Run in a separate elevated PowerShell process, as the Windows CI job does.
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$powershell = (Get-Process -Id $PID).Path
$root = Join-Path ([IO.Path]::GetTempPath()) ('environment-test-' + [guid]::NewGuid())
$env:XDG_CONFIG_HOME = ''; $env:XDG_STATE_HOME = ''; $env:NVIM_APPNAME = ''

$files = @(
    'AppData/Local/nvim/init.lua'
    'AppData/Local/nvim/lua/local/overrides.lua'
    'AppData/Local/nvim/lua/plugins/ai.lua'
    '.config/opencode/opencode.jsonc'
    '.config/opencode/cli.json'
    'AppData/Local/environment/profile'
)
$skills = Join-Path $repo 'agents/skills'
foreach ($file in Get-ChildItem -LiteralPath $skills -Recurse -File) {
    $relative = $file.FullName.Substring($skills.Length + 1)
    $files += ".agents/skills/$relative", ".claude/skills/$relative"
}

# Remove links themselves during cleanup, never their targets in the checkout.
function Remove-Fixture($Path) {
    $item = Get-Item -LiteralPath $Path -Force
    if ($item.PSIsContainer -and -not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        foreach ($child in Get-ChildItem -LiteralPath $Path -Force) { Remove-Fixture $child.FullName }
    }
    $item.Delete()
}

try {
    foreach ($mode in 'Link', 'Copy') {
        foreach ($profile in 'personal', 'work') {
            $env:USERPROFILE = Join-Path $root "$profile-$mode"
            $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData/Local'
            & $powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $repo 'install.ps1') -Profile $profile "-$mode" -Yes
            if ($LASTEXITCODE -ne 0) { throw "Installer failed: $profile $mode" }
            foreach ($file in $files) {
                [void][IO.File]::ReadAllBytes((Join-Path $env:USERPROFILE $file))
            }
            Write-Host "PASS: expected files are readable ($profile, $mode)"
        }
    }
} finally {
    if (Test-Path -LiteralPath $root) { Remove-Fixture $root }
}
