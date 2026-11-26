# Optional Docker Engine for WSL Dev Containers

Docker Desktop is not required. This optional setup targets Ubuntu 24.04
with systemd; it is separate from the shell/mise/cargo/npm bootstrap.

## Plan and installation

1. Inspect existing Docker packages, repositories, services and membership.
2. Record private system state before changes.
3. Install only missing Docker CE, CLI, containerd, Buildx and Compose
   packages from Docker's official stable APT repository.
4. Enable the local Docker/containerd services and grant the selected
   Ubuntu user Docker access.
5. Verify Docker Server, Compose and Buildx without running the CLI as root.
6. Reconnect VS Code to WSL and retry **Reopen in Container**.

Inside Ubuntu, run:

```bash
bash ~/dotfiles/wsl/docker/install.sh
```

The script requests sudo and records the current user before elevating.
When already root, pass the intended non-root username explicitly.
It refuses to remove conflicting distribution packages or overwrite
reserved configuration paths. Existing Docker installations/repositories
are retained, and installed packages are not automatically upgraded.
It does not execute `curl | sh`, install Docker Desktop, change daemon
settings, open a TCP daemon endpoint, or disable security checks.
The Docker signing-key fingerprint is verified before registering APT.

**Security:** Membership in `docker` grants root-equivalent privileges
inside this Ubuntu environment. It is not an ordinary low-privilege group.
Use this setup only after approving that access. Published container ports
can bypass UFW rules; review application port bindings separately.

Docker APT packages use the official stable repository, not mise/cargo
version pins. Record/update them with APT deliberately; the setup only
installs missing packages and never performs `apt upgrade`.

## Verification

New sessions pick up group membership:

```bash
docker version
docker compose version
docker buildx version
docker run --rm hello-world
```

An existing VS Code WSL server may still have the old groups. Close WSL
VS Code windows and reconnect. If necessary, use VS Code's WSL server
restart/kill command after saving work; do not kill unrelated processes.
A WSL restart interrupts all work in that distribution, so do it explicitly
only after saving work and stopping any containers that matter.

## Backups and recovery

Each run prints a root-private directory:
`/var/backups/dotfiles/docker/<timestamp>-<unique-id>`.
It records installed package inventories, the target user and original
membership, Docker/socket/containerd service states, and hashes of newly
created APT files. These records are not committed.

Restore runs in reverse order when reverting several setup runs:

```bash
bash ~/dotfiles/wsl/docker/restore.sh /var/backups/dotfiles/docker/<backup>
```

Recovery validates all APT targets and service states before making changes,
refuses later edits and running containers, restores enable/start settings,
removes only membership added by the setup, and removes only its own unchanged
APT files. If setup failed before final service snapshots were available,
the restore helper stops for manual inspection rather than guessing.

Installed packages, the Docker group and Docker data remain intact.
Use the private before/after inventories if individual package removal is
later required; never blindly purge packages or run autoremove.
Do not delete `/var/lib/docker`, `/var/lib/containerd`, volumes, or images
as part of routine recovery. Registry credentials and `~/.docker/config.json`
stay local and must not be copied into this repository.

## Dev Box validation

The Ubuntu setup was applied and verified without Docker Desktop:

- Docker Engine 29.10.1, Compose 5.8.0 and Buildx 0.39.1.
- Initial installation added 13 packages, upgraded none and removed none.
- Non-root `hello-world` and a disposable Compose service both completed.
- Docker, its socket and containerd are enabled and active.
- Reapplying changed no package versions, service states or APT files.
- Recovery refused a running test container before making changes.
- Service-state regression tests cover missing, masked, failed and
  unsuccessful service queries.

Test containers and the temporary Compose network were removed. Downloaded
public test images remain cached. Full rollback was not performed on the
working installation; recovery must be scheduled around existing work.

References:
- [Docker Engine on Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
- [Docker Linux post-installation](https://docs.docker.com/engine/install/linux-postinstall/)
- [VS Code Dev Containers](https://code.visualstudio.com/docs/devcontainers/containers)
