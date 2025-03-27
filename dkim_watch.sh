#!/bin/bash
# dkim_watch.sh - Monitoring changes in DKIM configuration
# Location: /usr/local/bin/dkim_watch.sh

# opendkim files to monitor
WATCH_PATHS=(
  "/etc/opendkim/SigningTable"
  "/etc/opendkim/KeyTable"
)

# Sync script
SYNC_SCRIPT="/usr/local/bin/dkim_sync.sh"

# Log file
LOG_FILE="/var/log/dkim_sync/watcher.log"
mkdir -p "$(dirname "$LOG_FILE")"
chown dkim-sync "$(dirname "$LOG_FILE")"

# Logging
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log "Start monitor DKIM config files..."

# Lock file to prevent concurrent sync
LOCK_FILE="/tmp/dkim_sync.lock"
rm -f "$LOCK_FILE"

inotifywait -m -e modify,create,delete,move --format '%w%f' ${WATCH_PATHS[@]} | while read FILE
do
  log "Changed file detected: $FILE"
  
  if [ ! -f "$LOCK_FILE" ]; then
    touch "$LOCK_FILE"
    log "Wait for all changes to complete before sync..."
    (
      sleep 5  # Wait 5s for other changes to complete
      log "Starting synchronization..."
      sudo -u dkim-sync "$SYNC_SCRIPT"
      log "Synchronization completed"
      rm -f "$LOCK_FILE"  # Release lock
    ) &
  fi
done