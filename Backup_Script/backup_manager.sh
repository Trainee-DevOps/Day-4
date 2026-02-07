#!/bin/bash
# backup_manager.sh
# Automated backup manager: full / incremental / differential backups with encryption-ready structure

set -euo pipefail

CONF="./backup.conf"
[[ -f "$CONF" ]] || { echo "Config file backup.conf not found"; exit 1; }
source "$CONF"

MODE="${1:-}"
BACKUP_TYPE="${2:-}"   # full | incremental | differential

# ./backup_manager.sh backup full 
# ./backup_manager.sh -> $0
# backup -> $1
# full -> $2

TODAY=$(date +%F)
WEEK=$(date +%V)
MONTH=$(date +%Y-%m)

log() { echo "[$(date '+%F %T')] $1" | tee -a "$LOG_FILE"; }

check_space() {
  avail=$(df -Pk "$BACKUP_ROOT" | awk 'NR==2 {print $4}')
  if (( avail < MIN_FREE_KB )); then
    log "ERROR: Not enough disk space"
    exit 1
  fi
}

create_snapshot() {
  SNAPSHOT="$METADATA_DIR/last_full.snar"
  [[ "$BACKUP_TYPE" == "incremental" ]] && SNAPSHOT="$METADATA_DIR/last_inc.snar"
  echo "$SNAPSHOT"
}

run_backup() {
  check_space
  mkdir -p "$BACKUP_ROOT/$TODAY" "$METADATA_DIR"

  SNAPSHOT=$(create_snapshot)
  ARCHIVE="$BACKUP_ROOT/$TODAY/${BACKUP_TYPE}_backup_$TODAY.tar.gz"

  log "Starting $BACKUP_TYPE backup"
  tar --listed-incremental="$SNAPSHOT" -czf "$ARCHIVE" "$SOURCE_DIR"

  md5sum "$ARCHIVE" > "$ARCHIVE.md5"
  log "Backup completed: $ARCHIVE"
}

apply_retention() {
  log "Applying retention policy"

  # Daily (7)
  ls -1dt "$BACKUP_ROOT"/* | tail -n +$((DAILY_RETENTION+1)) | xargs -r rm -rf

  # Weekly (4) and Monthly (12) tagging is directory-based; handled externally by cron rotation
}

restore_backup() {
  echo "Available backups:"
  select dir in "$BACKUP_ROOT"/*; do
    [[ -n "$dir" ]] || exit 0
    echo "Selected: $dir"
    ls "$dir"
    read -p "Enter archive name to restore: " archive
    tar -xzf "$dir/$archive" -C "$RESTORE_DIR"
    log "Restore completed to $RESTORE_DIR"
    break
  done
}

verify_backup() {
  for f in "$BACKUP_ROOT"/*/*.tar.gz; do
    md5sum -c "$f.md5"
  done
}

case "$MODE" in
  backup)
    [[ "$BACKUP_TYPE" =~ ^(full|incremental|differential)$ ]] || { echo "Invalid backup type"; exit 1; }
    run_backup
    apply_retention
    ;;
  restore)
    restore_backup
    ;;
  verify)
    verify_backup
    ;;
  *)
    echo "Usage: $0 {backup <full|incremental|differential>|restore|verify}"
    exit 1
    ;;
esac
