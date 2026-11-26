#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$#" -ne 1 ]; then
    echo "Usage: bash wsl/docker/restore.sh BACKUP_DIRECTORY" >&2
    exit 2
fi
if [ "$EUID" -ne 0 ]; then
    exec sudo -- bash "$SCRIPT_DIR/restore.sh" "$@"
fi
BACKUP_DIR="$(realpath "${1:?Usage: bash wsl/docker/restore.sh BACKUP_DIRECTORY}")"
case "$BACKUP_DIR" in
    /var/backups/dotfiles/docker/*) ;;
    *) echo "ERROR: Expected a Docker backup under /var/backups/dotfiles/docker." >&2; exit 1 ;;
esac
. "$SCRIPT_DIR/common.sh"
TARGET_USER="$(cat "$BACKUP_DIR/user")"
member_before="$(cat "$BACKUP_DIR/member-before")"
case "$member_before" in 0|1) ;; *) echo "ERROR: Invalid membership snapshot." >&2; exit 1 ;; esac
id "$TARGET_USER" >/dev/null
if [ "$(id -u "$TARGET_USER")" -eq 0 ]; then
    echo "ERROR: Refusing a root-user membership snapshot." >&2
    exit 1
fi

while IFS=$'\t' read -r path hash; do
    case "$path" in
        /etc/apt/keyrings/dotfiles-docker.asc|/etc/apt/sources.list.d/dotfiles-docker.sources) ;;
        *) echo "ERROR: Unexpected restore target: $path" >&2; exit 1 ;;
    esac
    if [ -L "$path" ] || { [ -e "$path" ] && [ "$(sha256sum "$path" | cut -d' ' -f1)" != "$hash" ]; }; then
        echo "ERROR: Docker APT file changed after setup; reconcile manually: $path" >&2
        exit 1
    fi
done < "$BACKUP_DIR/files-created.tsv"

if [ ! -f "$BACKUP_DIR/services-after.tsv" ]; then
    echo "ERROR: Setup failed before service snapshots completed. Inspect the backup before manual recovery." >&2
    exit 1
fi
for unit in "${DOCKER_UNITS[@]}"; do
    before="$(awk -F '\t' -v unit="$unit" '$1 == unit {print $2 "\t" $3}' "$BACKUP_DIR/services-before.tsv")"
    after="$(awk -F '\t' -v unit="$unit" '$1 == unit {print $2 "\t" $3}' "$BACKUP_DIR/services-after.tsv")"
    current="$(service_state "$unit" | cut -f2-)"
    restored="${before/not-found/disabled}"
    if [ "$current" != "$before" ] && [ "$current" != "$after" ] && [ "$current" != "$restored" ]; then
        echo "ERROR: $unit changed after setup; reconcile manually." >&2
        exit 1
    fi
done
if [ "$(systemctl show docker.service --property=ActiveState --value)" = active ]; then
    running="$(docker --host unix:///var/run/docker.sock ps -q)"
    if [ -n "$running" ]; then
        echo "ERROR: Running containers exist. Stop them explicitly before restoring Docker settings." >&2
        exit 1
    fi
fi
for unit in docker.socket docker.service containerd.service; do
    IFS=$'\t' read -r enabled active < <(awk -F '\t' -v unit="$unit" \
        '$1 == unit {print $2 "\t" $3}' "$BACKUP_DIR/services-before.tsv")
    if [ "$enabled" = not-found ] &&
        [ "$(systemctl show "$unit" --property=LoadState --value)" = not-found ]; then
        continue
    fi
    case "$enabled" in
        enabled) systemctl enable "$unit" ;;
        disabled|not-found) systemctl disable "$unit" ;;
        *) echo "ERROR: Unsupported original service state: $unit" >&2; exit 1 ;;
    esac
    if [ "$active" = active ]; then systemctl start "$unit"; else systemctl stop "$unit"; fi
done
if [ "$member_before" = 0 ] && id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq docker; then
    gpasswd -d "$TARGET_USER" docker
fi
while IFS=$'\t' read -r path hash; do
    rm -f -- "$path"
done < "$BACKUP_DIR/files-created.tsv"
printf 'restored\n' > "$BACKUP_DIR/status"
echo "Docker settings restored. Reconnect WSL/VS Code to refresh group membership."
echo "Packages, the docker group, images, volumes and container data were not deleted."
