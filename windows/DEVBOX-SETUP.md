# Dev Box setup and recovery

For an AI-assisted setup on another machine, start with [AGENTS.md](../AGENTS.md).
Supported targets are Windows with winget/PowerShell 7 and Ubuntu 24.04 on
WSL 2. Use `~/dotfiles` on each OS; do not reuse the Windows clone through
`/mnt/c` for the installed Linux shell configuration.

## Recorded plan

1. Inspect installed tools and existing user settings without printing secrets.
2. Work on a setup branch; keep private backups outside Git and OneDrive.
3. Install missing Windows packages, not older pinned versions. Do not
   upgrade existing applications automatically.
4. Install Python with uv and user-scoped PowerShell modules. Preserve
   existing profiles and Git settings; add a portable dotfiles loader.
   Install Hack and 0xProto Nerd Fonts for the current user. Back up Windows
   Terminal settings and migrate the previous PC's appearance, copy/key
   behavior and default Ubuntu tab. Cache M365Princess outside Git.
5. Install Ubuntu 24.04 if absent, then clone into its Linux home directory
   and run a backed-up WSL bootstrap.
   Optionally install Docker Engine/Compose using the separate
   [WSL Docker plan and recovery](../wsl/docker/README.md), without Docker Desktop.
6. Validate shell startup, Git, tool availability, repeat setup and recovery.
7. Review staged files for sensitive data and publish a pull request.

## Windows

Use PowerShell 7:

```powershell
pwsh -NoProfile -File .\install.ps1
# Reapply settings without reinstalling tools:
pwsh -NoProfile -File .\install.ps1 -SkipPackages -SkipPython -SkipModules
```

For a fresh Windows-only setup, pass `-SkipTerminal` until Ubuntu is
initialized and Windows Terminal has generated its **Ubuntu-24.04** profile.
Then rerun without that switch to migrate terminal preferences.

Each run prints a manifest under
`$env:LOCALAPPDATA\dotfiles\backups\<unique-id>`. It records original files,
checksums, user PATH and private package inventories. Never publish backups.
Errors are reported explicitly; configuration is applied after tool setup.
Symlinks and administrative access are not needed for configuration.
Some package installers may require elevation; follow organizational policy.

Windows can redirect Documents (and `$PROFILE`) into OneDrive. The bootstrap
does not change that setting. Its portable loader checks `~/dotfiles` on each
PC; host-specific profiles run afterward. Only the exact old dotfiles startup
block is migrated out of a host profile; unrelated functions stay intact.
Backups stay under LocalAppData, outside OneDrive.
When Python is installed, its user bin directory precedes WindowsApps in the
user PATH so Store aliases do not intercept `python`. Machine PATH entries
and existing system runtimes retain their precedence.
Windows installs the exact Python pin from the repository's `mise.toml`
alongside Python 3.12.15, which remains the Windows default. This avoids a
second stale copy of the managed Python version in the installer. Existing
Python installations are not uninstalled.

PowerShell uses M365Princess with Hack Nerd Font. Ubuntu uses 0xProto Nerd
Font and the Campbell color scheme, matching the previous PC's black
background rather than Ubuntu's default purple. Theme and font sources are
pinned, and font archives are checksum-verified, using
`windows/terminal/appearance.json`. The theme is cached under
`$env:LOCALAPPDATA\dotfiles\themes`, not fetched on every shell startup.
`POSH_THEMES_PATH` is not required. The old `m365.omp.json` reference no longer
exists upstream; M365Princess is the user-approved replacement.
The font is installed on Windows, including for WSL terminals.
Pass `-SkipTerminal` to skip font/terminal settings, not prompt-theme setup.
posh-git adds Git completion;
PSFzf adds Ctrl+R history search and Ctrl+F path selection. Up/Down search
history using the text already typed. Host profiles may override the prompt.
VS Code can retain an older PATH after package installation. If `fzf` is
missing from that process, the profile appends only its directory found in
the registered machine/user PATH, preserving existing process entries and
their precedence. No persistent environment variables are changed.
If the binary is genuinely unavailable, PSFzf is skipped with an explicit
warning rather than failing profile startup. Save work and reopen VS Code
after package installation to refresh other inherited environment variables.
Terminal preferences are in `windows/terminal/preferences.json`, a merge
template rather than a replacement for the machine's complete settings.
It sets Hack as the default font, 100% opacity, selection copy, plain-text
copying, Shift+Enter input, split/copy/paste/find shortcuts and title-tab
appearance. Ubuntu gets Campbell and 0xProto, and becomes the default tab.
The real Dev Box profile GUID is resolved by name/source, not copied from the
previous PC. Existing VS/other profiles, font sizes and unrelated bindings
are retained. JSON formatting/comments may be normalized when saving.
Close and reopen Windows Terminal after installing the font.
Choose **Ubuntu-24.04** (the Microsoft.WSL-generated profile) for this setup,
or run `wsl -d Ubuntu-24.04`. A second **Ubuntu 24.04 LTS** entry may come from
the Store launcher; it is not removed or changed automatically.
Older `Windows.Terminal.Wsl`-generated profiles are also accepted by the
merger. If multiple generated profiles share the target name, setup stops
instead of choosing an arbitrary GUID.

Set Git name and email privately in `~/.gitconfig.local` using a local editor.
Git Credential Manager handles Windows HTTPS credentials. Authenticate CLI
with `gh auth login --web`. Never paste tokens into chat or remote URLs.

