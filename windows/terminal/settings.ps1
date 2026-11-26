function Merge-TerminalPreferences {
    param(
        [Parameter(Mandatory)][System.Collections.IDictionary]$Settings,
        [Parameter(Mandatory)][System.Collections.IDictionary]$Preferences,
        [Parameter(Mandatory)][string]$DefaultProfileName
    )

    $targets = @{}
    foreach ($override in $Preferences.profiles.list) {
        $matches = @($Settings.profiles.list | Where-Object {
            $_.name -eq $override.name -and (
                $_.source -eq $override.source -or (
                    $override.source -eq "Microsoft.WSL" -and $_.source -eq "Windows.Terminal.Wsl"
                )
            )
        })
        if ($matches.Count -ne 1) {
            throw "Expected one terminal profile for $($override.name). Initialize WSL and reopen Terminal first."
        }
        $targets[$override.name] = $matches[0]
    }
    $default = $targets[$DefaultProfileName]
    if (-not $default -or -not $default.guid) {
        throw "Default terminal profile not found: $DefaultProfileName"
    }

    foreach ($key in $Preferences.Keys) {
        if ($key -notin @("profiles", "actions", "keybindings")) {
            $Settings[$key] = $Preferences[$key]
        }
    }
    if (-not $Settings.profiles.defaults) { $Settings.profiles.defaults = [ordered]@{} }
    foreach ($key in $Preferences.profiles.defaults.Keys) {
        if ($key -eq "font") {
            if (-not $Settings.profiles.defaults.font) { $Settings.profiles.defaults.font = [ordered]@{} }
            foreach ($fontKey in $Preferences.profiles.defaults.font.Keys) {
                $Settings.profiles.defaults.font[$fontKey] = $Preferences.profiles.defaults.font[$fontKey]
            }
        } else {
            $Settings.profiles.defaults[$key] = $Preferences.profiles.defaults[$key]
        }
    }
    foreach ($profile in $Settings.profiles.list) {
        if ($profile.name -match "PowerShell" -and $profile.font -and $profile.font.face) {
            $profile.font.face = $Preferences.profiles.defaults.font.face
        }
    }
    foreach ($override in $Preferences.profiles.list) {
        $profile = $targets[$override.name]
        foreach ($key in $override.Keys) {
            if ($key -in @("name", "source")) { continue }
            if ($key -eq "font") {
                if (-not $profile.font) { $profile.font = [ordered]@{} }
                foreach ($fontKey in $override.font.Keys) {
                    $profile.font[$fontKey] = $override.font[$fontKey]
                }
            } else {
                $profile[$key] = $override[$key]
            }
        }
    }
    $Settings.defaultProfile = $default.guid

    $actions = @($Settings.actions | Where-Object { $_ })
    foreach ($action in $Preferences.actions) {
        $actions = @($actions | Where-Object { $_.id -ne $action.id }) + @($action)
    }
    $Settings.actions = $actions
    $bindings = @($Settings.keybindings | Where-Object { $_ })
    foreach ($binding in $Preferences.keybindings) {
        $retained = @()
        foreach ($current in $bindings) {
            $keys = @($current.keys)
            $remaining = @($keys | Where-Object { $_ -ine $binding.keys })
            if ($remaining.Count -eq $keys.Count) {
                $retained += $current
            } elseif ($remaining.Count -gt 0) {
                $copy = [ordered]@{}
                foreach ($key in $current.psbase.Keys) { $copy[$key] = $current[$key] }
                $copy["keys"] = $remaining
                $retained += $copy
            }
        }
        $bindings = $retained + @($binding)
    }
    $Settings.keybindings = $bindings
    return $Settings
}
