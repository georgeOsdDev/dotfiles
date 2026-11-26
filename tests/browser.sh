#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -f "$TMP_DIR/powershell.exe" "$TMP_DIR/errors"; rmdir "$TMP_DIR"' EXIT
cat > "$TMP_DIR/powershell.exe" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$DOTFILES_BROWSER_URL" "$WSLENV"
exit "${FAKE_PS_EXIT:-0}"
EOF
chmod +x "$TMP_DIR/powershell.exe"
export PATH="$TMP_DIR:$PATH"
export WSLENV=EXISTING_VARIABLE/u
URL='https://example.com/?a=1&b=%2Fvalue+two&c=$(echo not-command);"quoted"#fragment'
actual="$(bash "$ROOT/wsl/browser/open.sh" "$URL")"
test "$actual" = "$URL"$'\nEXISTING_VARIABLE/u:DOTFILES_BROWSER_URL/w'
if bash "$ROOT/wsl/browser/open.sh" 'file:///tmp/private' >/dev/null 2>"$TMP_DIR/errors"; then
    echo "ERROR: Non-HTTP URLs must be refused." >&2
    exit 1
fi
grep -q 'Expected an HTTP(S) URL' "$TMP_DIR/errors"
if FAKE_PS_EXIT=42 bash "$ROOT/wsl/browser/open.sh" "$URL" >/dev/null; then
    echo "ERROR: Windows launcher failures must propagate." >&2
    exit 1
else
    test "$?" -eq 42
fi
echo "Browser bridge regression tests passed."
