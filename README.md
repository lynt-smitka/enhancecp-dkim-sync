# DKIM Synchronization System for EnhanceCP

This system automates the synchronization of OpenDKIM configuration between a primary mail server and multiple secondary web servers for EnhanceCP hosting environments (https://enhance.com/).

## Motivation

In default EnhanceCP configuration, DKIM signatures are only applied to emails sent directly from the mail server's mailboxes. Emails sent from web servers are not signed by default, which can lead to delivery issues and spam filtering problems. This script solves this by synchronizing DKIM configuration across all servers, ensuring consistent email signing regardless of the sending server.

## Components

- `dkim_watch.sh`: Monitors OpenDKIM configuration files for changes
- `dkim_sync.sh`: Synchronizes configuration to secondary servers
- `install.sh`: Installation script for both primary and secondary servers

## Security

- The system operates using a dedicated `dkim-sync` system user
- Root-level operations are strictly limited via sudoers configuration
- Only specific, whitelisted commands can be executed with elevated privileges:
  - On primary: Only specific rsync commands to copy files to temporary directories
  - On secondary: Only specific rsync commands to deploy files and restart the service

## Installation

### Primary Mail Server

```bash
sudo ./install.sh primary
```

This will:
1. Install required packages (inotify-tools, rsync)
2. Create the dkim-sync user
3. Generate SSH keys for remote authentication
4. Set up the monitoring scripts and service
5. Configure sudoers with minimal required permissions

### Secondary Web Servers

```bash
sudo ./install.sh secondary
```

This will:
1. Create the dkim-sync user
2. Set up SSH authentication directory
3. Import the primary server's SSH key (if present)
4. Configure sudoers with minimal required permissions

## Post-Installation

After installation:

1. On the primary mail server, configure `/etc/dkim_sync/servers.conf` with a list of secondary web servers
2. Copy the primary mail server's SSH public key to each secondary web server's authorized_keys file
3. (Optional) Test the connection to all configured servers:
   ```bash
   sudo ./install.sh test
   ```
   This will automatically test SSH connectivity to all servers and accept their host keys
4. Start the service on the primary server: `sudo systemctl enable --now dkim-sync.service`

## Operation

- The system monitors specified OpenDKIM configuration files for changes
- When changes are detected, it waits 5 seconds to collect related changes
- Changes are synchronized to all secondary web servers defined in the configuration
- Each synchronization is logged to `/var/log/dkim_sync/`

## Manual Installation Steps

If you prefer to install the system manually instead of using the installation script:

### Primary Mail Server

1. Install required packages:
   - inotify-tools
   - rsync

2. Create user `dkim-sync` with home directory `/home/dkim-sync`

3. Generate SSH key pair for the `dkim-sync` user

4. Copy files to their destinations:
   - `dkim_sync.sh` → `/usr/local/bin/`
   - `dkim_watch.sh` → `/usr/local/bin/`
   - `dkim-sync.service` → `/etc/systemd/system/`
   - `dkim-sync-primary` → `/etc/sudoers.d/`

5. Create required directories (owned by dkim-sync):
   - `/var/log/dkim_sync/` 
   - `/etc/dkim_sync/`
   - `/etc/dkim_sync/servers.conf`

6. Enable and start the systemd service

### Secondary Web Servers

1. Create system user `dkim-sync` with home directory `/home/dkim-sync`

2. Add primary server's SSH public key to dkim-sync's `authorized_keys`

3. Copy files to their destinations:
   - `dkim-sync-secondary` → `/etc/sudoers.d/`

## Troubleshooting

If synchronization issues occur:
- Check log files in `/var/log/dkim_sync/`
- Verify SSH connectivity from primary mail server to secondary web servers - `sudo -u dkim-sync ssh SERVER_IP`, you should be connected without any password prompts
- Ensure sudoers configuration is correct on all servers
