$ErrorActionPreference = "Stop"
$profilePath = Join-Path $PSScriptRoot "..\PowerShell\Microsoft.PowerShell_profile.ps1"
$directory = ([Environment]::GetEnvironmentVariable("Path", "Machine") -split ";" |
    Where-Object { $_ } | Select-Object -First 1)
if (-not $directory) { throw "A registered machine PATH entry is required for this test." }
$machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
$savedPath = $env:Path
try {
    foreach ($scenario in @("stale", "available", "missing")) {
        & {
            $imports = [System.Collections.Generic.List[string]]::new()
            $warnings = [System.Collections.Generic.List[string]]::new()
            $bindings = [System.Collections.Generic.List[string]]::new()
            $prefix = "C:\dotfiles-profile-test"
            $env:Path = $prefix
            if ($scenario -eq "available") { $env:Path += ";$directory" }
            function Get-Command($Name, $CommandType, $ErrorAction) {
                if ($Name -eq "fzf" -and $scenario -ne "missing" -and
                    $directory -in ($env:Path -split ";")) {
                    [pscustomobject]@{ Source = (Join-Path $directory "fzf.exe") }
                }
            }
            function Test-Path($LiteralPath, $PathType) {
                $scenario -ne "missing" -and
                    $LiteralPath -eq (Join-Path $directory "fzf.exe")
            }
            function Get-Module($Name, [switch]$ListAvailable) {
                if ($Name -in @("Terminal-Icons", "posh-git", "PSFzf") -and
                    ($ListAvailable -or $imports.Contains($Name))) {
                    [pscustomobject]@{ Name = $Name }
                }
            }
            function Import-Module($Name) { $imports.Add($Name) }
            function Write-Warning($Message) { $warnings.Add($Message) }
            function Set-PsFzfOption($PSReadlineChordProvider, $PSReadlineChordReverseHistory) {
                $bindings.Add("$PSReadlineChordProvider,$PSReadlineChordReverseHistory")
            }
            . $profilePath
            if ($scenario -eq "missing") {
                if ($imports.Contains("PSFzf") -or $bindings.Count -ne 0) {
                    throw "PSFzf must not import or bind keys without its binary."
                }
                if (-not ($warnings | Where-Object { $_ -like "PSFzf requires fzf*" })) {
                    throw "A missing binary must produce an explicit warning."
                }
                if ($env:Path -ne $prefix) { throw "Missing binaries must not change PATH." }
            } else {
                if ($env:Path -ne "$prefix;$directory") {
                    throw "The profile must retain existing PATH entries without duplicates."
                }
                if (-not $imports.Contains("PSFzf") -or $bindings -notcontains "Ctrl+f,Ctrl+r") {
                    throw "PSFzf must import and bind its shortcuts when the binary is available."
                }
            }
        }
    }
} finally {
    $env:Path = $savedPath
}
if ([Environment]::GetEnvironmentVariable("Path", "Machine") -ne $machinePath -or
    [Environment]::GetEnvironmentVariable("Path", "User") -ne $userPath) {
    throw "Profile initialization must not change persistent PATH."
}
Write-Host "PowerShell profile regression tests passed."
