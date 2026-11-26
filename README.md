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
| **zsh + zim** | `wsl/shell/.zshrc`, `wsl/shell/.zimrc`, `wsl/shell/.zshenv` | Manual |
| **git** | `windows/git/.gitconfig`, `wsl/git/.gitconfig` | Manual |

## Quick Start

For AI-assisted setup, share this repository URL and ask the assistant to
follow [AGENTS.md](AGENTS.md). It defines inspection, consent, execution,
verification and recovery; passwords and authentication remain local.

### New Windows Machine

Prerequisites: Windows with winget, Git and PowerShell 7. If Git or
PowerShell 7 is missing, install only the missing prerequisite:

```powershell
winget install --id Git.Git --exact --no-upgrade
winget install --id Microsoft.PowerShell --exact --no-upgrade
```

Then open a new **PowerShell 7** window so the installed commands are on PATH.
Run the bootstrap without elevation; individual installers can request
their own elevation. Install VS Code separately if it is not already present.

```powershell
# 1. Clone this repo
git clone https://github.com/georgeOsdDev/dotfiles.git ~/dotfiles

# 2. Run bootstrap with PowerShell 7
pwsh -NoProfile -File "$HOME\dotfiles\install.ps1" -SkipTerminal
```

See [Dev Box setup and recovery](windows/DEVBOX-SETUP.md) for the recorded
plan, private backups, authentication, WSL setup and rollback.
Existing applications are kept; stale winget versions are not forced.
After initializing Ubuntu and opening Windows Terminal, rerun without
`-SkipTerminal` to apply the managed fonts and terminal preferences.

### New WSL Environment

Initialize Ubuntu 24.04 on WSL 2 first (see the setup document). Run as your
normal Linux user, not root. The bootstrap installs missing APT prerequisites
and requires sudo access and network access to the configured tool sources.

```bash
# 1. Clone this repo
git clone https://github.com/georgeOsdDev/dotfiles.git ~/dotfiles

# 2. Run bootstrap
bash ~/dotfiles/install.sh
```

## Optional Docker for WSL Dev Containers

For Docker Engine/Compose without Docker Desktop, see
[WSL Docker setup and recovery](wsl/docker/README.md).
This is an optional system-level setup, not a mise/cargo package.

```bash
bash ~/dotfiles/wsl/docker/install.sh
```

The `docker` group grants root-equivalent access inside Ubuntu. Review the
documented privileges and backup/recovery steps before running.

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
new-crate = "=1.0.0"
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
