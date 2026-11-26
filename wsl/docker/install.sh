#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$EUID" -ne 0 ]; then
    if [ "$#" -ne 0 ]; then
        echo "Usage: bash wsl/docker/install.sh (sudo is requested)" >&2
        exit 2
    fi
    exec sudo -- bash "$SCRIPT_DIR/install.sh" "$(id -un)"
fi
TARGET_USER="${1:-${SUDO_USER:-}}"
if [ -z "$TARGET_USER" ] || [ "$#" -gt 1 ]; then
    echo "ERROR: Specify an existing non-root user when running as root." >&2
    exit 2
fi
TARGET_UID="$(id -u "$TARGET_USER")"
if [ "$TARGET_UID" -eq 0 ]; then
    echo "ERROR: Docker access must target a non-root user." >&2
    exit 2
fi
. "$SCRIPT_DIR/common.sh"
. /etc/os-release
if [ "$ID" != ubuntu ] || [ "$VERSION_ID" != 24.04 ] || [ "$(cat /proc/1/comm)" != systemd ]; then
    echo "ERROR: This setup requires Ubuntu 24.04 with systemd." >&2
    exit 1
fi
for tool in curl gpg; do
    command -v "$tool" >/dev/null
done
umask 077
mkdir -p /var/backups/dotfiles/docker
BACKUP_DIR="$(mktemp -d "/var/backups/dotfiles/docker/$(date -u +%Y%m%dT%H%M%SZ)-XXXXXX")"
echo "Docker recovery directory: $BACKUP_DIR"
trap 'echo "ERROR: Docker setup failed. Recovery directory: $BACKUP_DIR" >&2' ERR
printf 'in-progress\n' > "$BACKUP_DIR/status"
finalize() {
    local result=$?
    trap - EXIT
    if [ -f "$BACKUP_DIR/services-before.tsv" ]; then
        if snapshot_services > "$BACKUP_DIR/services-after.tsv.tmp"; then
            mv "$BACKUP_DIR/services-after.tsv.tmp" "$BACKUP_DIR/services-after.tsv"
        else
            rm -f "$BACKUP_DIR/services-after.tsv.tmp"
            echo "ERROR: Could not record final service states; manual recovery is required." >&2
            result=1
        fi
    fi
    if ! dpkg-query -W -f='${binary:Package}\t${Status}\t${Version}\n' > "$BACKUP_DIR/packages-after.tsv"; then
        echo "ERROR: Could not record final package state." >&2
        result=1
    fi
    if [ "$result" -eq 0 ]; then printf 'complete\n'; else printf 'failed\n'; fi > "$BACKUP_DIR/status"
    exit "$result"
}
trap finalize EXIT
printf '%s\n' "$TARGET_USER" > "$BACKUP_DIR/user"
if id -nG "$TARGET_USER" | tr ' ' '\n' | grep -Fxq docker; then
    printf '1\n' > "$BACKUP_DIR/member-before"
else
    printf '0\n' > "$BACKUP_DIR/member-before"
fi
snapshot_services > "$BACKUP_DIR/services-before.tsv"
dpkg-query -W -f='${binary:Package}\t${Status}\t${Version}\n' > "$BACKUP_DIR/packages-before.tsv"
touch "$BACKUP_DIR/files-created.tsv"

missing=()
for package in "${DOCKER_PACKAGES[@]}"; do
    if ! package_installed "$package"; then missing+=("$package"); fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    for package in docker.io docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd runc; do
        if package_installed "$package"; then
            echo "ERROR: Existing $package conflicts with Docker CE; refusing to remove or replace it." >&2
            exit 1
        fi
    done
fi
repo_exists=0
while IFS= read -r -d '' source; do
    if grep -Fq 'download.docker.com/linux/ubuntu' "$source"; then repo_exists=1; fi
done < <(find /etc/apt/sources.list.d -maxdepth 1 -type f \
    \( -name '*.list' -o -name '*.sources' \) -print0)
if [ -f /etc/apt/sources.list ] &&
    grep -Fq 'download.docker.com/linux/ubuntu' /etc/apt/sources.list; then repo_exists=1; fi
if [ "$repo_exists" -eq 0 ]; then
    key=/etc/apt/keyrings/dotfiles-docker.asc
    source=/etc/apt/sources.list.d/dotfiles-docker.sources
    for path in "$key" "$source"; do
        if [ -e "$path" ] || [ -L "$path" ]; then
            echo "ERROR: Reserved Docker configuration already exists: $path" >&2
            exit 1
        fi
    done
    curl --proto '=https' --tlsv1.2 -fsSL https://download.docker.com/linux/ubuntu/gpg \
        -o "$BACKUP_DIR/docker.asc"
    mkdir -m 0700 "$BACKUP_DIR/gnupg"
    fingerprint="$(gpg --homedir "$BACKUP_DIR/gnupg" --show-keys --with-colons "$BACKUP_DIR/docker.asc" |
        awk -F: '$1 == "fpr" {print $10; exit}')"
    if [ "$fingerprint" != 9DC858229FC7DD38854AE2D88D81803C0EBFCD88 ]; then
        echo "ERROR: Unexpected Docker repository signing key." >&2
        exit 1
    fi
    install -d -m 0755 /etc/apt/keyrings
    install -m 0644 "$BACKUP_DIR/docker.asc" "$key"
    printf '%s\t%s\n' "$key" "$(sha256sum "$key" | cut -d' ' -f1)" >> "$BACKUP_DIR/files-created.tsv"
    cat > "$BACKUP_DIR/docker.sources" <<EOF
# Managed by dotfiles
Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: noble
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: $key
EOF
    install -m 0644 "$BACKUP_DIR/docker.sources" "$source"
    printf '%s\t%s\n' "$source" "$(sha256sum "$source" | cut -d' ' -f1)" >> "$BACKUP_DIR/files-created.tsv"
fi
if [ "$repo_exists" -eq 0 ] || [ "${#missing[@]}" -gt 0 ]; then
    apt-get update
fi
if [ "${#missing[@]}" -gt 0 ]; then
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends --no-upgrade --no-remove "${missing[@]}"
fi
if ! getent group docker >/dev/null; then groupadd docker; fi
if [ "$(cat "$BACKUP_DIR/member-before")" = 0 ]; then
    usermod -aG docker "$TARGET_USER"
fi
systemctl enable --now containerd.service docker.socket docker.service
runuser -u "$TARGET_USER" -- docker --host unix:///var/run/docker.sock version --format '{{.Server.Version}}'
runuser -u "$TARGET_USER" -- docker compose version
runuser -u "$TARGET_USER" -- docker buildx version
echo "Docker Engine and Compose are ready; Docker Desktop was not installed."
echo "Reconnect WSL/VS Code to refresh docker group membership."
