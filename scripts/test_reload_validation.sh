#!/usr/bin/env bash
set -euo pipefail

# Quick integration test:
# 1. Backup Caddyfile
# 2. Inject a syntax error
# 3. Run reload script (expect non-zero exit)
# 4. Restore Caddyfile
# 5. Run reload script (expect zero exit)

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CADDY="$ROOT_DIR/Caddyfile"
BACKUP="$ROOT_DIR/Caddyfile.test.bak"

if [ ! -f "$CADDY" ]; then
  echo "Caddyfile not found at $CADDY"; exit 2
fi

cp "$CADDY" "$BACKUP"
trap 'mv -f "$BACKUP" "$CADDY" >/dev/null 2>&1 || true' EXIT

echo "Injecting syntax error into Caddyfile"
echo "{ invalid }" > "$CADDY"

set +e
echo "Running reload (should fail)"
sudo bash "$ROOT_DIR/scripts/reload_caddy.sh" || rc=$?
set -e

if [ "${rc:-0}" -eq 0 ]; then
  echo "ERROR: reload unexpectedly succeeded with invalid Caddyfile"; exit 1
else
  echo "Expected failure observed (reload aborted on invalid Caddyfile). rc=${rc}" 
fi

echo "Restoring original Caddyfile"
mv -f "$BACKUP" "$CADDY"

echo "Running reload (should succeed)"
sudo bash "$ROOT_DIR/scripts/reload_caddy.sh"
echo "Reload succeeded after restoring Caddyfile"
