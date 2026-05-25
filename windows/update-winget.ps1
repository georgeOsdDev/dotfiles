# Check for winget package updates and optionally update winget-packages.json
# Usage:
#   .\update-winget.ps1           # Check for updates (dry run)
#   .\update-winget.ps1 -Apply    # Upgrade packages and update JSON
param(
    [switch]$Apply
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$JsonPath = Join-Path $ScriptDir "winget-packages.json"

if (-not (Test-Path $JsonPath)) {
    Write-Error "winget-packages.json not found at $JsonPath"
    exit 1
}

$json = Get-Content $JsonPath -Raw | ConvertFrom-Json
$packages = $json.Sources[0].Packages

# Build a lookup of installed versions via winget list
$installed = @{}
$listOutput = winget list --accept-source-agreements 2>$null
foreach ($pkg in $packages) {
    $id = $pkg.PackageIdentifier
    $match = $listOutput | Select-String ([regex]::Escape($id))
    if ($match) {
        # winget list output uses variable-width columns; split on 2+ spaces
        $parts = "$match" -split '\s{2,}'
        # Installed version is typically the 3rd field (after Name, Id)
        if ($parts.Count -ge 3) {
            $installed[$id] = $parts[2].Trim()
        }
    }
}

Write-Host "=== winget package update check ===" -ForegroundColor Cyan
Write-Host ""

$updates = @()
foreach ($pkg in $packages) {
    $id = $pkg.PackageIdentifier
    $pinned = $pkg.Version
    $current = $installed[$id]

    # Get latest available version from winget
    $info = winget show --id $id --accept-source-agreements 2>$null
    $latest = ($info | Select-String "^Version:" | ForEach-Object { $_ -replace 'Version:\s+', '' }).Trim()

    if (-not $latest) {
        Write-Host "  [?] $id - could not determine latest version" -ForegroundColor Yellow
        continue
    }

    if ($current -and $current -ne $pinned) {
        Write-Host "  [DRIFT]  $id  json=$pinned installed=$current latest=$latest" -ForegroundColor Magenta
    }

    if ($latest -ne $pinned) {
        Write-Host "  [UPDATE] $id  $pinned -> $latest (installed=$current)" -ForegroundColor Green
        $updates += [PSCustomObject]@{ Id = $id; From = $pinned; Installed = $current; To = $latest }
    } else {
        Write-Host "  [OK]     $id  $pinned" -ForegroundColor Gray
    }
}

Write-Host ""
if ($updates.Count -eq 0) {
    Write-Host "All packages are up to date." -ForegroundColor Cyan
    exit 0
}

Write-Host "$($updates.Count) update(s) available." -ForegroundColor Yellow

if (-not $Apply) {
    Write-Host ""
    Write-Host "Run with -Apply to upgrade packages and update winget-packages.json" -ForegroundColor Yellow
    exit 0
}

Write-Host ""
Write-Host ">>> Upgrading packages..." -ForegroundColor Yellow
foreach ($u in $updates) {
    Write-Host "  Upgrading $($u.Id) to $($u.To)..."
    winget upgrade --id $u.Id --version $u.To --accept-package-agreements --accept-source-agreements
}

Write-Host ""
Write-Host ">>> Updating winget-packages.json..." -ForegroundColor Yellow
foreach ($u in $updates) {
    $pkg = $packages | Where-Object { $_.PackageIdentifier -eq $u.Id }
    $pkg.Version = $u.To
}
$json.CreationDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.000-00:00")
$json | ConvertTo-Json -Depth 10 | Set-Content $JsonPath -Encoding UTF8

Write-Host ""
Write-Host "=== Done. Review changes with: git diff windows/winget-packages.json ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "NOTE: Restart your terminal to apply updates." -ForegroundColor Yellow
$restartNeeded = $updates | Where-Object { $_.Id -match "Microsoft\.WSL|Canonical\.Ubuntu|Microsoft\.WindowsTerminal" }
if ($restartNeeded) {
    Write-Host "  - WindowsTerminal: Close and reopen to use the new version" -ForegroundColor Yellow
    Write-Host "  - WSL/Ubuntu: Run 'wsl --shutdown' then reopen to apply kernel/distro updates" -ForegroundColor Yellow
}
