#!/usr/bin/env bash
DOCKER_PACKAGES=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
DOCKER_UNITS=(docker.service docker.socket containerd.service)

package_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -Fxq 'install ok installed'
}

service_state() {
    local unit="$1" load enabled active
    load="$(systemctl show "$unit" --property=LoadState --value)" || return $?
    if [ "$load" = not-found ]; then
        enabled=not-found
        active=inactive
    else
        enabled="$(systemctl show "$unit" --property=UnitFileState --value)" || return $?
        active="$(systemctl show "$unit" --property=ActiveState --value)" || return $?
    fi
    case "$enabled" in
        enabled|disabled|not-found) ;;
        *) echo "ERROR: Unsupported service state for $unit: $enabled" >&2; return 1 ;;
    esac
    case "$active" in
        active|inactive) ;;
        *) echo "ERROR: Investigate $unit before changing it: $active" >&2; return 1 ;;
    esac
    printf '%s\t%s\t%s\n' "$unit" "$enabled" "$active"
}

snapshot_services() {
    local unit
    for unit in "${DOCKER_UNITS[@]}"; do
        if ! service_state "$unit"; then return 1; fi
    done
}
