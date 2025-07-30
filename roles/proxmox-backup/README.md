# Proxmox Backup Automation Role

This Ansible role automates the backup process for Proxmox VE nodes by coordinating wake-on-LAN for the backup server (Fractal), managing backup hooks, and handling file synchronization.

## Features

- **Automatic Wake-on-LAN**: Starts Fractal backup server 5 minutes before scheduled backups
- **Backup Coordination**: Manages race conditions between multiple Proxmox nodes
- **File Backup**: Syncs Eagle's `/storage/backup` directory to Fractal
- **Smart Shutdown**: Automatically powers down Fractal when all backups complete
- **Network Interface Detection**: Automatically detects the best interface for WOL
- **Comprehensive Logging**: Detailed logging with log rotation

## Architecture

### Backup Flow
1. **20:55 PST**: Cron job triggers Fractal wake-up script
2. **21:00 PST**: Proxmox backup jobs start
3. **Job Start**: Hook script ensures Fractal is online and creates lock file
4. **Backup Execution**: LXC/CT backups run, Eagle file sync runs in parallel
5. **Job End**: Hook script removes lock file and checks for remaining jobs
6. **Shutdown**: If no jobs remain, Fractal is shut down after 30-second delay

### Lock Mechanism
- Lock files stored in `/mnt/pve/backup_cluster/.lock/`
- Each node creates `{hostname}.lock` at job start
- Lock files removed at job end
- Fractal shutdown only occurs when no lock files remain

## Configuration

### Required Variables

The role uses variables defined in `vars/main.yml`:

```yaml
fractal_ip: "192.168.1.86"
fractal_mac: "a8:a1:59:0c:6a:ae"
backup_mount_point: "/mnt/pve/backup_cluster"
```

### Host-Specific Variables

Set in inventory for interface fallbacks:

```yaml
# For eagle
backup_interface_fallback: "enp9s0f0np0"

# For proxmox  
backup_interface_fallback: "eno1"
```

## Files Deployed

### Scripts
- `/usr/local/bin/pve-backup-hook.sh` - Proxmox backup hook script
- `/usr/local/bin/fractal-wakeup.sh` - Wake-on-LAN script
- `/usr/local/bin/eagle-file-backup.sh` - Eagle file backup script (eagle only)

### Configuration
- `/etc/vzdump.conf` - Proxmox backup configuration with hook
- `/etc/logrotate.d/proxmox-backup` - Log rotation configuration

### Cron Jobs
- **20:55 daily**: Fractal wake-up (`fractal-wakeup.sh`)
- **21:00 daily**: Eagle file backup (`eagle-file-backup.sh`, eagle only)

## Logging

### Log Files
- `/var/log/fractal-wakeup.log` - Wake-on-LAN operations
- `/var/log/eagle-backup.log` - Eagle file backup operations
- `/var/log/eagle-rsync-YYYYMMDD-HHMMSS.log` - Individual rsync operations
- System logs via `logger` with tag `pve-backup-hook`

### Log Rotation
- Daily rotation with 7-day retention
- Compression enabled
- Automatic cleanup of old rsync logs

## Network Requirements

### Wake-on-LAN
- Fractal must have WOL enabled in BIOS/UEFI
- Network interface must support WOL (verified with `ethtool`)
- MAC address must be correct: `a8:a1:59:0c:6a:ae`

### Connectivity
- SSH access from Proxmox nodes to fractal as root
- Port 445 (SMB) accessible on fractal for health checks
- Backup storage mounted at `/mnt/pve/backup_cluster`

## SSH Key Setup

**Required**: SSH keys must be configured for passwordless access from eagle and proxmox to fractal.

### Setting up SSH Keys

1. **Generate SSH key on each Proxmox node** (if not already done):
   ```bash
   # On eagle and proxmox nodes
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
   ```

2. **Copy public key to fractal**:
   ```bash
   # From eagle and proxmox nodes
   ssh-copy-id root@192.168.1.86
   ```

3. **Test SSH access**:
   ```bash
   # Should work without password prompt
   ssh root@192.168.1.86 "echo 'SSH test successful'"
   ```

4. **Verify with test script**:
   ```bash
   /usr/local/bin/test-backup-workflow.sh ssh
   ```

## Troubleshooting

### Check WOL Interface Detection
```bash
# View detected interface
ansible eagle -m shell -a "ip route show default | awk '/default/ { print \$5 }' | head -1"

# Check WOL capability
ansible eagle -m shell -a "ethtool enp9s0f0np0 | grep -i wake-on"
```

### Monitor Backup Process
```bash
# Check backup hook logs
tail -f /var/log/syslog | grep pve-backup-hook

# Check wake-up logs
tail -f /var/log/fractal-wakeup.log

# Check eagle backup logs
tail -f /var/log/eagle-backup.log
```

### Verify Lock Mechanism
```bash
# Check active locks
ls -la /mnt/pve/backup_cluster/.lock/

# Manual lock cleanup (if needed)
rm -f /mnt/pve/backup_cluster/.lock/*.lock
```

### Test Wake-on-LAN
```bash
# Manual WOL test
/usr/local/bin/fractal-wakeup.sh

# Check if Fractal responds
nc -z -w 2 192.168.1.86 445
```

## Dependencies

### Required Packages
- `etherwake` - Wake-on-LAN functionality
- `netcat-openbsd` - Network connectivity testing
- `rsync` - File synchronization

### Proxmox Configuration
- Backup jobs must be configured in Proxmox web interface
- Backup storage must point to `/mnt/pve/backup_cluster`
- Storage must be mounted before backup jobs run

## Security Notes

- SSH keys must be configured for passwordless access to Fractal
- Backup storage should use appropriate permissions (755 for directories)
- Log files contain operational information but no sensitive data
- WOL packets are sent only on detected/configured interfaces

## Maintenance

### Regular Tasks
- Monitor log files for errors
- Verify backup storage space
- Test WOL functionality periodically
- Review and clean old backup files

### Updates
- Update MAC address if Fractal network hardware changes
- Adjust timing if backup schedule changes
- Update interface names if network configuration changes