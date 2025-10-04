#!/usr/bin/env sh
# Revert changes made by scripts/add_local_hosts.sh
# Usage:
#   ./scripts/revert_local_hosts.sh           # remove the marker block (safe)
#   ./scripts/revert_local_hosts.sh --restore-backup  # restore the most recent /etc/hosts.bak.*
#   ./scripts/revert_local_hosts.sh --restore-backup --yes  # non-interactive restore

set -eu

HOSTS_FILE=/etc/hosts
BACKUP_DIR=/etc
TIMESTAMP=$(date +%Y%m%d%H%M%S)
MARKER_BEGIN="# caddy-local-hosts BEGIN"
MARKER_END="# caddy-local-hosts END"

RESTORE_BACKUP=0
ASSUME_YES=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --restore-backup) RESTORE_BACKUP=1; shift ;;
    --yes|-y) ASSUME_YES=1; shift ;;
    --help|-h) printf "Usage: %s [--restore-backup] [--yes]\n" "$0"; exit 0 ;;
    *) printf "Unknown arg: %s\n" "$1"; exit 1 ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Elevating privileges with sudo; you may be prompted for your password..."
  exec sudo "$0" "$@"
fi

# Make a backup of current hosts before modifying
CUR_BACKUP="$BACKUP_DIR/hosts.pre_revert.$TIMESTAMP"
cp "$HOSTS_FILE" "$CUR_BACKUP"
echo "Backed up current $HOSTS_FILE -> $CUR_BACKUP"

if [ "$RESTORE_BACKUP" -eq 1 ]; then
  # Find latest backup created by add_local_hosts (pattern hosts.bak.*)
  LATEST_BACKUP=$(ls -1 $BACKUP_DIR/hosts.bak.* 2>/dev/null | sort || true)
  if [ -z "$LATEST_BACKUP" ]; then
    echo "No backups matching $BACKUP_DIR/hosts.bak.* found. Nothing to restore." >&2
    exit 1
  fi
  # pick last line
  LATEST_BACKUP=$(printf "%s\n" "$LATEST_BACKUP" | tail -n 1)
  if [ "$ASSUME_YES" -ne 1 ]; then
    printf "Restore hosts from '%s' and overwrite %s? [y/N]: " "$LATEST_BACKUP" "$HOSTS_FILE"
    read ans || true
    case "$ans" in
      [Yy]* ) ;;
      * ) echo "Aborted."; exit 1 ;;
    esac
  fi
  cp "$LATEST_BACKUP" "$HOSTS_FILE"
  echo "Restored $HOSTS_FILE from $LATEST_BACKUP"
  exit 0
fi

# Otherwise, remove the marker block if present
TMP_ORIG=$(mktemp /tmp/hosts.orig.XXXXXX)
TMP_CLEAN=$(mktemp /tmp/hosts.clean.XXXXXX)
cp "$HOSTS_FILE" "$TMP_ORIG"

awk -v MB="$MARKER_BEGIN" -v ME="$MARKER_END" 'BEGIN{inblock=0} { if ($0==MB) { inblock=1; next } if ($0==ME) { inblock=0; next } if (!inblock) print }' "$TMP_ORIG" > "$TMP_CLEAN"

if cmp -s "$TMP_ORIG" "$TMP_CLEAN"; then
  echo "No marker block ('$MARKER_BEGIN' / '$MARKER_END') found in $HOSTS_FILE. No changes made."
  rm -f "$TMP_ORIG" "$TMP_CLEAN"
  exit 0
fi

# Move cleaned file into place atomically
mv "$TMP_CLEAN" "$HOSTS_FILE"
echo "Removed marker block and updated $HOSTS_FILE"

# Show removed block from the original backup for auditing
echo "--- previous marker block (if any) from backup $CUR_BACKUP: ---"
awk "/^$MARKER_BEGIN/{p=1;print;next} /^$MARKER_END/{print;exit} p{print}" "$CUR_BACKUP" || true

rm -f "$TMP_ORIG"
exit 0
