# PowerShell Profile
# Managed by dotfiles - https://github.com/georgeOsdDev/dotfiles

# Oh My Posh prompt
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    $appearance = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\terminal\appearance.json") -Raw |
        ConvertFrom-Json
    $themePath = Join-Path $env:LOCALAPPDATA "dotfiles\themes\$($appearance.themeName).omp.json"
    if (-not (Test-Path -LiteralPath $themePath)) {
        throw "Prompt theme not installed. Run install.ps1."
    }
    $promptInit = oh-my-posh init pwsh --config $themePath
    if ($LASTEXITCODE -ne 0) { throw "Oh My Posh initialization failed" }
    $promptInit | Invoke-Expression
} else {
    Write-Warning "oh-my-posh is not installed; run install.ps1."
}

# PSReadLine configuration
if (Get-Module -ListAvailable PSReadLine) {
    Import-Module PSReadLine
    if ($Host.UI.SupportsVirtualTerminal -and -not [Console]::IsOutputRedirected) {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# Terminal Icons
if (-not (Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue)) {
    # VS Code may retain the PATH from before a package was installed.
    $registeredPath = @(
        [Environment]::GetEnvironmentVariable("Path", "Machine"),
        [Environment]::GetEnvironmentVariable("Path", "User")
    ) -join ";"
    foreach ($directory in ($registeredPath -split ";")) {
        if ($directory -and (Test-Path -LiteralPath (Join-Path $directory "fzf.exe") -PathType Leaf)) {
            $env:Path = "$env:Path;$directory"
            break
        }
    }
}
foreach ($module in @("Terminal-Icons", "posh-git", "PSFzf")) {
    if ($module -eq "PSFzf" -and
        -not (Get-Command fzf -CommandType Application -ErrorAction SilentlyContinue)) {
        Write-Warning "PSFzf requires fzf in PATH; run install.ps1 and restart VS Code."
        continue
    }
    if (Get-Module -ListAvailable $module) {
        Import-Module $module
    } else {
        Write-Warning "$module is not installed; run install.ps1."
    }
}
if ((Get-Module PSFzf) -and (Get-Command fzf -ErrorAction SilentlyContinue)) {
    Set-PsFzfOption -PSReadlineChordProvider "Ctrl+f" -PSReadlineChordReverseHistory "Ctrl+r"
}
