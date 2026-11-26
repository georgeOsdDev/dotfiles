# Reproducible Windows and WSL setup

When given this repository to prepare a machine, read
[README.md](README.md), [setup and recovery](windows/DEVBOX-SETUP.md) and
[repository conventions](.github/copilot-instructions.md) first.

## Before changes

- Confirm the target OS, existing tools, Windows/WSL scope, repository
  location and optional Docker requirement. Supported setup: Windows with
  PowerShell 7/winget and Ubuntu 24.04 on WSL 2.
- Use `~/dotfiles` separately on Windows and in the Linux home directory.
  Windows profiles intentionally resolve the repository at that location.
- Inspect versions, shell/profile paths, PATH and Terminal settings without
  printing identities, tokens, environment secrets or credential files.
  Documents/profile paths can be redirected to OneDrive.
- Record the proposed changes and private backup location before execution.
  Do not replace existing customizations blindly. Work on a Git branch
  when editing repository files; do not publish without approval.
- Ask before Docker's root-equivalent group access, automatic service
  startup, restarts that interrupt work, or unrelated package upgrades.

## Execution order

1. Ensure winget, Git and PowerShell 7 exist; follow the README prerequisites.
   Run `install.ps1 -SkipTerminal` without elevation. Existing Windows
   applications must not be upgraded by setup.
2. Check `wsl --list --verbose`. Install/initialize Ubuntu 24.04 only if
   absent; require WSL 2. The user enters the Linux password locally.
3. Clone into Linux `~/dotfiles`, review the pinned configuration and run
   `bash install.sh` as the normal Ubuntu user. It installs missing APT
   prerequisites, trusts the reviewed mise configs and installs pinned
   tools. If shell-changing authentication is unavailable, use
   `DOTFILES_SKIP_CHSH=1` and arrange `chsh` with the user afterward.
4. Open Windows Terminal so its Ubuntu profile is generated. Reapply
   `install.ps1` without `-SkipTerminal` for the managed font/theme and
   terminal preferences. Preserve local profile GUIDs and unrelated options.
5. If approved, run the separate Docker installer described in
   [wsl/docker/README.md](wsl/docker/README.md). Docker Desktop is unnecessary.
6. Configure Git identity in private `~/.gitconfig.local`; the user completes
   `gh auth login --web` and `az login` locally. Never copy credentials between
   machines or into tracked files.

## Verify the actual outcome

- In new Windows PowerShell and Ubuntu zsh terminals, check Git, Node,
  Python, mise/Cargo tools, prompt initialization and `fzf`/Ctrl+R.
- Confirm Terminal fonts, black Campbell background, default Ubuntu tab
  and preserved unrelated profiles. Reopen Terminal to refresh installed fonts.
- Open a public URL with `wsl-browser`, then let the user test `az login`.
  An already-running shell or VS Code server can retain old environment data.
- For Docker, verify normal-user `docker version`, Compose, Buildx and a
  disposable container. Let the user verify their own **Reopen in Container**.
  Do not restart WSL or terminate other work to refresh groups automatically.
- Run the validation commands in the setup document. State limitations:
  tests do not replace a full fresh-machine installation.
- Report backup paths, changes, checks and any remaining user actions.
  Recovery restores settings, not installed packages/fonts or Docker data.
  Restore multiple runs in reverse order and refuse drift or damaged backups.

## Repository changes

Keep exact mise versions, exact `=version` Cargo pins and standard npm ranges.
Keep shell files LF. Never commit backups, credential files, machine-specific
exports, authentication output or private Git identity. Before publication,
refresh the intended staging, review the complete payload, validate CI, and
preserve unrelated user changes.
