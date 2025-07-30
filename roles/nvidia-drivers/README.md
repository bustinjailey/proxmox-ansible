# NVIDIA Drivers Role

This role installs and configures NVIDIA drivers with CUDA support for Proxmox hosts, specifically optimized for LXC GPU passthrough and Ollama workloads.

## Overview

This role provides a comprehensive solution for NVIDIA GPU support on Proxmox hosts, including:

- **Proxmox-compatible NVIDIA driver installation**
- **CUDA toolkit for compute workloads**
- **LXC GPU passthrough configuration**
- **Device node management for containers**
- **Verification and testing tools**
- **Ollama optimization**

## Features

- ✅ **Proxmox Compatibility**: Uses proper kernel headers and stable driver versions
- ✅ **LXC GPU Passthrough**: Complete configuration for container GPU access
- ✅ **CUDA Support**: Full CUDA toolkit installation for compute workloads
- ✅ **Automatic Device Management**: Creates and manages NVIDIA device nodes
- ✅ **Verification Tools**: Comprehensive testing and validation scripts
- ✅ **Ollama Optimized**: Specifically configured for optimal Ollama performance
- ✅ **Error Handling**: Robust error detection and recovery procedures

## Requirements

### Hardware
- NVIDIA GPU (tested with Quadro T2000)
- Proxmox VE host

### Software
- Proxmox VE 7.0 or later
- Debian-based system (Proxmox uses Debian)
- Internet connection for package downloads

## Role Variables

### Required Variables
```yaml
has_nvidia_gpu: true                    # Enable NVIDIA driver installation
nvidia_gpu_model: "Quadro T2000"       # GPU model (documentation only)
```

### Optional Variables
```yaml
# Driver versions (defined in vars/main.yml)
nvidia_driver_version: "535"           # NVIDIA driver version
cuda_version: "12-2"                   # CUDA version

# Ollama optimizations
ollama_gpu_optimizations:
  enable_persistence: true             # Enable GPU persistence mode
  enable_mig: false                    # Disable Multi-Instance GPU
  power_limit: null                    # Set power limit (watts) if needed
  compute_mode: "Default"              # GPU compute mode
```

## Dependencies

This role automatically installs:
- `build-essential` - Compilation tools
- `dkms` - Dynamic kernel module support
- `pve-headers` - Proxmox kernel headers
- `nvidia-driver-535` - NVIDIA driver
- `cuda-toolkit-12-2` - CUDA development toolkit
- `nvidia-container-toolkit` - Container GPU support

## Example Playbook

```yaml
---
- name: Configure Proxmox nodes with NVIDIA GPU support
  hosts: proxmox_cluster
  become: yes
  roles:
    - role: nvidia-drivers
      when: has_nvidia_gpu | default(false)
```

## Inventory Configuration

```yaml
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
          # No GPU configuration
```

## LXC Container Configuration

After running this role, configure your Ollama LXC container by adding these lines to `/etc/pve/lxc/<CONTAINER_ID>.conf`:

```bash
# GPU Device Access
lxc.cgroup2.devices.allow: c 195:* rwm
lxc.cgroup2.devices.allow: c 235:* rwm
lxc.cgroup2.devices.allow: c 509:* rwm

# Device Mounts
lxc.mount.entry: /dev/nvidia0 dev/nvidia0 none bind,optional,create=file
lxc.mount.entry: /dev/nvidiactl dev/nvidiactl none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm dev/nvidia-uvm none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-uvm-tools dev/nvidia-uvm-tools none bind,optional,create=file
lxc.mount.entry: /dev/nvidia-modeset dev/nvidia-modeset none bind,optional,create=file

# Features
features: nesting=1
```

Then restart the container:
```bash
pct restart <CONTAINER_ID>
```

## Verification

The role includes comprehensive verification tools:

### Host Verification
```bash
# Test NVIDIA driver
nvidia-smi

# Test CUDA
nvcc --version

# Run comprehensive verification
/usr/local/bin/verify-lxc-gpu.sh
```

