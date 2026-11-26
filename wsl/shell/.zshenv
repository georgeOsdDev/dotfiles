skip_global_compinit=1

if [ -z "${BROWSER:-}" ] && [ -e /proc/sys/fs/binfmt_misc/WSLInterop ] &&
    [ -x "$HOME/.local/bin/wsl-browser" ]; then
    export BROWSER="$HOME/.local/bin/wsl-browser"
fi
