# Copilot Instructions for dotfiles

## Repository Overview
This is a cross-platform dotfiles repository managing software packages and configurations for Windows (winget) and WSL (mise, cargo, npm).

## Key Conventions

### Version Pinning
- **mise** (`wsl/mise/config.toml`): Always use exact version numbers (e.g., `node = "24.12.0"`), never `latest` or `lts`. Renovate requires exact versions to detect updates.
- **cargo** (`wsl/cargo/Cargo.toml`): Always use exact version pins with `=` prefix (e.g., `bat = "=0.26.1"`).
- **npm** (`wsl/npm/package.json`): Use standard semver ranges in `dependencies`.

### File Structure
- `windows/` — Windows-specific configs (winget, PowerShell)
- `wsl/` — WSL-specific configs (mise, cargo, npm, shell, git)
  - `wsl/shell/` — bash (.bashrc, .profile) and zsh + zim (.zshrc, .zimrc, .zshenv)
- `.github/` — Renovate config and CI workflows
- `install.sh` — WSL bootstrap script (installs zsh, links configs, sets up tools)
- `install.ps1` — Windows bootstrap script

### Security Rules
- **Never** commit email addresses, passwords, tokens, SSH keys, or API keys.
- Git email should be configured in `~/.gitconfig.local` (not tracked).
- The `.gitignore` excludes common secret file patterns.

### When Adding New Packages
- **winget**: Add `{ "PackageIdentifier": "Author.Package" }` to `windows/winget-packages.json`.
- **mise**: Add `toolname = "x.y.z"` (pinned) to `wsl/mise/config.toml`.
- **cargo**: Add `crate-name = "=x.y.z"` (exact pin) to `wsl/cargo/Cargo.toml` under `[dependencies]`.
- **npm**: Add to `dependencies` in `wsl/npm/package.json`.

### When Updating Versions
- Renovate handles automatic updates for mise, cargo, and npm via PR.
- winget is managed manually — run `winget upgrade --all` and update the JSON.
- After version changes, ensure `install.sh` / `install.ps1` still work correctly.

### Bootstrap Scripts
- `install.sh`: Links configs first (shell, git), then installs tools (mise → cargo → npm). Reports failures at the end.
- `install.ps1`: Installs winget packages, PowerShell modules, then links profile.
- Both scripts are idempotent — safe to re-run.

### CI / Validation
- `.github/workflows/validate.yml` runs on PRs to `main`: validates JSON, TOML syntax, and shell script syntax.
- Keep the workflow passing for all changes.
