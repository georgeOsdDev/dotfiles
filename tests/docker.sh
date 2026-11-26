#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$ROOT/wsl/docker/common.sh"
ERROR_LOG="$(mktemp)"
trap 'rm -f "$ERROR_LOG"' EXIT
MODE=missing
systemctl() {
    local unit="$2" property="$3"
    case "$property" in
        --property=LoadState)
            if [ "$MODE" = query-failed ]; then
                echo loaded
                echo "ERROR: Service query failed." >&2
                return 1
            fi
            if [ "$MODE" = missing ]; then echo not-found; else echo loaded; fi ;;
        --property=UnitFileState)
            if [ "$MODE" = masked ]; then echo masked; else echo enabled; fi ;;
        --property=ActiveState)
            if [ "$MODE" = failed ] && [ "$unit" = docker.service ]; then echo failed; else echo active; fi ;;
        *) return 1 ;;
    esac
}
test "$(service_state docker.service)" = $'docker.service\tnot-found\tinactive'
MODE=masked
if service_state docker.service >/dev/null 2>"$ERROR_LOG"; then
    echo "ERROR: Masked services must not be silently changed." >&2
    exit 1
fi
grep -q 'Unsupported service state' "$ERROR_LOG"
MODE=failed
if snapshot_services >/dev/null 2>"$ERROR_LOG"; then
    echo "ERROR: A later healthy service must not hide an earlier snapshot failure." >&2
    exit 1
fi
grep -q 'Investigate docker.service' "$ERROR_LOG"
MODE=query-failed
if snapshot_services >/dev/null 2>"$ERROR_LOG"; then
    echo "ERROR: Failed service queries must not produce successful snapshots." >&2
    exit 1
fi
grep -q 'Service query failed' "$ERROR_LOG"
echo "Docker service-state regression tests passed."
