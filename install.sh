#!/usr/bin/env bash
# Bootstrap script for WSL environment
# Managed by dotfiles - https://github.com/georgeOsdDev/dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Run the WSL bootstrap as your normal user; sudo is requested for APT only." >&2
    exit 1
fi
. /etc/os-release
if [ "$ID" != ubuntu ] || [ "$VERSION_ID" != 24.04 ]; then
    echo "ERROR: This bootstrap is tested on Ubuntu 24.04." >&2
    exit 1
fi
FAILED=()
MISE_VERSION="2026.10.19"
BACKUP_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/backups/$(date -u +%Y%m%dT%H%M%SZ)-$$"
mkdir -p "$BACKUP_DIR"
chmod 700 "$BACKUP_DIR"
getent passwd "$(id -un)" | cut -d: -f7 > "$BACKUP_DIR/login-shell"
touch "$BACKUP_DIR/files.tsv"
echo "Recovery directory: $BACKUP_DIR"
trap 'echo "ERROR: Setup failed. Recovery directory: $BACKUP_DIR" >&2' ERR

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

backup_config() {
    local relative="$1" destination="$HOME/$1" original
    original="$(fingerprint "$destination")"
    mkdir -p "$BACKUP_DIR/original/$(dirname "$relative")"
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        cp -a "$destination" "$BACKUP_DIR/original/$relative"
    fi
    printf '%s\t%s\n' "$relative" "$original" >> "$BACKUP_DIR/original.tsv"
}

record_config() {
    printf '%s\t%s\n' "$1" "$(fingerprint "$HOME/$1")" >> "$BACKUP_DIR/files.tsv"
}

link_config() {
    local source="$1" relative="$2" destination="$HOME/$2"
    if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
        return
    fi
    backup_config "$relative"
    mkdir -p "$(dirname "$destination")"
    ln -sfn "$source" "$destination"
    record_config "$relative"
}

echo "=== dotfiles WSL bootstrap ==="
echo "Dotfiles directory: $DOTFILES_DIR"

echo ">>> Checking APT prerequisites..."
dpkg-query -W -f='${binary:Package}\t${Status}\t${Version}\n' > "$BACKUP_DIR/packages-before.tsv"
missing=()
for package in ca-certificates curl git unzip gnupg zsh build-essential pkg-config libssl-dev libicu74; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -Fxq 'install ok installed'; then
        missing+=("$package")
    fi
done
if [ "${#missing[@]}" -gt 0 ]; then
    sudo apt-get update
    sudo apt-get install -y --no-upgrade --no-remove "${missing[@]}"
fi
dpkg-query -W -f='${binary:Package}\t${Status}\t${Version}\n' > "$BACKUP_DIR/packages-after.tsv"

if [ -e /proc/sys/fs/binfmt_misc/WSLInterop ]; then
    echo ">>> Installing Windows browser bridge..."
    if ! command -v powershell.exe >/dev/null 2>&1; then
        echo "ERROR: Windows PowerShell is unavailable. Check WSL interop and Windows PATH." >&2
        exit 1
    fi
    BROWSER_SOURCE="$DOTFILES_DIR/wsl/browser/open.sh"
    BROWSER_TARGET="$HOME/.local/bin/wsl-browser"
    if [ "$(fingerprint "$BROWSER_TARGET")" != "$(fingerprint "$BROWSER_SOURCE")" ] ||
        [ ! -x "$BROWSER_TARGET" ]; then
        backup_config .local/bin/wsl-browser
        mkdir -p "$HOME/.local/bin"
        rm -f -- "$BROWSER_TARGET"
        install -m 0755 "$BROWSER_SOURCE" "$BROWSER_TARGET"
        record_config .local/bin/wsl-browser
    fi
fi

# --- shell configs (link first so mise activation is available) ---
echo ""
echo ">>> Linking shell configs..."
link_config "$DOTFILES_DIR/wsl/shell/.bashrc" .bashrc
link_config "$DOTFILES_DIR/wsl/shell/.profile" .profile

# --- zsh / zim ---
echo ""
echo ">>> Setting up zsh + zim..."
link_config "$DOTFILES_DIR/wsl/shell/.zshrc" .zshrc
link_config "$DOTFILES_DIR/wsl/shell/.zimrc" .zimrc
link_config "$DOTFILES_DIR/wsl/shell/.zshenv" .zshenv

# Install zim modules (zim itself is bootstrapped from .zshrc on first launch)
if [ -d ~/.zim ]; then
    echo "  Updating zim modules..."
    if ! ZIM_HOME="$HOME/.zim" GIT_TERMINAL_PROMPT=0 \
        zsh -c 'source "$ZIM_HOME/zimfw.zsh" install'; then
        FAILED+=("zim:modules")
    fi
else
    echo "  Zim will auto-install on first zsh launch."
fi

# Set zsh as default shell if not already
if [ "${DOTFILES_SKIP_CHSH:-0}" != 1 ] &&
    [ "$(basename "$(cat "$BACKUP_DIR/login-shell")")" != "zsh" ]; then
    echo "  Setting zsh as default shell..."
    if ! chsh -s "$(command -v zsh)"; then
        echo "WARN: Could not change login shell. Run chsh locally." >&2
        FAILED+=("shell:chsh")
    fi
