#!/bin/bash
# dkim_sync.sh - Synchronization of DKIM configuration to web servers
# Location: /usr/local/bin/dkim_sync.sh
# This script runs as user dkim-sync

# Config file - one server per line
CONFIG_FILE="/etc/dkim_sync/servers.conf"

# Log file
LOG_FILE="/var/log/dkim_sync/sync.log"

# Logging
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Load servers from config
load_servers() {
  local config_file="$1"
  local servers=()
  
  # Check if config file exists
  if [ ! -f "$config_file" ]; then
    log "ERROR: Config file $config_file does not exist"
    return 1
  fi
  
  # Parse config file
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip comments and empty lines
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    
    # Remove leading and trailing spaces
    line=$(echo "$line" | xargs)
    
    # Add server to the list
    [[ -n "$line" ]] && servers+=("$line")
  done < "$config_file"
  
  # Check if any servers were loaded
  if [ ${#servers[@]} -eq 0 ]; then
    log "ERROR: No servers were loaded from $config_file"
    return 1
  fi
  
  echo "${servers[@]}"
}

# Sync with a remote server
sync_server() {
  local server=$1
  log "Synchronizing server $server"

  # Prepare temporary directories
  TMP_DIR="/tmp/dkim_sync"
  mkdir -p "$TMP_DIR/opendkim"
  mkdir -p "$TMP_DIR/dkimkeys"

  # Copy directories using sudo rsync
  log "Copying files to temporary directory..."
  sudo rsync --chown=dkim-sync:nogroup -a "/etc/opendkim/" "$TMP_DIR/opendkim/"
  sudo rsync --chown=dkim-sync:nogroup -a "/etc/dkimkeys/" "$TMP_DIR/dkimkeys/"

  # Create temporary directory structure on remote server
  log "Creating remote directory structure..."
  ssh "dkim-sync@$server" "mkdir -p $TMP_DIR/opendkim $TMP_DIR/dkimkeys"

  # Synchronize files from local temporary copy
  log "Transferring files to remote server..."
  rsync -az --checksum "$TMP_DIR/opendkim/" "dkim-sync@$server:$TMP_DIR/opendkim/"
  rsync -az --checksum "$TMP_DIR/dkimkeys/" "dkim-sync@$server:$TMP_DIR/dkimkeys/"

  # Apply changes on remote server and restart service
  log "Applying changes on remote server..."
  ssh "dkim-sync@$server" "sudo rsync --chown=root:root -a $TMP_DIR/opendkim/ /etc/opendkim/ && \
                           sudo rsync --chown=opendkim:opendkim -a $TMP_DIR/dkimkeys/ /etc/dkimkeys/ && \
                           sudo systemctl restart opendkim && \
                           rm -rf $TMP_DIR"

  # Clean up local copy
  rm -rf "$TMP_DIR"

  if [ $? -eq 0 ]; then
    log "Synchronization with server $server completed successfully"
    return 0
  else
    log "Error synchronizing server $server"
    return 1
  fi
}

# Main part of script
log "Starting DKIM configuration synchronization"

# Load servers
if ! SERVERS=($(load_servers "$CONFIG_FILE")); then
  log "Configuration error"
  exit 1
fi

# Sync all servers
for server in "${SERVERS[@]}"; do
  sync_server "$server"
done

log "Synchronization completed"