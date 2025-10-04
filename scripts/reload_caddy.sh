#!/usr/bin/env bash
# Reload Caddy container with updated Caddyfile
# - Validates the Caddyfile (in-container if running, otherwise transient container)
# - Attempts in-container `caddy reload` and falls back to `docker restart` if needed
# Usage: ./scripts/reload_caddy.sh [--force] [--no-validate]

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=0
NOVAL=0
QUIET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
  --no-validate) NOVAL=1; shift ;;
  -q|--quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: $0 [--force] [--no-validate]"; exit 0 ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

cd "$ROOT_DIR"

function die { echo "$*" >&2; exit 1; }

if ! command -v docker >/dev/null 2>&1; then
  die "docker is required"
fi

# Container name can be overridden with CADDY_CONTAINER env var
CONTAINER_NAME="${CADDY_CONTAINER:-caddy}"

is_running=$(docker ps --filter "name=${CONTAINER_NAME}" --format '{{.Names}}' || true)
if [[ -z "$is_running" ]]; then
  die "No running container named '${CONTAINER_NAME}' found"
fi

if [[ $NOVAL -eq 0 ]]; then
  echo "Validating Caddyfile via scripts/validate_caddy.sh..."
  VALIDATE_CMD=("$ROOT_DIR/scripts/validate_caddy.sh")
  if [[ $QUIET -eq 1 ]]; then
    VALIDATE_CMD+=("-q")
  fi
  if ! bash "${VALIDATE_CMD[@]}"; then
    die "Validation failed; aborting reload. Use --no-validate to override (not recommended)."
  fi
  echo "Validation passed."
fi

if [[ $FORCE -eq 1 ]]; then
  echo "Force mode: skipping validation and attempting graceful reload"
fi

echo "Ensuring in-container Caddyfile matches validated host Caddyfile"
# Overwrite the in-container file with the validated host copy before attempting reload.
# This ensures the file inside the container matches what we just validated.
if ! docker exec "$CONTAINER_NAME" test -d /etc/caddy >/dev/null 2>&1; then
  echo "/etc/caddy directory not present in container; creating"
  docker exec "$CONTAINER_NAME" mkdir -p /etc/caddy || true
fi

echo "Copying host Caddyfile into container (overwrite)"
if docker cp "$ROOT_DIR/Caddyfile" "$CONTAINER_NAME":/etc/caddy/Caddyfile >/dev/null 2>&1; then
  echo "docker cp succeeded"
else
  echo "docker cp failed; attempting to stream file into container path (fallback)"
  if docker exec -i "$CONTAINER_NAME" sh -c 'cat > /etc/caddy/Caddyfile' < "$ROOT_DIR/Caddyfile"; then
    echo "streamed host Caddyfile into container"
  else
    echo "stream fallback also failed; continuing to attempt reload but the in-container file may not match validated host file"
  fi
fi
# ensure permissions are readable (best-effort)
docker exec "$CONTAINER_NAME" chown root:root /etc/caddy/Caddyfile >/dev/null 2>&1 || true
docker exec "$CONTAINER_NAME" chmod 644 /etc/caddy/Caddyfile >/dev/null 2>&1 || true

echo "Attempting in-container graceful reload"
if docker exec "$CONTAINER_NAME" caddy reload --config /etc/caddy/Caddyfile; then
  echo "caddy reload: success"
  exit 0
fi

echo "Caddyfile exists inside container but reload failed."
echo "ERROR: caddy reload failed. Do not restart the container; inspect container logs and ensure the caddy process is healthy and the Caddyfile is valid inside the container."
exit 1