## Windows recovery

```powershell
pwsh -NoProfile -File .\windows\restore.ps1 -ManifestPath '<backup>\manifest.json'
```

Restore multiple runs in reverse order. Recovery checks hashes before
changing anything and refuses later user edits: reconcile these manually
with private backups. It restores files and user PATH, not packages, modules
or Python runtimes/fonts. Compare private before/after package and user-font
inventories before considering individual uninstalls; do not remove
pre-existing applications or fonts.

## WSL

Check `wsl --list --verbose`. If Ubuntu is absent:

```powershell
wsl --install -d Ubuntu-24.04 --no-launch
wsl -d Ubuntu-24.04
```

Complete first-run account/password prompts locally. Inside Ubuntu:

```bash
git clone https://github.com/georgeOsdDev/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh
```

Use Linux home, not the Windows/OneDrive filesystem. The bootstrap preserves
replaced configurations, including links, under
`~/.local/state/dotfiles/backups`, and records the original login shell.
Restore using `bash ~/dotfiles/restore.sh '<backup-directory>'`.
Recovery refuses later configuration changes and does not uninstall tools.
Run as the normal Linux user. Missing APT prerequisites (including curl,
GnuPG, unzip, zsh, build tools and runtime libraries) are installed without
upgrading existing packages or removing packages. Before/after package
inventories are saved in the same private recovery directory.
Review the pinned mise configs before execution; the script explicitly trusts
those two repository configs, not all files or future repositories.
APT and changing the login shell may require local authentication.
For noninteractive setup, use `DOTFILES_SKIP_CHSH=1 bash install.sh`, then
change the login shell locally with `chsh -s "$(command -v zsh)"`.
Do not copy Windows credentials into WSL.
Never use `wsl --unregister` for routine rollback: it deletes the filesystem.

### Windows browser from WSL

The bootstrap installs `~/.local/bin/wsl-browser` from
`wsl/browser/open.sh`. Bash and zsh set `BROWSER` to it only in WSL and only
when no browser was already configured. Windows PowerShell opens the URL
with the Windows default HTTP(S) handler; Linux browser packages are not
required. URLs are passed through a process-local WSL environment variable,
not interpolated into command text, written to files or printed.

Open a fresh shell, then verify:

```bash
wsl-browser 'https://example.com/?source=wsl&check=browser'
az login
```

Complete authentication in the Windows browser, not in chat. An existing
`az login` waiting for a browser must be cancelled locally with Ctrl+C and
retried after refreshing the shell. Existing custom `BROWSER` settings are
preserved; inspect those locally if they still select a different launcher.
The browser bridge participates in the bootstrap's existing backup and
restore manifests. Restoring tracked shell sources is separate from
restoring their home-directory symlinks: retain a private copy before
deploying changes to an existing clone.

For the configuration-only Dev Box deployment, the private backup also
contains `shell/.bashrc`, `shell/.zshenv` and `applied.sha256`. To undo that
deployment, select its printed backup directory and verify all checksums
before restoring source files and the browser command:

```bash
backup='<printed-backup-directory>'
if sha256sum -c "$backup/applied.sha256"; then
    cp -a "$backup/shell/.bashrc" ~/dotfiles/wsl/shell/.bashrc
    cp -a "$backup/shell/.zshenv" ~/dotfiles/wsl/shell/.zshenv
    bash ~/dotfiles/restore.sh "$backup"
fi
```

Do not overwrite later edits when checksums fail. Restart the shell after
recovery; no Windows browser settings or installed applications are changed.

Dev Box validation confirmed the public URL displayed in Windows Edge,
fresh bash/zsh sessions selected the bridge, and Azure CLI's Python runtime
selected the same browser handler. Custom `BROWSER` values were preserved.
Regression tests verified URL metacharacters remain data, launcher failures
propagate, and recovery removes only the newly installed browser command.
Actual Azure authentication is completed by the user; no login was automated.

## Publication and maintenance

Before publishing, run the same targeted checks as CI:

```powershell
pwsh -NoProfile -File .\windows\tests\restore.Tests.ps1
pwsh -NoProfile -File .\windows\tests\terminal.Tests.ps1
pwsh -NoProfile -File .\windows\tests\profile.Tests.ps1
```

Inside Ubuntu from the repository root:

```bash
for file in install.sh restore.sh wsl/browser/open.sh wsl/docker/*.sh tests/*.sh; do
    bash -n "$file" || exit
done
bash tests/restore.sh
bash tests/bootstrap.sh
bash tests/browser.sh
bash tests/docker.sh
zsh -n wsl/shell/.zshrc wsl/shell/.zimrc wsl/shell/.zshenv
```

CI also parses managed JSON/TOML and PowerShell syntax. A full fresh-machine
installation still requires local administrator/sudo approval, network
access, Ubuntu account initialization and user-completed authentication;
do not claim those steps were tested merely because regression tests pass.

Publish reusable scripts and configuration only, never private logs,
backups or full machine exports. Review staged changes before committing.
Keep exact mise/cargo pins and npm semver conventions. Verify availability
before updating versions. The bootstrap does not disable TLS verification,
security software, or organizational policies.

The repository-level `mise.toml` Python pin matches the WSL global pin so
working inside dotfiles does not select the obsolete Python 3.10 runtime.
The stale `zimfw/eza` module reference is removed; the eza binary and shell
aliases remain. mise and Cargo PATH activation precede Zim initialization.
