#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMP="$(mktemp -d)"
cleanup() {
    find "$TEMP" -type f -delete
    find "$TEMP" -type l -delete
    find "$TEMP" -depth -type d -empty -delete
}
trap cleanup EXIT
dpkg-query() {
    if [ "$#" -eq 2 ]; then
        printf 'existing\tinstall ok installed\t1.0\n'
    elif [ "${*: -1}" = curl ] && [ "$SCENARIO" = missing ]; then
        return 1
    else
        printf 'install ok installed'
    fi
}
sudo() { printf '%s\n' "$*" >> "$APT_LOG"; }
git() {
    echo "ERROR: Test Git configuration is unreadable." >&2
    return 23
}
export -f dpkg-query sudo git
for SCENARIO in installed missing; do
    export SCENARIO APT_LOG="$TEMP/$SCENARIO-apt.log"
    mkdir -p "$TEMP/$SCENARIO"
    : > "$APT_LOG"
    if HOME="$TEMP/$SCENARIO" DOTFILES_SKIP_CHSH=1 \
        bash "$ROOT/install.sh" > "$TEMP/$SCENARIO-output.log" 2>&1; then
        echo "ERROR: Bootstrap must stop when existing Git settings cannot be read." >&2
        exit 1
    else
        test "$?" -eq 23
    fi
    grep -q 'Could not read Git includes: 23' "$TEMP/$SCENARIO-output.log"
    if [ "$SCENARIO" = installed ]; then
        test ! -s "$APT_LOG"
    else
        test "$(cat "$APT_LOG")" = $'apt-get update\napt-get install -y --no-upgrade --no-remove curl'
    fi
    mapfile -t inventories < <(find "$TEMP/$SCENARIO/.local/state/dotfiles/backups" \
        -name 'packages-*.tsv')
    test "${#inventories[@]}" -eq 2
    cmp "${inventories[0]}" "${inventories[1]}"
done
echo "WSL prerequisite and Git-failure regression tests passed."
