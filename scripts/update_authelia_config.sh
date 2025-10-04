#!/usr/bin/env bash
set -euo pipefail

# Copies config files from the repo into the authelia docker volume, with backups,
# validates the new configuration, and restarts the authelia container on success.
# On validation failure the script will revert to the backups.

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC_CONFIG="$REPO_ROOT/config/authelia/configuration.yml"
SRC_USERS="$REPO_ROOT/config/authelia/users.yml"
DEST_DIR="$REPO_ROOT/config/authelia"

TS=$(date +%m%d%Y_%H%M)

FILES=("configuration.yml" "users.yml")

echo "📁 Repository root: $REPO_ROOT"

for f in "$SRC_CONFIG" "$SRC_USERS"; do
  if [ ! -f "$f" ]; then
    echo "❌ Source file not found: $f" >&2
    exit 2
  fi
done

echo -e "\n🛡️  Step 1: Backing up existing files\n"

declare -A BACKUPS
for name in "${FILES[@]}"; do
  src="$DEST_DIR/$name"
  if [ -f "$src" ]; then
    backup="$src"_"$TS".bak
    cp -v "$src" "$backup"
    BACKUPS["$name"]="$backup"
    echo "✅ Backed up $name -> $(basename "$backup")"
  else
    echo "ℹ️  No existing $name to backup (will be created)."
    BACKUPS["$name"]=""
  fi
done

echo -e "\n📤 Step 2: Config files are already mounted via bind mount - no copy needed\n"
echo "✅ Files are accessible at: $DEST_DIR/"

echo -e "\n🔍 Step 3: Validating Authelia configuration inside container 'authelia'\n"

set +e
VALID_OUT=$(mktemp)
VALID_EXIT=0
docker exec authelia authelia validate-config --config /config/configuration.yml >"$VALID_OUT" 2>&1
VALID_EXIT=$?
set -e

if [ $VALID_EXIT -eq 0 ]; then
  echo "✅ Configuration validated successfully (🎉)"
else
  echo "❌ Configuration validation failed (see details):"
  sed -n '1,200p' "$VALID_OUT" || true
  echo -e "\n↩️  Reverting to previous configuration backups...\n"
  for name in "${FILES[@]}"; do
    bpath="${BACKUPS[$name]}"
    dest="$DEST_DIR/$name"
    if [ -n "$bpath" ]; then
      cp -v "$bpath" "$dest"
      echo "🔄 Restored $name from $(basename "$bpath")"
    else
      # No backup existed previously, remove the newly copied file to revert
      if [ -f "$dest" ]; then
        rm -v "$dest"
        echo "🗑️  Removed newly copied $name (no previous backup)"
      fi
    fi
  done
  rm -f "$VALID_OUT"
  echo "❗ Revert complete. Please fix your configuration and try again."
  exit 3
fi

rm -f "$VALID_OUT"

echo -e "\n🚀 Step 4: Restarting authelia container\n"

if docker restart authelia >/dev/null 2>&1; then
  echo "🔁 authelia restarted successfully"
  echo "
🎉 All done. Your new configuration is in place and authelia was restarted."
  echo "You can view the active configuration with: sudo cat $DEST_DIR/configuration.yml"
  exit 0
else
  echo "❌ Failed to restart authelia. Attempting to revert to previous configuration..."
  for name in "${FILES[@]}"; do
    bpath="${BACKUPS[$name]}"
    dest="$DEST_DIR/$name"
    if [ -n "$bpath" ]; then
      cp -v "$bpath" "$dest"
      echo "🔄 Restored $name from $(basename "$bpath")"
    fi
  done
  echo "❗ Revert complete. Please check the container logs and configuration."
  exit 4
fi
