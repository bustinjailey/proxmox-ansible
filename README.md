# Proxmox Cluster Ansible Configuration

This repository contains Ansible playbooks and roles for managing a Proxmox VE cluster.

## Overview

This Ansible configuration manages a 4-node Proxmox cluster with the following features:

- Automated Zabbix agent deployment and configuration
- Network UPS Tools (NUT) configuration for power management
- NVIDIA GPU drivers with CUDA support for LXC passthrough
- Proxmox post-installation script automation
- DNS configuration management
- Automated updates for hosts, LXCs, and VMs
- Automated backup coordination with wake-on-LAN support

### Cluster Nodes

- eagle.bustinjailey.org (UPS connected via USB)
- proxmox.bustinjailey.org
- fractal.bustinjailey.org
- dell.bustinjailey.org (NVIDIA Quadro T2000 GPU for Ollama)

## Prerequisites

1. Install Ansible on your control machine:

   ```bash
   pip install ansible proxmoxer
   ```

2. Install required Ansible collections:

   ```bash
   ansible-galaxy collection install community.general
   ```

3. Set up SSH key authentication to all Proxmox nodes as root

4. Clone this repository:
   ```bash
   git clone <repository-url>
   cd proxmox-ansible
   ```

## Initial Setup

### 1. Configure Passwords

Copy the example vault file:

```bash
cp group_vars/proxmox_cluster/vault.yml.example group_vars/proxmox_cluster/vault.yml
```

Create encrypted vault with your passwords:

```bash
ansible-vault create group_vars/proxmox_cluster/vault.yml
```

Add the following content:

```yaml
# NUT UPS passwords
nut_upsmon_password: "your-secure-upsmon-password-here"
```

### 2. Verify Inventory

Review and adjust the inventory file if needed:

```bash
cat inventories/production/hosts.yml
```

## Usage

### Initial Configuration

Apply the base configuration to all nodes:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --ask-vault-pass
```

### Update Operations

Update all nodes, containers, and VMs:

```bash
ansible-playbook playbooks/update-cluster.yml --ask-vault-pass
```

Update a specific node:

```bash
ansible-playbook playbooks/update-cluster.yml --limit eagle --ask-vault-pass
```

### Testing Changes

Dry run to test changes without applying them:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --check --ask-vault-pass
```

### Selective Configuration

Skip the post-install script:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --skip-tags post-install --ask-vault-pass
```

### NVIDIA GPU Configuration

Install NVIDIA drivers on GPU-enabled nodes:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --tags nvidia --ask-vault-pass
```

Install only on the Dell node:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --limit dell --tags nvidia --ask-vault-pass
```

Verify GPU installation:

```bash
ansible dell -m shell -a "nvidia-smi"
ansible dell -m shell -a "/usr/local/bin/verify-lxc-gpu.sh"
```

### Backup Automation Configuration

Configure automated backup with wake-on-LAN for fractal:

```bash
ansible-playbook playbooks/configure-backup-automation.yml --ask-vault-pass
```

Configure backup automation as part of base configuration:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --tags backup --ask-vault-pass
```

Test wake-on-LAN functionality:

```bash
ansible eagle -m shell -a "/usr/local/bin/fractal-wakeup.sh"
ansible proxmox -m shell -a "/usr/local/bin/fractal-wakeup.sh"
```

## Managing Secrets with Ansible Vault

### Using a Password File

