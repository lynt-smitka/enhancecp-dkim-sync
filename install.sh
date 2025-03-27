#!/bin/bash
# install.sh - DKIM synchronization installation script [experimental]
# Usage: ./install.sh [primary|secondary|test]

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root"
  exit 1
fi

# Check arguments
if [ $# -ne 1 ] || [[ ! "$1" =~ ^(primary|secondary|test)$ ]]; then
  echo "Usage: $0 [primary|secondary|test]"
  exit 1
fi

MODE="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Primary server installation
install_primary() {
  # Install required packages
  echo "Installing packages..."
  apt-get update && apt-get install -y inotify-tools rsync
  
  # Create dkim-sync user
  echo "Creating dkim-sync user..."
  if ! id "dkim-sync" &>/dev/null; then
    adduser --system --home /home/dkim-sync --shell /bin/bash dkim-sync
  fi
  
  # Generate SSH keys
  echo "Setting up SSH keys..."
  sudo -u dkim-sync mkdir -p /home/dkim-sync/.ssh
  sudo -u dkim-sync chmod 700 /home/dkim-sync/.ssh
  
  if [ ! -f /home/dkim-sync/.ssh/id_ed25519 ]; then
    sudo -u dkim-sync ssh-keygen -t ed25519 -f /home/dkim-sync/.ssh/id_ed25519 -N ""
  fi
  
  # Copy scripts
  echo "Copying scripts..."
  cp "$SCRIPT_DIR/dkim_sync.sh" /usr/local/bin/
  cp "$SCRIPT_DIR/dkim_watch.sh" /usr/local/bin/
  chmod +x /usr/local/bin/dkim_sync.sh
  chmod +x /usr/local/bin/dkim_watch.sh
  
  # Setup systemd service
  echo "Setting up systemd service..."
  cp "$SCRIPT_DIR/dkim-sync.service" /etc/systemd/system/
  systemctl daemon-reload
  systemctl enable dkim-sync
  
  # Create log directory
  echo "Creating log directory..."
  mkdir -p /var/log/dkim_sync
  chown dkim-sync:nogroup /var/log/dkim_sync
  
  # Setup sudoers configuration
  echo "Setting up sudoers..."
  cp "$SCRIPT_DIR/dkim-sync-primary" /etc/sudoers.d/
  chmod 440 /etc/sudoers.d/dkim-sync-primary
  
  # Create config directory and file
  echo "Creating config directory..."
  mkdir -p /etc/dkim_sync
  chown dkim-sync:nogroup /etc/dkim_sync
  
  # Create empty servers.conf if it doesn't exist
  if [ ! -f /etc/dkim_sync/servers.conf ]; then
    touch /etc/dkim_sync/servers.conf
    chown dkim-sync:nogroup /etc/dkim_sync/servers.conf
  fi
  
  # Display public key
  echo "Public SSH key for remote server configuration:"
  cat /home/dkim-sync/.ssh/id_ed25519.pub
  
  echo ""
  echo "Next steps:"
  echo "1. Define servers in /etc/dkim_sync/servers.conf"
  echo "2. Copy the SSH public key above to authorized_keys on secondary servers"
  echo "3. Run 'systemctl start dkim-sync' to start the synchronization service"
}

# Secondary server installation
install_secondary() {
  # Create dkim-sync user
  echo "Creating dkim-sync user..."
  if ! id "dkim-sync" &>/dev/null; then
    adduser --system --home /home/dkim-sync --shell /bin/bash dkim-sync
  fi
  
  # Setup SSH authentication
  echo "Setting up SSH directory..."
  sudo -u dkim-sync mkdir -p /home/dkim-sync/.ssh
  sudo -u dkim-sync chmod 700 /home/dkim-sync/.ssh
  
  if [ ! -f /home/dkim-sync/.ssh/authorized_keys ]; then
    touch /home/dkim-sync/.ssh/authorized_keys
  fi
  
  chmod 600 /home/dkim-sync/.ssh/authorized_keys
  chown dkim-sync:nogroup /home/dkim-sync/.ssh/authorized_keys
  
  # If public key exists in script directory, add it to authorized_keys
  if [ -f "$SCRIPT_DIR/id_ed25519.pub" ]; then
    cat "$SCRIPT_DIR/id_ed25519.pub" >> /home/dkim-sync/.ssh/authorized_keys
    echo "Added public key to authorized_keys"
  fi
  
  # Setup sudoers configuration
  echo "Setting up sudoers..."
  cp "$SCRIPT_DIR/dkim-sync-secondary" /etc/sudoers.d/
  chmod 440 /etc/sudoers.d/dkim-sync-secondary
}

# Test connection to all servers
test_connection() {
  if [ ! -f /etc/dkim_sync/servers.conf ]; then
    echo "Error: /etc/dkim_sync/servers.conf not found"
    exit 1
  fi

  echo "Testing connection to all servers..."
  
  while IFS= read -r server; do
    # Skip empty lines and comments
    [[ -z "$server" || "$server" =~ ^#.*$ ]] && continue
    
    echo "Testing connection to $server..."
    
    # Try to connect and automatically accept host key
    if sudo -u dkim-sync ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "$server" "echo 'Connection successful'"; then
      echo "✓ Successfully connected to $server"
    else
      echo "✗ Failed to connect to $server"
    fi
  done < /etc/dkim_sync/servers.conf
}

# Main installation
echo "Installing DKIM synchronization in $MODE mode..."

if [ "$MODE" = "primary" ]; then
  install_primary
elif [ "$MODE" = "secondary" ]; then
  install_secondary
elif [ "$MODE" = "test" ]; then
  test_connection
fi

echo "Installation complete"