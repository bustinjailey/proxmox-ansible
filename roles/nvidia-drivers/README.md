# NVIDIA Drivers Role

This role installs and configures NVIDIA drivers with CUDA support for Proxmox hosts using the **official NVIDIA network repository method**, specifically optimized for LXC GPU passthrough and GPU workloads.

## Overview

This role provides a comprehensive solution for NVIDIA GPU support on Proxmox hosts, including:

- **Official NVIDIA Network Repository Installation** - Following NVIDIA's documented Debian installation method
- **Automatic Driver Version Management** - Repository determines the best compatible driver version
- **CUDA toolkit for compute workloads**
- **LXC GPU passthrough configuration**
- **Device node management for containers**
- **Verification and testing tools**
- **Proxmox compatibility** - Works with Proxmox kernel headers

## Features

- ✅ **Official NVIDIA Method**: Uses the official network repository installation from NVIDIA documentation
- ✅ **Automatic Version Management**: Repository automatically selects compatible driver and CUDA versions
- ✅ **Proxmox Compatibility**: Uses proper kernel headers and tested installation method
- ✅ **LXC GPU Passthrough**: Complete configuration for container GPU access
- ✅ **CUDA Support**: Full CUDA toolkit installation for compute workloads
- ✅ **Automatic Device Management**: Creates and manages NVIDIA device nodes
- ✅ **Verification Tools**: Comprehensive testing and validation scripts
- ✅ **Error Handling**: Robust error detection and recovery procedures

## Requirements

### Hardware
- NVIDIA GPU (tested with various models including Quadro T2000)
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
# Installation configuration (defined in vars/main.yml)
nvidia_cuda_keyring_url: "https://developer.download.nvidia.com/compute/cuda/repos/debian12/x86_64/cuda-keyring_1.1-1_all.deb"

# GPU optimizations
gpu_optimizations:
  persistence_mode: true               # Enable GPU persistence mode
  lxc:
    device_file_uid: 0                 # Device file ownership
    device_file_gid: 0
    device_file_mode: "0666"           # Device file permissions
  performance:
    enable_mig: false                  # Disable Multi-Instance GPU
    power_limit: null                  # Set power limit (watts) if needed
    compute_mode: "Default"            # GPU compute mode

# Installation timeouts and retries
installation_config:
  download_timeout: 30
  download_retries: 3
  verification_retries: 5
  verification_delay: 10
  reboot_timeout: 600
```

## Dependencies

This role automatically installs:
- `build-essential` - Compilation tools
- `dkms` - Dynamic kernel module support
- `pve-headers` - Proxmox kernel headers
- `cuda-toolkit` - NVIDIA CUDA toolkit (includes drivers)
- `nvidia-settings` - NVIDIA configuration utilities
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

After running this role, configure your LXC container by adding these lines to `/etc/pve/lxc/<CONTAINER_ID>.conf`:

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

# Test with Docker (if using containerized workloads)
docker run --gpus all nvidia/cuda:11.0-base nvidia-smi
```

## Installation Method

This role follows the official NVIDIA network repository installation method:

1. **Download CUDA Keyring**: Uses `wget` to download the official CUDA keyring package
2. **Install Keyring**: Installs keyring with `dpkg -i` to set up the repository
3. **Update Repository**: Updates APT cache to access NVIDIA packages
4. **Install CUDA Toolkit**: Installs `cuda-toolkit` which includes compatible drivers
5. **Configure LXC Support**: Sets up device nodes and passthrough configuration
6. **Verify Installation**: Tests driver and CUDA functionality

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
3. Check repository: `apt-cache policy cuda-toolkit`

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

For optimal GPU performance:

1. **Enable GPU persistence**: Reduces initialization time
2. **Use latest drivers**: Repository provides most recent stable versions
3. **Configure power limits**: Prevents thermal throttling if needed
4. **Monitor GPU utilization**: Use `nvidia-smi` to verify usage

## Version Compatibility

| Component | Version | Notes |
|-----------|---------|-------|
| NVIDIA Driver | Latest from repo | Automatically selected by CUDA toolkit |
| CUDA Toolkit | Latest from repo | Compatible with current drivers |
| Proxmox VE | 7.0+ | Tested on current versions |
| Debian | 11, 12 | Supports multiple Debian versions |

## Contributing

When modifying this role:

1. Test on a development Proxmox environment first
2. Verify LXC container functionality is not broken
3. Update documentation for any new variables or features
4. Test with actual GPU workloads to ensure performance

## License

This role is provided as-is for educational and operational use.