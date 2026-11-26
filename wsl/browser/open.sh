#!/usr/bin/env bash
set -euo pipefail
if [ "$#" -ne 1 ]; then
    echo "Usage: wsl-browser HTTP_OR_HTTPS_URL" >&2
    exit 2
fi
case "$1" in
    http://*|https://*) ;;
    *) echo "ERROR: Expected an HTTP(S) URL." >&2; exit 2 ;;
esac
if ! command -v powershell.exe >/dev/null 2>&1; then
    echo "ERROR: Windows PowerShell is unavailable. Check WSL interop and Windows PATH." >&2
    exit 1
fi
# Transfer the URL as data, never as PowerShell command text.
export DOTFILES_BROWSER_URL="$1"
export WSLENV="${WSLENV:+$WSLENV:}DOTFILES_BROWSER_URL/w"
exec powershell.exe -NoLogo -NoProfile -NonInteractive -Command '
    $ErrorActionPreference = "Stop"
    $url = $env:DOTFILES_BROWSER_URL
    Remove-Item Env:\DOTFILES_BROWSER_URL
    $uri = [System.Uri]$url
    if (-not $uri.IsAbsoluteUri -or $uri.Scheme -notin @("http", "https")) {
        throw "Expected an absolute HTTP(S) URL."
    }
    Start-Process -FilePath $url
'
