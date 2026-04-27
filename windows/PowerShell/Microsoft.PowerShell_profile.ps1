# PowerShell Profile
# Managed by dotfiles - https://github.com/georgeOsdDev/dotfiles

# Oh My Posh prompt
oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\m365.omp.json" | Invoke-Expression

# PSReadLine configuration
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
Set-PSReadLineOption -HistorySearchCursorMovesToEnd

# Terminal Icons
Import-Module Terminal-Icons
