# Proxmox Backup Automation - Configuration Guide

## Overview

The Proxmox backup automation system is now fully configuration-driven, allowing you to easily add or modify backup nodes and their file backup requirements through simple inventory configuration.

## Configuration Structure

### Inventory Configuration

Each host in your inventory can be configured as a backup node by setting the following variables:

```yaml
hosts:
  your-node:
    ansible_host: your-node.domain.com
    backup_node: true                    # Enables backup automation for this node
    backup_interface_fallback: "eth0"    # Fallback interface for WOL (auto-detected if not set)
    backup_file_paths:                   # List of paths to backup (optional)
      - "/path/to/backup1"
      - "/path/to/backup2"
```

### Current Configuration

Based on your inventory, here's the current setup:

#### eagle
- **Backup Node**: Yes
- **File Backup Paths**: `/storage/backup`
- **Wake-up fractal**: Yes (20:55 PST)
- **File Backup**: Yes (21:00 PST)
- **Destination**: `/mnt/pve/backup_cluster/eagle-backup`

#### proxmox
- **Backup Node**: Yes
- **File Backup Paths**: None
- **Wake-up fractal**: Yes (20:55 PST)
- **File Backup**: No
- **LXC/CT Backup**: Yes (via Proxmox scheduler)

## How It Works

### 1. Backup Node Detection
- Any host with `backup_node: true` will have backup automation installed
- Only backup nodes will wake up fractal and participate in coordination

### 2. Wake-on-LAN (All Backup Nodes)
- **Every backup node** gets a cron job at 20:55 PST to wake fractal
- This ensures fractal is online regardless of which node starts backup first
- Uses automatic network interface detection with fallback

### 3. File Backup (Configurable)
- Nodes with `backup_file_paths` get a file backup script and cron job
- Each path in the list is backed up to `fractal:/mnt/pve/backup_cluster/{hostname}-backup/{path_basename}`
- Runs at 21:00 PST in parallel with Proxmox LXC/CT backups

### 4. Coordination & Shutdown
- Lock files in `/mnt/pve/backup_cluster/.lock/` coordinate between nodes
- fractal only shuts down when all backup jobs complete (no lock files remain)

## Adding New Backup Nodes

To add a new backup node, simply update your inventory:

```yaml
new-node:
  ansible_host: new-node.domain.com
  backup_node: true
  backup_file_paths:
    - "/opt/important-data"
    - "/etc"
```

Then run the playbook:
```bash
ansible-playbook playbooks/configure-backup-automation.yml --limit new-node --ask-vault-pass
```

## Removing File Backup from a Node

To stop backing up files from a node while keeping it as a backup node:

```yaml
your-node:
  backup_node: true
  backup_file_paths: []  # Empty list = no file backup
```

## Disabling Backup Automation

To completely disable backup automation for a node:

```yaml
your-node:
  backup_node: false  # or remove the line entirely
```

## Generated Scripts Per Node

### All Backup Nodes Get:
- `/usr/local/bin/pve-backup-hook.sh` - Proxmox backup hook
- `/usr/local/bin/fractal-wakeup.sh` - Wake-on-LAN script
- `/usr/local/bin/test-backup-workflow.sh` - Test script
- Cron job: fractal wake-up at 20:55 PST

### Nodes with File Backup Get:
- `/usr/local/bin/{hostname}-file-backup.sh` - Node-specific file backup
- Cron job: file backup at 21:00 PST
- Log rotation for backup logs

## Logging

### All Backup Nodes:
- `/var/log/fractal-wakeup.log` - Wake-on-LAN operations

### Nodes with File Backup:
- `/var/log/{hostname}-backup.log` - File backup operations
- `/var/log/{hostname}-rsync-*.log` - Individual rsync sessions

## Testing

Test any backup node with:
```bash
ssh root@your-node /usr/local/bin/test-backup-workflow.sh
```

Test specific components:
```bash
/usr/local/bin/test-backup-workflow.sh wol        # Wake-on-LAN only
/usr/local/bin/test-backup-workflow.sh storage    # Backup storage only
/usr/local/bin/test-backup-workflow.sh ssh        # SSH access to fractal
```

## Benefits of Configuration-Driven Approach

1. **No Hardcoded Logic**: No more eagle-specific or machine-specific code
2. **Easy Scaling**: Add new backup nodes by just updating inventory
3. **Flexible File Backup**: Each node can backup different paths
4. **Consistent Behavior**: All backup nodes use the same logic
5. **Maintainable**: Changes are made in configuration, not code

## Migration from Old Setup

The old eagle-specific setup has been replaced with this generic approach. The functionality is identical, but now:

- `eagle-file-backup.sh` → `eagle-file-backup.sh` (same name, generic template)
- Eagle-specific logic → Configuration-driven logic
- Hardcoded paths → Configurable paths in inventory