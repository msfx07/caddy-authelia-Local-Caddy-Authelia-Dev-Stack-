#!/usr/bin/env bash
set -euo pipefail

# validate_caddy.sh - validate Caddy configuration for this repo.
# Behavior:
# 1. Check that expected files exist locally
# 2. If a running container named 'caddy' exists, run `caddy validate` inside it
# 3. Otherwise run a transient caddy container that mounts the repo and config

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CADDYFILE="$REPO_ROOT/Caddyfile"
CONFIG_DIR="$REPO_ROOT/config"
# Container name can be overridden with environment variable CADDY_CONTAINER
CONTAINER_NAME="${CADDY_CONTAINER:-caddy}"
QUIET=0

# Parse args
while [ "$#" -gt 0 ]; do
  case "$1" in
    -q|--quiet) QUIET=1; shift ;;
    -h|--help) echo "Usage: $0 [--quiet]"; exit 0 ;;
    *) echo "Unknown arg: $1"; echo "Usage: $0 [--quiet]"; exit 2 ;;
  esac
done

echo "Repo root: $REPO_ROOT"

# Check Docker availability early to give a clear message
if ! command -v docker >/dev/null 2>&1; then
  echo "ERROR: docker CLI not found in PATH. This script requires Docker to validate the Caddyfile."
  echo "Install Docker or run on a host with Docker socket access (or use sudo where appropriate)."
  exit 2
fi

missing=0
if [ ! -f "$CADDYFILE" ]; then
  echo "ERROR: $CADDYFILE not found"
  missing=1
fi
if [ ! -d "$CONFIG_DIR" ]; then
  echo "WARNING: $CONFIG_DIR not found (imports may fail at runtime)"
fi

if [ "$missing" -ne 0 ]; then
  exit 2
fi

# Try to run inside existing container
if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$" 2>/dev/null; then
  echo "Found running container '${CONTAINER_NAME}', attempting in-container validation..."
  if docker exec -i "$CONTAINER_NAME" caddy validate --config /etc/caddy/Caddyfile; then
    echo "Validation succeeded (inside container)."

    echo
    echo "--- Active Caddyfile in container ---"
    docker exec -i "$CONTAINER_NAME" sh -c 'printf "Path: %s\n" /etc/caddy/Caddyfile; stat -c "Size: %s bytes\nModified: %y\n" /etc/caddy/Caddyfile 2>/dev/null || true'
    echo
    echo "--- Caddyfile (first 200 lines, numbered) ---"
    docker exec -i "$CONTAINER_NAME" sh -c 'nl -ba /etc/caddy/Caddyfile | sed -n "1,200p"' || true
    echo
    if [ "$QUIET" -eq 0 ]; then
      echo "--- Adapted JSON config (caddy adapt) ---"
      docker exec -i "$CONTAINER_NAME" caddy adapt --config /etc/caddy/Caddyfile || true
    else
      echo "--- Short summary ---"
      docker exec -i "$CONTAINER_NAME" sh -c "grep -E '^https?://|^\{|^import |:[0-9]+' /etc/caddy/Caddyfile || true" | sed -n '1,200p' || true
    fi
    echo
    echo "--- End of active config ---"

    exit 0
  else
    echo "In-container validation failed. Will try transient container fallback."
  fi
else
  echo "No running '${CONTAINER_NAME}' container found. Using transient caddy container to validate."
fi

# Transient container fallback: mount repo and config
# Note: this requires Docker access and will use the host's PWD contents. Use sudo if needed.

echo "Running transient caddy container for validation (will mount repo and config)..."

set +e
docker run --rm -v "$REPO_ROOT":/workspace -v "$CONFIG_DIR":/etc/caddy -w /workspace caddy:latest \
  caddy validate --config /workspace/Caddyfile
rc=$?
set -e

if [ $rc -eq 0 ]; then
  echo "Validation succeeded (transient container)."
  echo
  echo "--- Active Caddyfile from host (mounted into transient container) ---"
  printf "Path: %s\n" "$CADDYFILE"
  stat -c "Size: %s bytes\nModified: %y\n" "$CADDYFILE" 2>/dev/null || true
  echo
  echo "--- Caddyfile (first 200 lines, numbered) ---"
  nl -ba "$CADDYFILE" | sed -n '1,200p' || true
  echo
  if [ "$QUIET" -eq 0 ]; then
    echo "--- Adapted JSON config (via transient caddy adapt) ---"
    docker run --rm -v "$REPO_ROOT":/workspace -v "$CONFIG_DIR":/etc/caddy -w /workspace caddy:latest caddy adapt --config /workspace/Caddyfile || true
  else
    echo "--- Short summary ---"
    grep -E '^https?://|^\{|^import |:[0-9]+' "$CADDYFILE" | sed -n '1,200p' || true
  fi
  echo
  echo "--- End of active config ---"
  exit 0
else
  echo "Validation failed in transient container (exit code $rc)."
  exit $rc
fi