Create a password file (don't commit this to git):

```bash
echo "your-vault-password" > ~/.vault_pass
chmod 600 ~/.vault_pass
```

Run playbooks with password file:

```bash
ansible-playbook playbooks/apply-base-configuration.yml --vault-password-file ~/.vault_pass
```

### Editing Vault

Edit existing vault:

```bash
ansible-vault edit group_vars/proxmox_cluster/vault.yml
```

### View Vault Contents

View encrypted vault contents:

```bash
ansible-vault view group_vars/proxmox_cluster/vault.yml
```

## Features

### NVIDIA GPU Support

- Proxmox-compatible NVIDIA driver installation (driver version 535)
- CUDA toolkit for compute workloads (CUDA 12.2)
- LXC GPU passthrough configuration for containers
- Automatic device node creation and management
- Optimized for Ollama and AI workloads
- Comprehensive verification and testing tools

### Zabbix Agent 2

- Automatically installed and configured on all nodes
- Reports to Zabbix server at 192.168.1.193
- Configured with proper hostname for each node
- Optional NVIDIA GPU monitoring support

### Network UPS Tools (NUT)

- Eagle node configured as NUT server (UPS connected via USB)
- Other nodes configured as NUT clients
- Supports APC SmartUPS 2200
- Automatic shutdown coordination during power events

### Backup Automation

- Automated wake-on-LAN for fractal backup server
- Coordinated backup execution with race condition handling
- Eagle file backup with rsync to `/mnt/pve/backup_cluster/eagle-backup`
- Smart shutdown coordination when all backups complete
- Comprehensive logging and monitoring
- Automatic network interface detection for WOL

### DNS Configuration

- Primary DNS server: 192.168.1.187
- Fallback DNS: 8.8.8.8
- Consistent configuration across all nodes

### Automated Updates

- Serial updates (one node at a time) to maintain cluster availability
- Automatic package updates for Proxmox hosts
- LXC container updates with support for helper script update commands
- VM updates for systems with QEMU guest agent
- Automatic error handling and logging

### Post-Installation Configuration

- Automatically runs the Proxmox community post-install script
- Configures no-subscription repository
- Removes subscription nag
- Runs only once per node (idempotent)

## Directory Structure

```
proxmox-ansible/
├── ansible.cfg
├── inventories/
│   └── production/
│       └── hosts.yml
├── group_vars/
│   └── proxmox_cluster.yml
│   └── proxmox_cluster/
│       ├── vault.yml (encrypted)
│       └── vault.yml.example
├── roles/
│   ├── common/
│   ├── nvidia-drivers/
│   ├── zabbix-agent/
│   └── nut-ups/
└── playbooks/
    ├── apply-base-configuration.yml
    ├── update-cluster.yml
    ├── update-lxc.yml
    └── update-vm.yml
```

## Important Notes

1. Updates are performed serially to maintain cluster availability
2. The post-install script runs only once per node
3. LXC and VM updates include error handling to prevent cascade failures
4. The UPS configuration assumes the APC SmartUPS 2200 is connected to the eagle node
5. All passwords should be stored in the Ansible vault, never in plain text
6. Backup automation requires SSH key access to fractal and proper network configuration

## Troubleshooting

### SSH Connection Issues

Ensure root SSH access is configured:

```bash
ssh root@eagle.bustinjailey.org
```

### Vault Password Issues

Reset vault password:

```bash
ansible-vault rekey group_vars/proxmox_cluster/vault.yml
```

### Update Failures

Check logs for specific node:

```bash
ansible-playbook playbooks/update-cluster.yml --limit problematic-node -vvv --ask-vault-pass
```

### NUT/UPS Issues

Check UPS status on eagle node:

```bash
ssh root@eagle.bustinjailey.org
upsc apc2200@localhost
```

Check NUT client status on other nodes:

```bash
ssh root@proxmox.bustinjailey.org
upsc apc2200@eagle.bustinjailey.org
```

### NVIDIA/GPU Issues

Check GPU status on Dell node:

```bash
ssh root@dell.bustinjailey.org
nvidia-smi
/usr/local/bin/verify-lxc-gpu.sh
```

Restart NVIDIA services:

```bash
ssh root@dell.bustinjailey.org
systemctl restart nvidia-devices
systemctl restart nvidia-persistenced
```

Check LXC GPU passthrough:

```bash
# Verify device nodes exist
ls -la /dev/nvidia*

# Check container configuration
cat /etc/pve/lxc/<CONTAINER_ID>.conf

# Test GPU in container
pct enter <CONTAINER_ID>
nvidia-smi  # Should work if drivers installed in container
```

### Backup Automation Issues

Test backup automation setup:

```bash
# Run comprehensive backup test
ssh root@eagle.bustinjailey.org
/usr/local/bin/test-backup-workflow.sh

ssh root@proxmox.bustinjailey.org
/usr/local/bin/test-backup-workflow.sh
```

Test individual components:

```bash
# Test wake-on-LAN only
/usr/local/bin/test-backup-workflow.sh wol

# Test backup storage
/usr/local/bin/test-backup-workflow.sh storage

# Test fractal connectivity
/usr/local/bin/test-backup-workflow.sh connectivity
```

Check backup logs:

```bash
# Monitor wake-up process
tail -f /var/log/fractal-wakeup.log

# Monitor eagle file backup
tail -f /var/log/eagle-backup.log

# Monitor backup hooks
tail -f /var/log/syslog | grep pve-backup-hook
```

Manual backup testing:

```bash
# Test fractal wake-up manually
/usr/local/bin/fractal-wakeup.sh

# Test eagle file backup manually (eagle only)
/usr/local/bin/eagle-file-backup.sh

# Test backup hook manually
/usr/local/bin/pve-backup-hook.sh job-start backup 100
/usr/local/bin/pve-backup-hook.sh job-end backup 100
```

Check backup coordination:

```bash
# View active backup locks
ls -la /mnt/pve/backup_cluster/.lock/

# Check backup storage mount
mountpoint /mnt/pve/backup_cluster
df -h /mnt/pve/backup_cluster
```

## Contributing

1. Test all changes in a development environment first
2. Use ansible-lint to check playbooks
3. Document any new variables or features
4. Keep sensitive data in vault files
