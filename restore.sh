#!/usr/bin/env bash
set -euo pipefail
BACKUP_DIR="${1:?Usage: bash restore.sh BACKUP_DIRECTORY}"
test -f "$BACKUP_DIR/files.tsv"
test -f "$BACKUP_DIR/login-shell"
original_shell="$(cat "$BACKUP_DIR/login-shell")"
current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
if [ "$current_shell" != "$original_shell" ] &&
    [ "$(basename "$current_shell")" != zsh ]; then
    echo "ERROR: Login shell changed after setup; restore it manually." >&2
    exit 1
fi

fingerprint() {
    if [ -L "$1" ]; then
        printf 'link:%s' "$(readlink "$1")"
    elif [ -f "$1" ]; then
        sha256sum "$1" | cut -d' ' -f1
    elif [ -e "$1" ]; then
        echo "ERROR: Not a regular config file: $1" >&2
        return 1
    else
        printf '%s' absent
    fi
}

if [ -f "$BACKUP_DIR/original.tsv" ]; then
    while IFS=$'\t' read -r relative original; do
        case "$relative" in
            .bashrc|.profile|.zshrc|.zimrc|.zshenv|.gitconfig|.config/mise/config.toml|.local/bin/wsl-browser) ;;
            *) echo "ERROR: Unexpected backup target: $relative" >&2; exit 1 ;;
        esac
        applied="$(awk -F '\t' -v name="$relative" '$1 == name {print $2}' "$BACKUP_DIR/files.tsv")"
        current="$(fingerprint "$HOME/$relative")"
        if [ "$current" != "$applied" ] && [ "$current" != "$original" ]; then
            echo "ERROR: Config changed after setup; reconcile manually: $relative" >&2
            exit 1
        fi
        if [ "$original" != absent ] &&
            [ "$(fingerprint "$BACKUP_DIR/original/$relative")" != "$original" ]; then
            echo "ERROR: Backup integrity check failed: $relative" >&2
            exit 1
        fi
    done < "$BACKUP_DIR/original.tsv"
    while IFS=$'\t' read -r relative original; do
        if [ "$original" = absent ]; then
            rm -f "$HOME/$relative"
        else
            rm -f "$HOME/$relative"
            cp -a "$BACKUP_DIR/original/$relative" "$HOME/$relative"
        fi
    done < "$BACKUP_DIR/original.tsv"
fi
if [ "$current_shell" != "$original_shell" ]; then
    chsh -s "$original_shell"
fi
echo "Settings restored. Restart your shell. Installed tools were not removed."
