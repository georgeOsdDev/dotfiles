#!/usr/bin/env bash
# Bootstrap script for WSL environment
# Managed by dotfiles - https://github.com/georgeOsdDev/dotfiles
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FAILED=()
MISE_VERSION="2026.5.15"

echo "=== dotfiles WSL bootstrap ==="
echo "Dotfiles directory: $DOTFILES_DIR"

# --- shell configs (link first so mise activation is available) ---
echo ""
echo ">>> Linking shell configs..."
ln -sf "$DOTFILES_DIR/wsl/shell/.bashrc" ~/.bashrc
ln -sf "$DOTFILES_DIR/wsl/shell/.profile" ~/.profile

# --- zsh / zim ---
echo ""
echo ">>> Setting up zsh + zim..."
if ! command -v zsh &>/dev/null; then
    echo "Installing zsh..."
    sudo apt-get update && sudo apt-get install -y zsh
fi

ln -sf "$DOTFILES_DIR/wsl/shell/.zshrc" ~/.zshrc
ln -sf "$DOTFILES_DIR/wsl/shell/.zimrc" ~/.zimrc
ln -sf "$DOTFILES_DIR/wsl/shell/.zshenv" ~/.zshenv

# Install zim modules (zim itself is bootstrapped from .zshrc on first launch)
if [ -d ~/.zim ]; then
    echo "  Updating zim modules..."
    zsh -c 'source ~/.zim/zimfw.zsh && zimfw install' 2>/dev/null || true
else
    echo "  Zim will auto-install on first zsh launch."
fi

# Set zsh as default shell if not already
if [ "$(basename "$SHELL")" != "zsh" ]; then
    echo "  Setting zsh as default shell..."
    chsh -s "$(command -v zsh)" || echo "  WARN: Could not change default shell. Run: chsh -s \$(which zsh)"
fi

# --- git config ---
echo ""
echo ">>> Linking git config..."
ln -sf "$DOTFILES_DIR/wsl/git/.gitconfig" ~/.gitconfig
if [ ! -f ~/.gitconfig.local ]; then
    echo "  Creating ~/.gitconfig.local template..."
    cat > ~/.gitconfig.local << 'EOF'
[user]
	email = your@email.com
EOF
    echo "  IMPORTANT: Edit ~/.gitconfig.local to set your email address"
fi

# --- mise ---
echo ""
echo ">>> Setting up mise..."
CURRENT_MISE_VERSION=""
if command -v mise &>/dev/null || [ -f "$HOME/.local/bin/mise" ]; then
    CURRENT_MISE_VERSION="$("$HOME/.local/bin/mise" --version 2>/dev/null | head -1 | awk '{print $1}')" || true
fi
if [ "$CURRENT_MISE_VERSION" != "$MISE_VERSION" ]; then
    echo "Installing mise $MISE_VERSION (current: ${CURRENT_MISE_VERSION:-none})..."
    MISE_VERSION="v$MISE_VERSION" curl https://mise.run | sh
fi

# Activate mise in current shell
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)" || true

echo "Linking mise config..."
mkdir -p ~/.config/mise
ln -sf "$DOTFILES_DIR/wsl/mise/config.toml" ~/.config/mise/config.toml

echo "Installing mise tools..."
mise install --yes

# Re-activate to pick up newly installed tools
eval "$(mise activate bash)" || true

# --- cargo tools ---
echo ""
echo ">>> Setting up cargo tools..."
if command -v cargo &>/dev/null; then
    # Install cargo-binstall first for faster installs
    if ! command -v cargo-binstall &>/dev/null; then
        echo "Installing cargo-binstall..."
        cargo install cargo-binstall
    fi

    # Read crates from Cargo.toml and install via binstall
    CARGO_TOML="$DOTFILES_DIR/wsl/cargo/Cargo.toml"
    if [ -f "$CARGO_TOML" ]; then
        echo "Installing cargo tools from Cargo.toml..."
        # Parse [dependencies] section, strip '=' prefix from exact versions
        awk '/^\[dependencies\]/{flag=1; next} /^\[/{flag=0} flag && /=/{
            gsub(/[" ]/, ""); split($0, a, "=");
            ver=a[2]; sub(/^=/, "", ver);
            printf "%s@%s\n", a[1], ver
        }' "$CARGO_TOML" | while read -r pkg; do
            crate="${pkg%%@*}"
            version="${pkg##*@}"
            if [ "$crate" = "cargo-binstall" ]; then
                continue
            fi
            echo "  Installing $crate@$version..."
            if ! cargo binstall --no-confirm "$crate@$version" 2>/dev/null; then
                if ! cargo install "$crate" --version "$version" 2>/dev/null; then
                    echo "  WARN: Failed to install $crate@$version"
                    FAILED+=("cargo:$crate@$version")
                fi
            fi
        done
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
    node -e "
        const pkg = require('$NPM_PKG');
        const deps = pkg.dependencies || {};
        Object.entries(deps).forEach(([name, ver]) => {
            console.log(name + '@' + ver);
        });
    " | while read -r pkg; do
        if [ -n "$pkg" ]; then
            echo "  Installing $pkg..."
            if ! npm install -g "$pkg" 2>/dev/null; then
                echo "  WARN: Failed to install $pkg"
                FAILED+=("npm:$pkg")
            fi
        fi
    done
else
    echo "SKIP: npm not found or package.json missing."
fi

echo ""
echo "=== WSL bootstrap complete! ==="
if [ ${#FAILED[@]} -gt 0 ]; then
    echo ""
    echo "WARNING: The following packages failed to install:"
    printf "  - %s\n" "${FAILED[@]}"
fi
echo ""
echo "NOTE: Restart your shell or run 'source ~/.bashrc' to apply changes."
echo "NOTE: Edit ~/.gitconfig.local to set your git email address."
