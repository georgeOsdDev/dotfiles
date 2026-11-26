# Reversible Windows bootstrap. Existing applications are not upgraded.
#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$SkipPackages,
    [switch]$SkipPython,
    [switch]$SkipModules,
    [switch]$SkipTerminal,
    [string]$BackupRoot = (Join-Path $env:LOCALAPPDATA "dotfiles\backups")
)

$ErrorActionPreference = "Stop"
if ([System.IO.Path]::GetFullPath($PSScriptRoot).TrimEnd("\") -ine
    [System.IO.Path]::GetFullPath((Join-Path $HOME "dotfiles")).TrimEnd("\")) {
    throw "Clone this repository into ~/dotfiles; the portable PowerShell loader resolves that location."
}
$backup = Join-Path $BackupRoot ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $backup -Force | Out-Null
$manifest = [ordered]@{
    Version = 1
    CreatedAt = (Get-Date).ToString("o")
    Repository = $PSScriptRoot
    UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
    AppliedUserPath = $null
    Files = @()
    Status = "in-progress"
}
$manifestPath = Join-Path $backup "manifest.json"
function Save-Manifest {
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
}
function Backup-File([string]$Path) {
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.LinkType -or $item.PSIsContainer)) {
        throw "Refusing to replace a link or directory: $Path"
    }
    $copy = Join-Path $backup ("file-{0}" -f $manifest.Files.Count)
    if ($item) { Copy-Item -LiteralPath $Path -Destination $copy }
    $manifest.Files += [ordered]@{
        Path = $Path
        Existed = [bool]$item
        Backup = $copy
        OriginalHash = $(if ($item) { (Get-FileHash -LiteralPath $Path).Hash } else { $null })
        AppliedHash = $null
    }
    Save-Manifest
}
function Record-File([string]$Path) {
    ($manifest.Files | Where-Object Path -EQ $Path).AppliedHash = (Get-FileHash -LiteralPath $Path).Hash
    Save-Manifest
}
function Invoke-Checked([string]$Command, [string[]]$Arguments) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

