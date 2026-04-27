# dotfiles

Cross-platform dotfiles for Windows (winget) and WSL (mise, cargo, npm) environments.

## What's managed

| Tool | Config File | Auto-update |
|------|------------|-------------|
| **winget** (Windows) | `windows/winget-packages.json` | Manual (`winget upgrade`) |
| **mise** (WSL) | `wsl/mise/config.toml` | Renovate (mise manager) |
| **cargo** (WSL) | `wsl/cargo/Cargo.toml` | Renovate (cargo manager) |
| **npm** (WSL) | `wsl/npm/package.json` | Renovate (npm manager) |
| **PowerShell** | `windows/PowerShell/Microsoft.PowerShell_profile.ps1` | Manual |
| **bash** | `wsl/shell/.bashrc`, `wsl/shell/.profile` | Manual |
| **git** | `wsl/git/.gitconfig` | Manual |

## Quick Start

### New Windows Machine

```powershell
# 1. Clone this repo
git clone https://github.com/georgeOsdDev/dotfiles.git ~/dotfiles

# 2. Run bootstrap (requires admin for symlinks)
~/dotfiles/install.ps1
```

### New WSL Environment

```bash
# 1. Clone this repo
git clone https://github.com/georgeOsdDev/dotfiles.git ~/dotfiles

# 2. Run bootstrap
chmod +x ~/dotfiles/install.sh
~/dotfiles/install.sh
```

## Adding Packages

### winget (Windows)

Edit `windows/winget-packages.json` and add:
```json
{ "PackageIdentifier": "Author.PackageName" }
```

### mise (WSL)

Edit `wsl/mise/config.toml`:
```toml
[tools]
newtool = "1.2.3"
```

### cargo (WSL)

Edit `wsl/cargo/Cargo.toml`:
```toml
[dependencies]
new-crate = "1.0.0"
```

### npm (WSL)

Edit `wsl/npm/package.json` and add to `dependencies`.

## Auto-update with Renovate

This repo uses [Renovate](https://github.com/apps/renovate) to automatically create PRs when new versions are available.

- **Patch updates**: auto-merged
- **Minor/Major updates**: require manual review
- **Schedule**: Monday mornings (JST)

### Setup

1. Install the [Renovate GitHub App](https://github.com/apps/renovate) on this repository
2. Renovate will automatically detect `renovate.json` and start creating PRs

## Manual Update

### Update all mise tools
```bash
mise upgrade
# Then update wsl/mise/config.toml with new versions
mise ls --current  # check current versions
```

### Update all cargo tools
```bash
cargo install-update -a
# Or reinstall from Cargo.toml
```

### Update winget packages
```powershell
winget upgrade --all
# Then re-export: winget export -o windows/winget-packages.json
```

## Security Notes

- **Never commit credentials** — use `.gitconfig.local` for email/credentials
- SSH keys and tokens are excluded via `.gitignore`
- Renovate automerge is limited to patch versions only
