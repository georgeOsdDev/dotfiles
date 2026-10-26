# Bootstrap script for Windows environment
# Managed by dotfiles - https://github.com/georgeOsdDev/dotfiles

$ErrorActionPreference = "Stop"
$DotfilesDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "=== dotfiles Windows bootstrap ===" -ForegroundColor Cyan
Write-Host "Dotfiles directory: $DotfilesDir"

# --- winget packages ---
Write-Host ""
Write-Host ">>> Installing winget packages..." -ForegroundColor Yellow
$wingetJson = Join-Path $DotfilesDir "windows\winget-packages.json"
if (Test-Path $wingetJson) {
    winget import -i $wingetJson --accept-package-agreements --accept-source-agreements
} else {
    Write-Warning "winget-packages.json not found at $wingetJson"
}

# --- Python (security-only branches no longer have winget installers) ---
Write-Host ""
Write-Host ">>> Setting up Python with uv..." -ForegroundColor Yellow
$uv = (Get-Command uv -ErrorAction SilentlyContinue).Source
if (-not $uv) {
    $uv = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\uv.exe"
}
foreach ($version in @("3.14.9", "3.12.15")) {
    & $uv python install $version
    if ($LASTEXITCODE -ne 0) { throw "Failed to install Python $version" }
}
& $uv python install 3.12.15 --default
if ($LASTEXITCODE -ne 0) { throw "Failed to select Python 3.12.15" }
& $uv python update-shell
if ($LASTEXITCODE -ne 0) { throw "Failed to update the Python PATH" }

# --- PowerShell modules ---
Write-Host ""
Write-Host ">>> Installing PowerShell modules..." -ForegroundColor Yellow
$modules = @("Terminal-Icons")
foreach ($mod in $modules) {
    if (-not (Get-Module -ListAvailable -Name $mod)) {
        Write-Host "  Installing $mod..."
        Install-Module -Name $mod -Scope CurrentUser -Force -AllowClobber
    } else {
        Write-Host "  $mod already installed"
    }
}

# --- PowerShell profile ---
Write-Host ""
Write-Host ">>> Linking PowerShell profile..." -ForegroundColor Yellow
$profileDir = Split-Path -Parent $PROFILE
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Force -Path $profileDir | Out-Null
}

$source = Join-Path $DotfilesDir "windows\PowerShell\Microsoft.PowerShell_profile.ps1"
if (Test-Path $PROFILE) {
    $existing = Get-Item $PROFILE -ErrorAction SilentlyContinue
    if ($existing.LinkType -ne "SymbolicLink") {
        $backup = "$PROFILE.bak"
        Write-Host "  Backing up existing profile to $backup"
        Copy-Item $PROFILE $backup -Force
    }
}

New-Item -ItemType SymbolicLink -Path $PROFILE -Target $source -Force | Out-Null
Write-Host "  Linked $PROFILE -> $source"

Write-Host ""
Write-Host "=== Windows bootstrap complete! ===" -ForegroundColor Cyan
Write-Host "NOTE: Restart your terminal to apply changes."