Save-Manifest
Write-Host "Recovery manifest: $manifestPath"
try {
    if (-not $SkipPackages) {
        Invoke-Checked winget @("export", "-o", (Join-Path $backup "packages-before.json"),
            "--accept-source-agreements", "--disable-interactivity")
        $packages = Get-Content -LiteralPath (Join-Path $PSScriptRoot "windows\winget-packages.json") -Raw |
            ConvertFrom-Json
        $missingSources = @()
        foreach ($source in $packages.Sources) {
            $missing = @()
            foreach ($package in $source.Packages) {
                $id = $package.PackageIdentifier
                & winget list --id $id --exact --accept-source-agreements --disable-interactivity | Out-Host
                if ($LASTEXITCODE -eq 0) { continue }
                if ($LASTEXITCODE -ne -1978335212) {
                    throw "Could not determine whether $id is installed: $LASTEXITCODE"
                }
                $missing += [pscustomobject]@{ PackageIdentifier = $id }
            }
            $source.Packages = $missing
            if ($missing.Count -gt 0) { $missingSources += $source }
        }
        $packages.Sources = $missingSources
        $missingPath = Join-Path $backup "packages-missing.json"
        $packages | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $missingPath -Encoding utf8
        if ($missingSources.Count -gt 0) {
            Invoke-Checked winget @("import", "-i", $missingPath,
                "--ignore-versions", "--no-upgrade", "--accept-package-agreements",
                "--accept-source-agreements", "--disable-interactivity")
        }
        Invoke-Checked winget @("export", "-o", (Join-Path $backup "packages-after.json"),
            "--accept-source-agreements", "--disable-interactivity")
    }

    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    foreach ($path in @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links"),
        (Join-Path $HOME ".local\bin")
    )) {
        if ($path -notin ($userPath -split ";")) {
            $userPath = @($userPath, $path) | Where-Object { $_ } | Join-String -Separator ";"
        }
    }
    if (-not $SkipPython) {
        $pythonBin = Join-Path $HOME ".local\bin"
        $userPath = (@($pythonBin) + @($userPath -split ";" |
            Where-Object { $_ -and $_ -ine $pythonBin })) -join ";"
    }
    $manifest.AppliedUserPath = $userPath
    Save-Manifest
    [Environment]::SetEnvironmentVariable("Path", $userPath, "User")
    $env:Path = "$([Environment]::GetEnvironmentVariable('Path', 'Machine'));$userPath"

    if (-not $SkipPython) {
        $runtimeConfig = Get-Content -LiteralPath (Join-Path $PSScriptRoot "mise.toml") -Raw
        $pythonPins = [regex]::Matches($runtimeConfig, '(?m)^python\s*=\s*"(?<version>\d+\.\d+\.\d+)"\s*$')
        if ($pythonPins.Count -ne 1) { throw "Expected one exact Python version in mise.toml." }
        $managedPythonVersion = $pythonPins[0].Groups["version"].Value
        foreach ($version in @($managedPythonVersion, "3.12.15")) {
            Invoke-Checked uv @("python", "install", $version)
        }
        Invoke-Checked uv @("python", "install", "3.12.15", "--default")
    }
    if (-not $SkipModules) {
        foreach ($module in @("Terminal-Icons", "posh-git", "PSFzf")) {
            if (-not (Get-Module -ListAvailable -Name $module)) {
                Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber
            }
        }
    }

    $appearance = Get-Content -LiteralPath (Join-Path $PSScriptRoot "windows\terminal\appearance.json") -Raw |
        ConvertFrom-Json
    $themeDirectory = Join-Path $env:LOCALAPPDATA "dotfiles\themes"
    $themePath = Join-Path $themeDirectory "$($appearance.themeName).omp.json"
    if (-not (Test-Path -LiteralPath $themePath)) {
        Backup-File $themePath
        New-Item -ItemType Directory -Path $themeDirectory -Force | Out-Null
        Invoke-WebRequest -Uri $appearance.themeUrl -OutFile $themePath
        Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json | Out-Null
        Record-File $themePath
    }
    $theme = Get-Content -LiteralPath $themePath -Raw | ConvertFrom-Json
    if (-not $theme.blocks) { throw "Invalid prompt theme at $themePath" }

    if (-not $SkipTerminal) {
        Add-Type -AssemblyName System.Drawing
        $fontRegistry = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
        $fontSnapshotTaken = $false
        foreach ($font in $appearance.fonts) {
            $fonts = [System.Drawing.Text.InstalledFontCollection]::new()
            try { $fontInstalled = $font.face -in $fonts.Families.Name } finally { $fonts.Dispose() }
            if ($fontInstalled) { continue }
            $principal = [Security.Principal.WindowsPrincipal]::new(
                [Security.Principal.WindowsIdentity]::GetCurrent()
            )
            if ($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                throw "Run without elevation to install user-scoped fonts, or pass -SkipTerminal."
            }
            if (-not $fontSnapshotTaken) {
                if (Test-Path $fontRegistry) {
                    Get-ItemProperty $fontRegistry |
                        Select-Object -Property * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider |
                        ConvertTo-Json |
                        Set-Content -LiteralPath (Join-Path $backup "fonts-before.json") -Encoding utf8
                } else {
                    "{}" | Set-Content -LiteralPath (Join-Path $backup "fonts-before.json") -Encoding utf8
                }
                $fontSnapshotTaken = $true
            }
            $archive = Join-Path $backup (($font.face -replace '[^\w.-]', '_') + ".zip")
            Invoke-WebRequest -Uri $font.archiveUrl -OutFile $archive
            if ((Get-FileHash -LiteralPath $archive).Hash -ne $font.sha256) {
                throw "Font archive checksum failed: $($font.face)"
            }
            Invoke-Checked oh-my-posh @("font", "install", $archive)
            Get-ItemProperty $fontRegistry |
                Select-Object -Property * -ExcludeProperty PSPath,PSParentPath,PSChildName,PSDrive,PSProvider |
                ConvertTo-Json |
                Set-Content -LiteralPath (Join-Path $backup "fonts-after.json") -Encoding utf8
        }
        . (Join-Path $PSScriptRoot "windows\terminal\settings.ps1")
        $preferences = Get-Content -LiteralPath (Join-Path $PSScriptRoot "windows\terminal\preferences.json") -Raw |
            ConvertFrom-Json -AsHashtable
        foreach ($settingsPath in @(
            (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
            (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
        )) {
            if (-not (Test-Path -LiteralPath $settingsPath)) { continue }
            $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json -AsHashtable
            $before = $settings | ConvertTo-Json -Depth 100 -Compress
            $settings = Merge-TerminalPreferences -Settings $settings -Preferences $preferences `
                -DefaultProfileName $appearance.defaultProfileName
            if ($before -ne ($settings | ConvertTo-Json -Depth 100 -Compress)) {
                Backup-File $settingsPath
                $settings | ConvertTo-Json -Depth 100 |
                    Set-Content -LiteralPath $settingsPath -Encoding utf8
                Record-File $settingsPath
            }
        }
    }

    $profilePath = $PROFILE.CurrentUserAllHosts
    $loader = @'
# dotfiles managed profile
$dotfilesProfile = Join-Path $HOME 'dotfiles\windows\PowerShell\Microsoft.PowerShell_profile.ps1'
if (Test-Path -LiteralPath $dotfilesProfile) {
    . $dotfilesProfile
} else {
    Write-Warning "dotfiles profile not found at $dotfilesProfile"
}
'@
    $existing = if (Test-Path -LiteralPath $profilePath) {
        [string](Get-Content -LiteralPath $profilePath -Raw)
    } else { "" }
    if (-not $existing.Contains($loader)) {
        Backup-File $profilePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $profilePath) -Force | Out-Null
        Add-Content -LiteralPath $profilePath -Value "`n$loader" -Encoding utf8
        Record-File $profilePath
    }

    # Migrate only the exact legacy dotfiles block, preserving host-specific code.
    $hostProfile = $PROFILE.CurrentUserCurrentHost
    if (Test-Path -LiteralPath $hostProfile) {
        $hostText = [string](Get-Content -LiteralPath $hostProfile -Raw)
        $legacy = @'
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\m365.omp.json" | Invoke-Expression

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

Import-Module Terminal-Icons
'@
        $normalizedHost = $hostText.Replace("`r`n", "`n")
        $normalizedLegacy = $legacy.Replace("`r`n", "`n")
        if ($normalizedHost.StartsWith($normalizedLegacy + "`n") -or $normalizedHost -eq $normalizedLegacy) {
            Backup-File $hostProfile
            $normalizedHost.Substring($normalizedLegacy.Length) |
                Set-Content -LiteralPath $hostProfile -Encoding utf8
            Record-File $hostProfile
        }
    }

    $gitConfig = Join-Path $HOME ".gitconfig"
    $sharedGit = (Join-Path $PSScriptRoot "windows\git\.gitconfig").Replace("\", "/")
    $includes = @(git config --global --get-all include.path)
    if ($LASTEXITCODE -notin @(0, 1)) { throw "Could not read Git includes" }
    if ($sharedGit -notin $includes) {
        Backup-File $gitConfig
        Invoke-Checked git @("config", "--file", $gitConfig, "--add", "include.path", $sharedGit)
        Record-File $gitConfig
    }
    $manifest.Status = "complete"
    Save-Manifest
    Write-Host "Windows setup complete. Restart your terminal."
    Write-Host "Configure Git identity privately in ~/.gitconfig.local; do not commit it."
} catch {
    $manifest.Status = "failed"
    Save-Manifest
    Write-Warning "Setup did not complete. Recovery manifest: $manifestPath"
    throw
}
