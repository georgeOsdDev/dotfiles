$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\terminal\settings.ps1")
$preferences = Get-Content -LiteralPath (Join-Path $PSScriptRoot "..\terminal\preferences.json") -Raw |
    ConvertFrom-Json -AsHashtable
$settings = @{
    defaultProfile = "{old-default}"
    launchMode = "maximized"
    profiles = @{
        defaults = @{font = @{face = "old-font"; size = 13}}
        list = @(
            @{name = "Ubuntu-24.04"; source = "Microsoft.WSL"; guid = "{devbox-ubuntu}"; font = @{size = 15}},
            @{name = "Developer PowerShell"; guid = "{devbox-vs}"; commandline = "keep-this"; hidden = $true}
        )
    }
    actions = @(@{id = "User.Keep"; command = "newTab"})
    keybindings = @(@{id = "User.Keep"; keys = @("ctrl+c", "ctrl+b")})
}
$settings = $settings | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
$settings = Merge-TerminalPreferences $settings $preferences "Ubuntu-24.04"
if ($settings.defaultProfile -ne "{devbox-ubuntu}" -or $settings.launchMode -ne "maximized") {
    throw "Preferences must use the actual Dev Box GUID and retain unrelated options."
}
$ubuntu = $settings.profiles.list[0]
$vs = $settings.profiles.list[1]
if ($ubuntu.font.size -ne 15 -or $settings.profiles.defaults.font.size -ne 13 -or
    $vs.guid -ne "{devbox-vs}" -or $vs.commandline -ne "keep-this" -or -not $vs.hidden) {
    throw "Preferences must preserve profile identity, font sizes and unrelated settings."
}
if ($ubuntu.colorScheme -ne "Campbell" -or $ubuntu.font.face -ne "0xProto Nerd Font" -or
    $settings.profiles.defaults.font.face -ne "Hack Nerd Font" -or -not $settings.copyOnSelect) {
    throw "Requested appearance and copy behavior were not applied."
}
if (@($settings.actions | Where-Object id -EQ "User.Keep").Count -ne 1 -or
    @($settings.keybindings | Where-Object { $_.id -eq "User.Keep" -and "ctrl+b" -in $_.keys }).Count -ne 1 -or
    @($settings.keybindings | Where-Object { $_.id -eq "Terminal.CopyToClipboard" -and $_.keys -eq "ctrl+c" }).Count -ne 1) {
    throw "Binding migration must retain unrelated chords and replace conflicting chords."
}
$before = $settings | ConvertTo-Json -Depth 100 -Compress
$settings = Merge-TerminalPreferences $settings $preferences "Ubuntu-24.04"
if ($before -ne ($settings | ConvertTo-Json -Depth 100 -Compress)) {
    throw "Preference merging must be idempotent."
}
$rejected = $false
try { Merge-TerminalPreferences @{profiles = @{list = @()}} $preferences "Ubuntu-24.04" > $null } catch {
    if ($_.Exception.Message -notlike "Expected one terminal profile*") { throw }
    $rejected = $true
}
if (-not $rejected) { throw "Missing Ubuntu profiles must be reported explicitly." }
$legacy = $settings | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable
$legacy.profiles.list[0].source = "Windows.Terminal.Wsl"
$legacy = Merge-TerminalPreferences $legacy $preferences "Ubuntu-24.04"
if ($legacy.defaultProfile -ne "{devbox-ubuntu}" -or
    $legacy.profiles.list[0].source -ne "Windows.Terminal.Wsl") {
    throw "Older WSL-generated profiles must retain their source and actual GUID."
}
$legacy.profiles.list += [ordered]@{
    name = "Ubuntu-24.04"; source = "Microsoft.WSL"; guid = "{another-ubuntu}"
}
$rejected = $false
try { Merge-TerminalPreferences $legacy $preferences "Ubuntu-24.04" > $null } catch {
    if ($_.Exception.Message -notlike "Expected one terminal profile*") { throw }
    $rejected = $true
}
if (-not $rejected) { throw "Ambiguous WSL profiles must not be selected silently." }
Write-Host "Terminal preference regression tests passed."
