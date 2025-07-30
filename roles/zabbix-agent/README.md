# Zabbix Agent Role

This role installs and configures Zabbix Agent 2 for monitoring Proxmox cluster nodes, with optional NVIDIA GPU monitoring support.

## Features

- **Zabbix Agent 2 Installation**: Latest Zabbix 6.0 agent with modern plugin architecture
- **Automatic Configuration**: Template-based configuration with inventory variables
- **NVIDIA GPU Monitoring**: Optional GPU monitoring using official Zabbix NVIDIA template
- **Conditional Installation**: GPU monitoring only enabled for nodes with `has_nvidia_gpu: true`

## Requirements

- Debian/Ubuntu-based system (Proxmox VE)
- Zabbix Server 6.0 or later
- For GPU monitoring: NVIDIA GPU with compatible drivers

## Role Variables

### Required Variables (set in group_vars)
```yaml
zabbix_agent2_config:
  server: "192.168.1.193"              # Zabbix server IP
  serveractive: "192.168.1.193"        # Zabbix server IP for active checks
  hostname: "{{ inventory_hostname }}.{{ domain }}"  # Agent hostname
  timeout: 30                          # Timeout for agent operations
  logfilesize: 100                     # Log file size in MB
```

### Optional Variables (set per host)
```yaml
has_nvidia_gpu: true                   # Enable NVIDIA GPU monitoring
nvidia_gpu_model: "Quadro T2000"       # GPU model (documentation only)
```

## NVIDIA GPU Monitoring

When `has_nvidia_gpu: true` is set for a host, the role will:

1. **Install Dependencies**:
   - `nvidia-utils` (provides nvidia-smi command)
   - `python3-pip` and `nvidia-ml-py` (NVML Python bindings)

2. **Configure Zabbix Agent2**:
   - Enable NVIDIA plugin with appropriate timeouts
   - Configure plugin parameters for optimal performance

3. **Verify Installation**:
   - Test GPU detection with nvidia-smi
   - Display detected GPU information
   - Warn if GPU expected but not found

### Monitored GPU Metrics

The official Zabbix NVIDIA template provides comprehensive monitoring:

- **Performance**: GPU utilization percentage, memory usage
- **Thermal**: GPU temperature, fan speed
- **Power**: Power consumption, power limit
- **Memory**: Used/free VRAM, memory utilization
- **Clock**: GPU and memory clock speeds
- **Health**: ECC errors, throttling events
- **Processes**: Running GPU processes and their memory usage

## Zabbix Server Configuration

After running this role on hosts with NVIDIA GPUs:

1. **Import Template** (if not already available):
   - In Zabbix frontend: Configuration → Templates
   - Import the "NVIDIA GPU by HTTP" template

2. **Link Template to Host**:
   - Go to Configuration → Hosts
   - Find your GPU-enabled host (e.g., dell.bustinjailey.org)
   - Click on the host name
   - Go to Templates tab
   - Link the "NVIDIA GPU by HTTP" template

3. **Configure Discovery**:
   - The template will automatically discover available GPUs
   - GPU items will appear under Latest Data within 5-10 minutes

4. **Set Up Alerts** (optional):
   - Configure triggers for high temperature (>80°C)
   - Set memory usage alerts (>90%)
   - Monitor for GPU throttling events

## Example Inventory Configuration

```yaml
# inventories/production/hosts.yml
all:
  children:
    proxmox_cluster:
      hosts:
        dell:
          ansible_host: dell.bustinjailey.org
          has_nvidia_gpu: true
          nvidia_gpu_model: "Quadro T2000"
        eagle:
          ansible_host: eagle.bustinjailey.org
          # No GPU monitoring for this host
```

## Troubleshooting

### GPU Not Detected
If the role reports "NVIDIA GPU expected but not detected":

1. **Check NVIDIA Drivers**:
   ```bash
   nvidia-smi
   lsmod | grep nvidia
   ```

2. **Verify Hardware**:
   ```bash
   lspci | grep -i nvidia
   ```

3. **Install Drivers** (if needed):
   ```bash
   apt update
   apt install nvidia-driver-470  # or latest version
   reboot
   ```

### Zabbix Agent Issues
If GPU monitoring doesn't appear in Zabbix:

1. **Check Agent Logs**:
   ```bash
   tail -f /var/log/zabbix/zabbix_agent2.log
   ```

2. **Test NVIDIA Plugin**:
   ```bash
   zabbix_agent2 -t nvidia.gpu.discovery
   ```

3. **Verify Configuration**:
   ```bash
   grep -i nvidia /etc/zabbix/zabbix_agent2.conf
   ```

## Dependencies

This role depends on:
- Internet access for downloading Zabbix repository
- Sudo/root privileges for package installation
- Network connectivity to Zabbix server

## Tags

- `monitoring`: Install and configure Zabbix monitoring
- `zabbix`: Zabbix-specific tasks
- `gpu`: NVIDIA GPU monitoring tasks (when applicable)

## Example Playbook Usage

```yaml
- hosts: proxmox_cluster
  roles:
    - role: zabbix-agent
      tags: ['monitoring', 'zabbix']
      when: enable_zabbix_monitoring | default(true)