### Container Verification
Inside your LXC container:
```bash
# Check device access
ls -la /dev/nvidia*

# Test NVIDIA driver (after installing in container)
nvidia-smi

# Test with Docker (if using containerized Ollama)
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Ollama Setup

After GPU passthrough is configured:

1. **Install NVIDIA drivers in the LXC container**:
   ```bash
   # Inside the container
   apt update
   apt install nvidia-driver-535
   ```

2. **Install Ollama**:
   ```bash
   curl -fsSL https://ollama.ai/install.sh | sh
   ```

3. **Verify GPU access**:
   ```bash
   ollama run llama2
   # Should show GPU utilization in nvidia-smi
   ```

## Troubleshooting

### Driver Installation Issues

**Problem**: `nvidia-smi` fails with "couldn't communicate with NVIDIA driver"
**Solution**: 
1. Check if modules are loaded: `lsmod | grep nvidia`
2. Reload modules: `systemctl restart nvidia-devices`
3. Verify device nodes: `ls -la /dev/nvidia*`

**Problem**: CUDA not found
**Solution**:
1. Check CUDA installation: `nvcc --version`
2. Verify library path: `ldconfig -p | grep cuda`
3. Source CUDA environment: `export PATH=/usr/local/cuda/bin:$PATH`

### LXC Container Issues

**Problem**: No GPU devices in container
**Solution**:
1. Verify host device nodes: `/usr/local/bin/verify-lxc-gpu.sh`
2. Check container config: `cat /etc/pve/lxc/<ID>.conf`
3. Restart container: `pct restart <ID>`

**Problem**: Permission denied accessing GPU
**Solution**:
1. Check device permissions: `ls -la /dev/nvidia*`
2. Verify cgroup rules in container config
3. Ensure container has `features: nesting=1`

### Ollama Performance Issues

**Problem**: Ollama not using GPU
**Solution**:
1. Check GPU visibility: `nvidia-smi` inside container
2. Verify Ollama GPU support: `ollama ps` should show GPU models
3. Check CUDA compatibility: Ensure CUDA version matches requirements

## Files Created

This role creates the following files:

- `/usr/local/bin/create-nvidia-devices.sh` - Device node creation script
- `/usr/local/bin/verify-lxc-gpu.sh` - GPU verification script
- `/etc/systemd/system/nvidia-devices.service` - Device management service
- `/etc/systemd/system/nvidia-persistenced.service` - Persistence daemon
- `/etc/modprobe.d/lxc-gpu-passthrough.conf` - Module configuration
- `/etc/modules-load.d/nvidia.conf` - Module loading configuration
- `/etc/ld.so.conf.d/nvidia.conf` - Library path configuration

## Tags

Use these tags to run specific parts of the role:

```bash
# Install only drivers
ansible-playbook playbook.yml --tags nvidia-drivers

# Configure only LXC passthrough
ansible-playbook playbook.yml --tags lxc-gpu

# Run only verification
ansible-playbook playbook.yml --tags gpu-verify
```

## Security Considerations

- GPU device nodes are created with 666 permissions for LXC access
- Container isolation is maintained through cgroup controls
- NVIDIA persistence daemon runs with minimal privileges
- All scripts are owned by root with appropriate permissions

## Performance Optimization

For optimal Ollama performance:

1. **Enable GPU persistence**: Reduces initialization time
2. **Use appropriate CUDA version**: Matches Ollama requirements
3. **Configure power limits**: Prevents thermal throttling
4. **Monitor GPU utilization**: Use `nvidia-smi` to verify usage

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| NVIDIA Driver | 535.x | Stable, long-term support |
| CUDA Toolkit | 12.2 | Compatible with most AI workloads |
| Proxmox VE | 7.0+ | Tested on current versions |
| Ollama | Latest | Supports CUDA 11.0+ |

## Contributing

When modifying this role:

1. Test on a development Proxmox environment first
2. Verify LXC container functionality is not broken
3. Update documentation for any new variables or features
4. Test with actual Ollama workloads to ensure performance

## License

This role is provided as-is for educational and operational use.