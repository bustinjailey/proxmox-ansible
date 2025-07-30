# Proxmox Cluster Ansible Configuration

This repository contains Ansible playbooks and roles for managing a Proxmox VE cluster.

## Overview

This Ansible configuration manages a 4-node Proxmox cluster with the following features:

- Automated Zabbix agent deployment and configuration
- Network UPS Tools (NUT) configuration for power management
- Proxmox post-installation script automation
- DNS configuration management
- Automated updates for hosts, LXCs, and VMs

### Cluster Nodes

- eagle.bustinjailey.org (UPS connected via USB)
- proxmox.bustinjailey.org
- fractal.bustinjailey.org
- dell.bustinjailey.org

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

### Zabbix Agent 2

- Automatically installed and configured on all nodes
- Reports to Zabbix server at 192.168.1.193
- Configured with proper hostname for each node

### Network UPS Tools (NUT)

- Eagle node configured as NUT server (UPS connected via USB)
- Other nodes configured as NUT clients
- Supports APC SmartUPS 2200
- Automatic shutdown coordination during power events

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

## Contributing

1. Test all changes in a development environment first
2. Use ansible-lint to check playbooks
3. Document any new variables or features
4. Keep sensitive data in vault files
