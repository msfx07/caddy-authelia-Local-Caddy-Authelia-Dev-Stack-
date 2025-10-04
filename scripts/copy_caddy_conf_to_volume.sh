#!/usr/bin/env sh
# Copy ./config/caddy_security.conf into a named Docker volume.
# Usage:
#   ./scripts/copy_caddy_conf_to_volume.sh [volume_name] [source_file]
# Examples:
#   ./scripts/copy_caddy_conf_to_volume.sh caddy_config
#   ./scripts/copy_caddy_conf_to_volume.sh myvol config/caddy_security.conf

set -eu

VOLUME_NAME=${1:-caddy_config}
SRC=${2:-config/caddy_security.conf}

# Basename of the source file (used as target filename inside the volume)
BASENAME=$(basename "$SRC")

die() {
    printf '%s\n' "$1" >&2
    exit 1
}

if ! command -v docker >/dev/null 2>&1; then
    die "docker not found in PATH"
fi

if [ ! -f "$SRC" ]; then
    die "Source file '$SRC' not found"
fi

echo "Ensuring docker volume '$VOLUME_NAME' exists..."
if ! docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
    docker volume create "$VOLUME_NAME" >/dev/null || die "failed to create docker volume '$VOLUME_NAME'"
    echo "Created volume: $VOLUME_NAME"
else
    echo "Volume exists: $VOLUME_NAME"
fi

echo "Copying '$SRC' into volume '$VOLUME_NAME'..."
# Use a tiny image to copy the file into the volume. We mount the source file read-only.
docker run --rm \
    -v "$VOLUME_NAME":/target \
    -v "$(pwd)/$SRC":/source:ro \
    alpine:3.18 sh -c 'cp /source /target/'"$BASENAME"' && chmod 644 /target/'"$BASENAME"''

echo "Done. The file is now in volume '$VOLUME_NAME' as /$BASENAME."
echo "Mount the volume into your Caddy service, for example:"
echo "  volumes:\n    - $VOLUME_NAME:/etc/caddy:ro"

# List the file inside the volume and show a short preview
echo "\nListing files in the volume ($VOLUME_NAME):"
docker run --rm -v "$VOLUME_NAME":/target alpine:3.18 sh -c 'ls -la /target || true'

echo "\nPreview of /caddy_security.conf inside the volume (first 200 lines):"
docker run --rm -v "$VOLUME_NAME":/target alpine:3.18 sh -c 'if [ -f /target/'"$BASENAME"' ]; then sed -n "1,200p" /target/'"$BASENAME"'; else echo "(file not found)"; fi'
