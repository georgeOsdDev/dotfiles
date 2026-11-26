#!/usr/bin/env bash
set -euo pipefail
RESTORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/restore.sh"
TEMP="$(mktemp -d)"
cleanup() {
    rm -f "$TEMP/home/.bashrc" "$TEMP/home/.profile" \
        "$TEMP/home/.local/bin/wsl-browser" \
        "$TEMP/backup/original/.bashrc" "$TEMP/backup/files.tsv" \
        "$TEMP/backup/original.tsv" "$TEMP/backup/login-shell" "$TEMP/error.log"
    rmdir "$TEMP/home/.local/bin" "$TEMP/home/.local" \
        "$TEMP/home" "$TEMP/backup/original" "$TEMP/backup" "$TEMP"
}
trap cleanup EXIT
mkdir -p "$TEMP/home/.local/bin" "$TEMP/backup/original"
getent passwd "$(id -un)" | cut -d: -f7 > "$TEMP/backup/login-shell"
printf original > "$TEMP/backup/original/.bashrc"
printf managed > "$TEMP/home/.bashrc"
printf managed > "$TEMP/home/.profile"
printf managed > "$TEMP/home/.local/bin/wsl-browser"
original="$(sha256sum "$TEMP/backup/original/.bashrc" | cut -d' ' -f1)"
applied="$(sha256sum "$TEMP/home/.bashrc" | cut -d' ' -f1)"
printf '.bashrc\t%s\n.profile\tabsent\n.local/bin/wsl-browser\tabsent\n' "$original" > "$TEMP/backup/original.tsv"
printf '.bashrc\t%s\n.profile\t%s\n.local/bin/wsl-browser\t%s\n' "$applied" "$applied" "$applied" > "$TEMP/backup/files.tsv"

printf 'later edit' > "$TEMP/home/.profile"
if HOME="$TEMP/home" bash "$RESTORE" "$TEMP/backup" 2>"$TEMP/error.log"; then
    echo "ERROR: Restore accepted a later edit." >&2
    exit 1
fi
grep -q 'Config changed after setup' "$TEMP/error.log"
test "$(cat "$TEMP/home/.bashrc")" = managed

printf managed > "$TEMP/home/.profile"
printf tampered > "$TEMP/backup/original/.bashrc"
if HOME="$TEMP/home" bash "$RESTORE" "$TEMP/backup" 2>"$TEMP/error.log"; then
    echo "ERROR: Restore accepted a modified backup." >&2
    exit 1
fi
grep -q 'Backup integrity check failed' "$TEMP/error.log"

printf original > "$TEMP/backup/original/.bashrc"
HOME="$TEMP/home" bash "$RESTORE" "$TEMP/backup"
test "$(cat "$TEMP/home/.bashrc")" = original
test ! -e "$TEMP/home/.profile"
test ! -e "$TEMP/home/.local/bin/wsl-browser"
HOME="$TEMP/home" bash "$RESTORE" "$TEMP/backup"
echo "WSL restore regression tests passed."
