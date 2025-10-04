# Scripts

This directory contains helper scripts used for managing the local Caddy container.

## reload_caddy.sh

Purpose
- Validate the repository `Caddyfile` and apply it to the running `caddy` container.

Behavior
- Validates using `caddy validate` inside the running container when possible.
- Falls back to a transient `caddy:latest` container that mounts the repository to validate the host `Caddyfile`.
- Attempts `docker exec caddy caddy reload --config /etc/caddy/Caddyfile` for a graceful reload.
- If `/etc/caddy/Caddyfile` is missing inside the container, the script copies the host `Caddyfile` into the container (`docker cp`) and retries reload.
- If reload fails, the script exits with an error and provides guidance to inspect container logs; it does not restart the container.

Usage
```sh
./scripts/reload_caddy.sh [--force] [--no-validate]
```

Flags
- `--force` : skip validation and attempt a graceful reload without restarting the container.
- `--no-validate` : skip Caddyfile validation step.

Caveats and recommendations
- The script uses `docker cp` to copy the host `Caddyfile` into the running container when the file is missing. This changes the container filesystem and is intended as a pragmatic fallback. Prefer to start the container with a bind-mount of the host `Caddyfile` to `/etc/caddy/Caddyfile` for a cleaner setup.
- The script will not restart the container under any circumstance; if reload fails, it exits with an error so operators can inspect logs and take explicit action.
- The script requires Docker socket access (run with `sudo` or ensure your user is in the `docker` group).

License: same as the repository.

## validate_caddy.sh

Purpose
- Validate the repository `Caddyfile` using a running `caddy` container when available, or a transient `caddy:latest` container as fallback.

Behavior
- Prefers in-container validation (`docker exec caddy caddy validate`).
- If Docker socket access is restricted or the running container is absent, it will run a transient `caddy` container mounting the repository and `/config` to validate the host `Caddyfile`.
- Prints a short summary and adapted JSON by default; use `-q|--quiet` to show a compact summary.

Usage
```sh
./scripts/validate_caddy.sh [-q|--quiet]
```

Notes
- Requires Docker socket access to validate in-container; run with `sudo` or ensure your user is in the `docker` group.
- The script does not change the running container; it's read-only (transient container fallback also read-only).
