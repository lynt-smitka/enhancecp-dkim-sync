# DKIM Synchronization System for EnhanceCP

This system automates the synchronization of OpenDKIM configuration between a primary mail server and multiple secondary web servers for EnhanceCP hosting environments (https://enhance.com/).

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
3. Start the service on the primary server: `sudo systemctl enable --now dkim-sync.service`

## Operation

- The system monitors specified OpenDKIM configuration files for changes
- When changes are detected, it waits 5 seconds to collect related changes
- Changes are synchronized to all secondary web servers defined in the configuration
- Each synchronization is logged to `/var/log/dkim_sync/`

## Troubleshooting

If synchronization issues occur:
- Check log files in `/var/log/dkim_sync/`
- Verify SSH connectivity from primary mail server to secondary web servers
- Ensure sudoers configuration is correct on all servers