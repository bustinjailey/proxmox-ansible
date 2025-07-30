# NUT UPS Role - Simplified Configuration

## Overview

This role configures Network UPS Tools (NUT) with a simplified architecture that reduces task skipping and ensures reliable service management across all hosts.

## Architecture

### Server Configuration (Eagle)
- **Role**: UPS Server + Monitor
- **Services**: `nut-server` + `nut-monitor`
- **Configuration**: 
  - `ups_connected: true` in inventory
  - MODE=netserver in nut.conf
  - Monitors UPS directly via localhost
  - Serves UPS data to clients

### Client Configuration (Dell, Fractal, Proxmox)
- **Role**: UPS Monitor Client
- **Services**: `nut-monitor` only
- **Configuration**:
  - No `ups_connected` variable needed
  - MODE=netclient in nut.conf
  - Monitors UPS via eagle server
  - Receives shutdown signals from server

## Key Improvements

### 1. Unified Handler Logic
- Single `restart nut` handler that works for both server and client roles
- Dynamically determines which services to restart based on host role
- No more skipped handler executions

### 2. Simplified Service Management
- All hosts run `nut-monitor` service (no skipping)
- Only server (eagle) additionally runs `nut-server`
- Removed complex fallback logic and service detection

### 3. Reduced Task Skipping
- Configuration tasks run on all appropriate hosts
- Service startup is guaranteed on all hosts
- Clear separation between server-only and universal tasks

## Configuration Variables

### Required Variables
- `nut_server`: Hostname of the UPS server (set to eagle.bustinjailey.org)
- `nut_ups_name`: Name of the UPS device (set to apc2200)
- `nut_upsmon_password`: Password for UPS monitoring

### Host-Specific Variables
- `ups_connected: true`: Set only on the UPS server host (eagle)

## Service Behavior

### Before Changes
```
Eagle:   nut-server + nut-monitor (OK)
Dell:    Many tasks skipped, unreliable service startup
Fractal: Many tasks skipped, unreliable service startup  
Proxmox: Many tasks skipped, unreliable service startup
```

### After Changes
```
Eagle:   nut-server + nut-monitor (Server role)
Dell:    nut-monitor (Client role)
Fractal: nut-monitor (Client role)
Proxmox: nut-monitor (Client role)
```

## Files Modified

1. **`tasks/main.yml`**: Simplified service management logic
2. **`handlers/main.yml`**: Unified restart handler for all host types

## Testing

To verify the configuration works correctly:

1. Run the playbook: `ansible-playbook playbooks/site.yml`
2. Check for reduced "skipping" messages in output
3. Verify services are running:
   - Eagle: `systemctl status nut-server nut-monitor`
   - Others: `systemctl status nut-monitor`

## Benefits

- **Fewer Skipped Tasks**: All hosts execute appropriate configuration tasks
- **Reliable Service Management**: All hosts properly start and manage NUT services
- **Clearer Logic**: Server vs client behavior is explicit and predictable
- **Easier Troubleshooting**: Reduced conditional complexity makes debugging simpler
- **Consistent Behavior**: All client hosts behave identically