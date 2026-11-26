#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ManifestPath
)
$ErrorActionPreference = "Stop"
$manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
if ($manifest.Version -ne 1) { throw "Unsupported backup manifest" }

# Validate all targets first, preserving later user edits.
foreach ($file in $manifest.Files) {
    $item = Get-Item -LiteralPath $file.Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.LinkType -or $item.PSIsContainer)) {
        throw "Restore target is now a link or directory: $($file.Path)"
    }
    $hash = if ($item) { (Get-FileHash -LiteralPath $file.Path).Hash } else { $null }
    if ($hash -ne $file.AppliedHash -and $hash -ne $file.OriginalHash) {
        throw "File changed after setup; reconcile manually: $($file.Path)"
    }
    if ($file.Existed -and (Get-FileHash -LiteralPath $file.Backup).Hash -ne $file.OriginalHash) {
        throw "Backup integrity check failed: $($file.Backup)"
    }
}
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($null -ne $manifest.AppliedUserPath -and
    $currentPath -ne $manifest.AppliedUserPath -and $currentPath -ne $manifest.UserPath) {
    throw "User PATH changed after setup; reconcile manually before restoring."
}
foreach ($file in $manifest.Files) {
    if ($file.Existed) {
        Copy-Item -LiteralPath $file.Backup -Destination $file.Path -Force
    } elseif (Test-Path -LiteralPath $file.Path) {
        Remove-Item -LiteralPath $file.Path
    }
}
if ($null -ne $manifest.AppliedUserPath) {
    [Environment]::SetEnvironmentVariable("Path", $manifest.UserPath, "User")
}
Write-Host "Settings restored. Restart your terminal. Packages and modules were not uninstalled."
