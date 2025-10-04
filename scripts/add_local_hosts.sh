#!/usr/bin/env sh
# Add local host entries used by the Caddy config
# Usage: sudo ./scripts/add_local_hosts.sh
# This script will:
#  - back up /etc/hosts to /etc/hosts.bak.TIMESTAMP
#  - remove any previous block added by this script
#  - append a new block mapping the listed hostnames to 127.0.0.1

set -eu

HOSTS_FILE=/etc/hosts
BACKUP_DIR=/etc
TIMESTAMP=$(date +%Y%m%d%H%M%S)
BACKUP_FILE="$BACKUP_DIR/hosts.bak.$TIMESTAMP"

# Hostnames to add will be created after privilege elevation

MARKER_BEGIN="# caddy-local-hosts BEGIN"
MARKER_END="# caddy-local-hosts END"


if [ "$(id -u)" -ne 0 ]; then
  echo "Elevating privileges with sudo; you may be prompted for your password..."
  exec sudo "$0" "$@"
fi

# Hostnames to add (one per line) - create as root to avoid permission problems
TMP_LIST=$(mktemp /tmp/_caddy_local_hosts.XXXXXX)
cat > "$TMP_LIST" <<'HOSTS_EOF'
test.sandbox99.local
auth0.sandbox99.local
HOSTS_EOF

# Ensure this runs on the host machine (not inside an ephemeral/containerized environment)
# We check for common indicators and refuse to proceed if detected.
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
  echo "This script must be run on the host machine." >&2
  exit 1
fi
if [ -r /proc/1/cgroup ]; then
  if grep -E -q ':(lxc|docker|containerd|kubepods|podman):' /proc/1/cgroup 2>/dev/null; then
    echo "This script must be run on the host machine." >&2
    exit 1
  fi
fi

  # Backup
cp "$HOSTS_FILE" "$BACKUP_FILE"
echo "Backed up $HOSTS_FILE -> $BACKUP_FILE"

# Work on temp files to avoid partial writes
ORIG="/tmp/hosts.orig.$$"
CLEAN="/tmp/hosts.clean.$$"
FINAL="/tmp/hosts.final.$$"
cp "$HOSTS_FILE" "$ORIG"

# Create a cleaned version with any previous marker block removed
# Use -v to pass marker strings into awk to avoid complex shell quoting
awk -v MB="$MARKER_BEGIN" -v ME="$MARKER_END" 'BEGIN{inblock=0} { if ($0==MB) { inblock=1; next } if ($0==ME) { inblock=0; next } if (!inblock) print }' "$ORIG" > "$CLEAN"

# Build list of hosts that are NOT present in the cleaned hosts file
TO_ADD="/tmp/hosts.toadd.$$"
rm -f "$TO_ADD" && touch "$TO_ADD"
while IFS= read -r host; do
  # skip empty lines and comments
  if [ -z "$host" ]; then
    continue
  fi
  case "$host" in
    # lines starting with # are comments
    \#*) continue ;;
  esac
  # Check for whole-word presence in the cleaned file
  if grep -E -q "(^|[[:space:]])$host([[:space:]]|$)" "$CLEAN"; then
    echo "Skipping existing host: $host"
  else
    echo "$host" >> "$TO_ADD"
  fi
done < "$TMP_LIST"

# If nothing to add, no changes required (but ensure previous block removed and file preserved)
if [ ! -s "$TO_ADD" ]; then
  echo "No new hosts to add; leaving $HOSTS_FILE unchanged (previous block preserved if any)."
  # Clean up
  rm -f "$TMP_LIST" "$ORIG" "$CLEAN" "$TO_ADD"
  exit 0
fi

# Write final hosts: cleaned content + marker block with only new entries
cp "$CLEAN" "$FINAL"
printf "%s\n" "$MARKER_BEGIN" >> "$FINAL"
while IFS= read -r host; do
  printf "127.0.0.1\t%s\n" "$host" >> "$FINAL"
done < "$TO_ADD"
printf "%s\n" "$MARKER_END" >> "$FINAL"

# Move final into place (atomic)
mv "$FINAL" "$HOSTS_FILE"
NUM_ADDED=$(wc -l < "$TO_ADD" 2>/dev/null || echo 0)
echo "Appended $NUM_ADDED host(s) to $HOSTS_FILE in marker block."

# Show the appended block
awk "/^$MARKER_BEGIN/{p=1;print;next} /^$MARKER_END/{print;exit} p{print}" "$HOSTS_FILE"

# Clean up
rm -f "$TMP_LIST" "$ORIG" "$CLEAN" "$TO_ADD"

exit 0