fi

# --- git config ---
echo ""
echo ">>> Linking git config..."
GIT_CONFIG="$DOTFILES_DIR/wsl/git/.gitconfig"
if includes="$(git config --global --get-all include.path)"; then
    :
else
    result=$?
    if [ "$result" -ne 1 ]; then
        echo "ERROR: Could not read Git includes: $result" >&2
        exit "$result"
    fi
fi
if ! printf '%s\n' "$includes" | grep -Fxq "$GIT_CONFIG"; then
    backup_config .gitconfig
    git config --global --add include.path "$GIT_CONFIG"
    record_config .gitconfig
fi
echo "  Set personal Git identity privately in ~/.gitconfig.local."

# --- mise ---
echo ""
echo ">>> Setting up mise..."
CURRENT_MISE_VERSION=""
if command -v mise &>/dev/null; then
    CURRENT_MISE_VERSION="$(mise --version | awk 'NR==1 {print $1}')"
elif [ -x "$HOME/.local/bin/mise" ]; then
    CURRENT_MISE_VERSION="$("$HOME/.local/bin/mise" --version | awk 'NR==1 {print $1}')"
fi
if [ "$CURRENT_MISE_VERSION" != "$MISE_VERSION" ]; then
    echo "Installing mise $MISE_VERSION (current: ${CURRENT_MISE_VERSION:-none})..."
    curl -fsSL https://mise.run | MISE_VERSION="v$MISE_VERSION" sh
fi

# Activate mise in current shell
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
eval "$(mise activate bash)"

echo "Linking mise config..."
mkdir -p ~/.config/mise
link_config "$DOTFILES_DIR/wsl/mise/config.toml" .config/mise/config.toml

mise trust "$DOTFILES_DIR/wsl/mise/config.toml"
mise trust "$DOTFILES_DIR/mise.toml"
echo "Installing mise tools..."
mise install --yes

# Re-activate to pick up newly installed tools
eval "$(mise activate bash)"

echo "Updating Python trust packages..."
uv pip install --python "$(mise which python)" --upgrade "pip>=26.2.2" "certifi>=2026.10.19"

# --- cargo tools ---
echo ""
echo ">>> Setting up cargo tools..."
if command -v cargo &>/dev/null; then
    # Read crates from Cargo.toml and install via binstall
    CARGO_TOML="$DOTFILES_DIR/wsl/cargo/Cargo.toml"
    if [ -f "$CARGO_TOML" ]; then
        BINSTALL_VERSION="$(awk -F '"' '/^cargo-binstall[[:space:]]*=/{sub(/^=/, "", $2); print $2}' "$CARGO_TOML")"
        echo "Installing cargo-binstall@$BINSTALL_VERSION..."
        cargo install cargo-binstall --version "=$BINSTALL_VERSION" --locked

        echo "Installing cargo tools from Cargo.toml..."
        while read -r pkg; do
            crate="${pkg%%@*}"
            version="${pkg##*@}"
            if [ "$crate" = "cargo-binstall" ]; then
                continue
            fi
            echo "  Installing $crate@$version..."
            if ! cargo binstall --no-confirm "$crate@$version"; then
                if ! cargo install "$crate" --version "=$version" --locked; then
                    echo "  WARN: Failed to install $crate@$version"
                    FAILED+=("cargo:$crate@$version")
                fi
            fi
        done < <(awk '/^\[dependencies\]/{flag=1; next} /^\[/{flag=0} flag && /=/{
            gsub(/["[:space:]]/, ""); split($0, a, "=");
            ver=$0; sub(/^[^=]*=/, "", ver); sub(/^=/, "", ver);
            printf "%s@%s\n", a[1], ver
        }' "$CARGO_TOML")
    fi
else
    echo "WARN: cargo not found. Install rust via mise first, then re-run."
    FAILED+=("cargo:not-found")
fi

# --- npm global packages ---
echo ""
echo ">>> Setting up npm global packages..."
NPM_PKG="$DOTFILES_DIR/wsl/npm/package.json"
if command -v npm &>/dev/null && [ -f "$NPM_PKG" ]; then
    NPM_SPECS="$(node -e '
        const pkg = require(process.argv[1]);
        Object.entries(pkg.dependencies || {}).forEach(([name, ver]) => {
            console.log(name + "@" + ver);
        });
    ' "$NPM_PKG")"
    while read -r pkg; do
        if [ -n "$pkg" ]; then
            echo "  Installing $pkg..."
            if ! npm install -g "$pkg"; then
                echo "  WARN: Failed to install $pkg" >&2
                FAILED+=("npm:$pkg")
            fi
        fi
    done <<< "$NPM_SPECS"
else
    echo "ERROR: npm not found or package.json missing." >&2
    FAILED+=("npm:missing")
fi

echo ""
if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: The following packages failed to install:"
    printf "  - %s\n" "${FAILED[@]}"
    exit 1
fi
echo "=== WSL bootstrap complete! ==="
echo ""
echo "NOTE: Restart your shell to apply changes."
echo "NOTE: Edit ~/.gitconfig.local to set your git email address."
