#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$restore = Join-Path $PSScriptRoot "..\restore.ps1"
$temp = Join-Path ([System.IO.Path]::GetTempPath()) ("dotfiles-restore-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    $existing = Join-Path $temp "existing.ps1"
    $created = Join-Path $temp "created.ps1"
    $original = Join-Path $temp "original.ps1"
    Set-Content -LiteralPath $original -Value "original" -Encoding utf8
    Set-Content -LiteralPath $existing -Value "managed" -Encoding utf8
    Set-Content -LiteralPath $created -Value "managed" -Encoding utf8
    $manifest = @{
        Version = 1
        AppliedUserPath = $null
        Files = @(
            @{
                Path = $existing; Existed = $true; Backup = $original
                OriginalHash = (Get-FileHash $original).Hash
                AppliedHash = (Get-FileHash $existing).Hash
            },
            @{
                Path = $created; Existed = $false; Backup = $null
                OriginalHash = $null; AppliedHash = (Get-FileHash $created).Hash
            }
        )
    }
    $path = Join-Path $temp "manifest.json"
    $manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $path -Encoding utf8

    Set-Content -LiteralPath $created -Value "later user edit" -Encoding utf8
    $rejected = $false
    try { & $restore -ManifestPath $path } catch {
        if ($_.Exception.Message -notlike "File changed after setup*") { throw }
        $rejected = $true
    }
    if (-not $rejected -or (Get-Content $existing -Raw).Trim() -ne "managed") {
        throw "Restore must reject later edits before changing any file."
    }

    Set-Content -LiteralPath $created -Value "managed" -Encoding utf8
    Set-Content -LiteralPath $original -Value "tampered" -Encoding utf8
    $rejected = $false
    try { & $restore -ManifestPath $path } catch {
        if ($_.Exception.Message -notlike "Backup integrity check failed*") { throw }
        $rejected = $true
    }
    if (-not $rejected) { throw "Restore must reject a modified backup." }

    Set-Content -LiteralPath $original -Value "original" -Encoding utf8
    & $restore -ManifestPath $path
    if ((Get-FileHash $existing).Hash -ne (Get-FileHash $original).Hash -or
        (Test-Path -LiteralPath $created)) {
        throw "Restore must recover original files and remove newly created files."
    }
    & $restore -ManifestPath $path
    Write-Host "Restore regression tests passed."
} finally {
    Remove-Item -LiteralPath $existing, $created, $original, (Join-Path $temp "manifest.json") `
        -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $temp
}
