#!/bin/bash
set -e

# Test script for Proxmox backup automation workflow
# This script helps verify the backup automation setup

FRACTAL_IP="192.168.1.86"
FRACTAL_MAC="a8:a1:59:0c:6a:ae"
CHECK_PORT=445
BACKUP_MOUNT="/mnt/pve/backup_cluster"
LOCK_DIR="$BACKUP_MOUNT/.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if running on eagle or proxmox
    local hostname=$(hostname)
    if [[ "$hostname" != "eagle" && "$hostname" != "proxmox" ]]; then
        log_error "This script should be run on eagle or proxmox nodes only"
        return 1
    fi
    
    # Check required commands
    local missing_commands=()
    for cmd in etherwake nc ssh rsync; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_commands+=("$cmd")
        fi
    done
    
    if [ ${#missing_commands[@]} -gt 0 ]; then
        log_error "Missing required commands: ${missing_commands[*]}"
        return 1
    fi
    
    log_success "Prerequisites check passed"
    return 0
}

test_network_interface() {
    log_info "Testing network interface detection..."
    
    local interface=$(ip route show default | awk '/default/ { print $5 }' | head -1)
    if [ -z "$interface" ]; then
        log_error "Could not detect default network interface"
        return 1
    fi
    
    log_info "Detected interface: $interface"
    
    if command -v ethtool >/dev/null 2>&1; then
        log_info "Checking WOL capability..."
        local wol_info=$(ethtool "$interface" | grep -i "wake-on" || echo "WOL info not available")
        log_info "WOL status: $wol_info"
    else
        log_warning "ethtool not available - cannot verify WOL capability"
    fi
    
    log_success "Network interface test completed"
    return 0
}

test_fractal_connectivity() {
    log_info "Testing fractal connectivity..."
    
    if nc -z -w 5 "$FRACTAL_IP" "$CHECK_PORT" 2>/dev/null; then
        log_success "fractal is reachable at $FRACTAL_IP:$CHECK_PORT"
        return 0
    else
        log_warning "fractal is not currently reachable at $FRACTAL_IP:$CHECK_PORT"
        return 1
    fi
}

test_wake_on_lan() {
    log_info "Testing Wake-on-LAN functionality..."
    
    if test_fractal_connectivity; then
        log_info "fractal is already online - skipping WOL test"
        return 0
    fi
    
    log_info "fractal appears to be offline - testing WOL..."
    
    local interface=$(ip route show default | awk '/default/ { print $5 }' | head -1)
    log_info "Sending WOL packet to $FRACTAL_MAC via $interface"
    
    if /usr/sbin/etherwake -i "$interface" "$FRACTAL_MAC"; then
        log_info "WOL packet sent successfully to fractal"
        
        log_info "Waiting for fractal to respond (up to 60 seconds)..."
        local count=0
        while [ $count -lt 12 ]; do
            sleep 5
            count=$((count + 1))
            if nc -z -w 2 "$FRACTAL_IP" "$CHECK_PORT" 2>/dev/null; then
                log_success "fractal responded after $((count * 5)) seconds"
                return 0
            fi
            echo -n "."
        done
        echo
        log_warning "fractal did not respond within 60 seconds"
        return 1
    else
        log_error "Failed to send WOL packet to fractal"
        return 1
    fi
}

test_backup_storage() {
    log_info "Testing backup storage..."
    
    if [ ! -d "$BACKUP_MOUNT" ]; then
        log_error "Backup mount point $BACKUP_MOUNT does not exist"
        return 1
    fi
    
    if ! mountpoint -q "$BACKUP_MOUNT" 2>/dev/null; then
        log_warning "Backup storage is not mounted at $BACKUP_MOUNT"
        log_info "Attempting to mount..."
        if mount "$BACKUP_MOUNT" 2>/dev/null; then
            log_success "Backup storage mounted successfully"
        else
            log_error "Failed to mount backup storage"
            return 1
        fi
    else
        log_success "Backup storage is mounted at $BACKUP_MOUNT"
    fi
    
    # Test write access
    local test_file="$BACKUP_MOUNT/.test-$(date +%s)"
    if echo "test" > "$test_file" 2>/dev/null; then
        rm -f "$test_file"
        log_success "Backup storage is writable"
    else
        log_error "Backup storage is not writable"
        return 1
    fi
    
    # Check lock directory
    if [ ! -d "$LOCK_DIR" ]; then
        log_info "Creating lock directory: $LOCK_DIR"
        mkdir -p "$LOCK_DIR" || {
            log_error "Failed to create lock directory"
            return 1
        }
    fi
    log_success "Lock directory is available: $LOCK_DIR"
    
    return 0
}

test_scripts_installation() {
    log_info "Testing script installation..."
    
    local scripts=(
        "/usr/local/bin/pve-backup-hook.sh"
        "/usr/local/bin/fractal-wakeup.sh"
    )
    
    # Check for node-specific file backup script if backup paths are configured
    local node_backup_script="/usr/local/bin/$(hostname)-file-backup.sh"
    if [ -f "$node_backup_script" ]; then
        scripts+=("$node_backup_script")
    fi
    
    local missing_scripts=()
    for script in "${scripts[@]}"; do
        if [ ! -f "$script" ]; then
            missing_scripts+=("$script")
        elif [ ! -x "$script" ]; then
            log_warning "$script exists but is not executable"
            missing_scripts+=("$script")
        fi
    done
    
    if [ ${#missing_scripts[@]} -gt 0 ]; then
        log_error "Missing or non-executable scripts: ${missing_scripts[*]}"
        return 1
    fi
    
    log_success "All required scripts are installed and executable"
    return 0
}

test_cron_jobs() {
    log_info "Testing cron job configuration..."
    
    local cron_output=$(crontab -l 2>/dev/null || echo "")
    
    if echo "$cron_output" | grep -q "fractal-wakeup"; then
        log_success "Fractal wake-up cron job is configured"
    else
        log_error "Fractal wake-up cron job is missing"
        return 1
    fi
    
    if [ "$(hostname)" = "eagle" ]; then
        if echo "$cron_output" | grep -q "eagle-file-backup"; then
            log_success "Eagle file backup cron job is configured"
        else
            log_error "Eagle file backup cron job is missing"
            return 1
        fi
    fi
    
    return 0
}

test_ssh_access() {
    log_info "Testing SSH access to fractal..."
    
    if ! test_fractal_connectivity; then
        log_warning "fractal is not reachable - skipping SSH test"
        return 1
    fi
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes root@"$FRACTAL_IP" "echo 'SSH test successful'" 2>/dev/null; then
        log_success "SSH access to fractal is working"
        return 0
    else
        log_error "SSH access to fractal failed - check SSH keys"
        return 1
    fi
}

run_full_test() {
    log_info "=== Starting Proxmox Backup Automation Test ==="
    log_info "Running on: $(hostname)"
    log_info "Date: $(date)"
    echo
    
    local tests=(
        "check_prerequisites"
        "test_scripts_installation"
        "test_network_interface"
        "test_backup_storage"
        "test_cron_jobs"
        "test_fractal_connectivity"
        "test_ssh_access"
    )
    
    local failed_tests=()
    
    for test in "${tests[@]}"; do
        echo
        if ! $test; then
            failed_tests+=("$test")
        fi
    done
    
    echo
    log_info "=== Test Summary ==="
    
    if [ ${#failed_tests[@]} -eq 0 ]; then
        log_success "All tests passed! Backup automation should work correctly."
    else
        log_error "Failed tests: ${failed_tests[*]}"
        log_error "Please fix the issues before running backup automation."
        return 1
    fi
    
    echo
    log_info "Next steps:"
    log_info "1. Configure Proxmox backup jobs in the web interface"
    log_info "2. Set backup storage to: $BACKUP_MOUNT"
    log_info "3. Monitor logs: /var/log/fractal-wakeup.log and /var/log/eagle-backup.log"
    log_info "4. Test manual backup execution"
    
    return 0
}

# Main execution
case "${1:-full}" in
    "full")
        run_full_test
        ;;
    "wol")
        test_wake_on_lan
        ;;
    "storage")
        test_backup_storage
        ;;
    "connectivity")
        test_fractal_connectivity
        ;;
    "ssh")
        test_ssh_access
        ;;
    *)
        echo "Usage: $0 [full|wol|storage|connectivity|ssh]"
        echo "  full         - Run all tests (default)"
        echo "  wol          - Test wake-on-LAN only"
        echo "  storage      - Test backup storage only"
        echo "  connectivity - Test fractal connectivity only"
        echo "  ssh          - Test SSH access to fractal only"
        exit 1
        ;;
esac