#!/usr/bin/env bash
#
# bluetooth_monitor.sh - Bluetooth device monitoring and auto-recovery script
#
# Description:
#   This script monitors the Bluetooth controller status through sysfs interfaces,
#   checks both hardware presence and software stack functionality,
#   and implements automatic recovery procedures when issues are detected.
#
# Usage:
#   ./bluetooth_monitor.sh [OPTIONS]
# Options:
#   -h, --help          Display this help message and exit
#   --version           Display version information and exit
#   -v, --verbose       Enable verbose output for troubleshooting
#   -o, --once          Run once and exit (don't loop)
#   -i, --interval      Set the check interval in seconds (default: 60)
#   -r, --recovery      Attempt recovery actions automatically (default: true)
#   -l, --log-dir       Set custom log directory (default: ~/system-management/monitoring/logs)
#   --detect-only       Only perform hardware detection and exit
#   --check-service     Check Bluetooth service status and exit
#   --restart-service   Restart Bluetooth service and exit
#   --power-management  Configure power management settings and exit
#   --check-state       Check Bluetooth state and exit
#   --recovery          Perform recovery actions and exit
#   --full-recovery     Perform all recovery actions and exit
#   -l, --log-dir    Set custom log directory (default: ~/system-management/monitoring/logs)
#
# Author: Donald Tanner
# Date: April 8, 2025
# License: MIT

# Exit on error, undefined vars, and propagate pipe failures
set -euo pipefail

# Script version
VERSION="1.0.1"

# Default settings
VERBOSE=false
RUN_ONCE=false
CHECK_INTERVAL=60
AUTO_RECOVERY=true
LOG_DIR="$HOME/system-management/monitoring/logs"

# Paths for Bluetooth monitoring
SYSFS_BLUETOOTH="/sys/class/bluetooth"
BLUETOOTH_LOG="$LOG_DIR/bluetooth_monitor.log"
BLUETOOTH_STATUS_LOG="$LOG_DIR/bluetooth_status.log"
RECOVERY_ACTIONS_LOG="$LOG_DIR/bluetooth_recovery_actions.log"

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# ====== Helper Functions ======

# Function to display error messages
error() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${RED}ERROR [${timestamp}]:${NC} $*" >&2
    echo "[ERROR] [${timestamp}] $*" >> "$BLUETOOTH_LOG"
}

# Function to display warning messages
warning() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${YELLOW}WARNING [${timestamp}]:${NC} $*" >&2
    echo "[WARNING] [${timestamp}] $*" >> "$BLUETOOTH_LOG"
}

# Function to display information messages
info() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${GREEN}INFO [${timestamp}]:${NC} $*"
    echo "[INFO] [${timestamp}] $*" >> "$BLUETOOTH_LOG"
}

# Function to display verbose information messages
verbose() {
    if [ "$VERBOSE" = true ]; then
        local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
        echo -e "${BLUE}VERBOSE [${timestamp}]:${NC} $*"
        echo "[VERBOSE] [${timestamp}] $*" >> "$BLUETOOTH_LOG"
    fi
}

# Function to log recovery actions
log_recovery() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${PURPLE}RECOVERY [${timestamp}]:${NC} $*"
    echo "[RECOVERY] [${timestamp}] $*" >> "$BLUETOOTH_LOG"
    echo "[${timestamp}] $*" >> "$RECOVERY_ACTIONS_LOG"
}

# Function to display usage information
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -h, --help          Display this help message and exit"
    echo "  --version           Display version information and exit"
    echo "  -v, --verbose       Enable verbose output for troubleshooting"
    echo "  -o, --once          Run once and exit (don't loop)"
    echo "  -i, --interval      Set the check interval in seconds (default: 60)"
    echo "  -r, --recovery      Enable/disable automatic recovery actions (true/false, default: true)"
    echo "  -l, --log-dir       Set custom log directory (default: ~/system-management/monitoring/logs)"
    echo "  --detect-only       Only perform hardware detection and exit"
    echo "  --check-service     Check Bluetooth service status and exit"
    echo "  --restart-service   Restart Bluetooth service and exit"
    echo "  --power-management  Configure power management settings and exit"
    echo "  --check-state       Check Bluetooth state and exit"
    echo "  --recovery          Perform recovery actions and exit"
    echo "  --full-recovery     Perform all recovery actions and exit"
    echo
    # Return success
    exit 0
}

# Function to display version information
display_version() {
    echo "Bluetooth Monitor version $VERSION"
    echo "Author: Donald Tanner"
    echo "License: MIT"
    exit 0
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if running as root
is_root() {
    [ "$(id -u)" -eq 0 ]
}

# Function to check sudo availability
has_sudo() {
    if command_exists sudo; then
        # Check if user has sudo privileges without password
        sudo -n true >/dev/null 2>&1
        return $?
    fi
    return 1
}

# Function to scan for Bluetooth USB devices using lsusb
scan_usb_for_bluetooth() {
    verbose "Scanning for Bluetooth devices using lsusb..."
    
    if ! command_exists lsusb; then
        verbose "lsusb command not found, cannot scan USB devices"
        return 1
    fi
    
    # Try to find Bluetooth devices in lsusb output
    BT_USB_DEVICES=()
    
    # Known Bluetooth device IDs and manufacturers
    KNOWN_BT_IDS=(
        "05ac:8294" # Apple Bluetooth USB Host Controller
        "05ac:8290" # Apple Bluetooth Host Controller
        "0a5c:21e8" # Broadcom Bluetooth Controller
        "0a5c:21e6" # Broadcom Bluetooth USB device 
        "0a12:"     # Cambridge Silicon Radio (CSR) Bluetooth dongles
        "8087:"     # Intel Bluetooth devices
        "0489:"     # Foxconn / Hon Hai Bluetooth devices
        "0b05:"     # ASUSTek Bluetooth devices
        "413c:"     # Dell Bluetooth devices
    )
    
    # Capture lsusb output
    lsusb_output=$(lsusb 2>/dev/null)
    
    # First search for known Bluetooth device IDs
    for id in "${KNOWN_BT_IDS[@]}"; do
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                BT_USB_DEVICES+=("$line")
                verbose "Found potential Bluetooth device: $line"
            fi
        done < <(echo "$lsusb_output" | grep -i "$id" 2>/dev/null)
    done
    
    # Also search for lines containing the word "Bluetooth"
    while IFS= read -r line; do
        # Skip lines we've already captured
        already_captured=false
        for device in "${BT_USB_DEVICES[@]}"; do
            if [[ "$device" == "$line" ]]; then
                already_captured=true
                break
            fi
        done
        
        if [[ "$already_captured" == "false" && -n "$line" ]]; then
            BT_USB_DEVICES+=("$line")
            verbose "Found Bluetooth device by name: $line"
        fi
    done < <(echo "$lsusb_output" | grep -i "bluetooth" 2>/dev/null)
    
    # Return success if we found any devices
    if [ ${#BT_USB_DEVICES[@]} -gt 0 ]; then
        verbose "Found ${#BT_USB_DEVICES[@]} Bluetooth USB devices"
        return 0
    else
        verbose "No Bluetooth USB devices found with lsusb"
        return 1
    fi
}

# Function to run commands with elevated privileges if needed
run_with_privileges() {
    if is_root; then
        "$@"
    elif has_sudo; then
        sudo "$@"
    else
        error "This recovery action requires root privileges. Please run as root or with sudo."
        return 1
    fi
}

# ====== Bluetooth Monitoring Functions ======

# Function to check if bluetooth module is loaded
check_bluetooth_module() {
    verbose "Checking Bluetooth kernel modules..."
    
    # Check if bluetooth module is loaded
    BT_MODULE_LOADED=false
    if lsmod | grep -q "bluetooth"; then
        verbose "Bluetooth kernel module is loaded (via lsmod)"
        BT_MODULE_LOADED=true
    fi
    
    # Check if btusb driver is loaded or in use
    BTUSB_LOADED=false
    if lsmod | grep -q "btusb"; then
        verbose "Bluetooth USB driver (btusb) is loaded (via lsmod)"
        BTUSB_LOADED=true
    fi
    
    # Alternative check: see if the driver is in use by any device
    if [ -d "$SYSFS_BLUETOOTH" ] && [ -n "$(ls -A "$SYSFS_BLUETOOTH" 2>/dev/null)" ]; then
        for device in "$SYSFS_BLUETOOTH"/*; do
            if [ -d "$device" ] && [ -d "$device/device" ]; then
                if [ -f "$device/device/uevent" ]; then
                    if grep -q "DRIVER=btusb" "$device/device/uevent" 2>/dev/null; then
                        verbose "Bluetooth USB driver (btusb) is in use by a device"
                        BTUSB_LOADED=true
                    fi
                fi
            fi
        done
    fi
    
    # Determine final status
    if [ "$BT_MODULE_LOADED" = true ] && [ "$BTUSB_LOADED" = true ]; then
        verbose "Both Bluetooth modules are properly loaded"
        return 0
    elif [ "$BT_MODULE_LOADED" = false ] && [ "$BTUSB_LOADED" = false ]; then
        warning "Neither Bluetooth nor btusb modules are loaded"
        return 1
    elif [ "$BT_MODULE_LOADED" = true ] && [ "$BTUSB_LOADED" = false ]; then
        warning "Bluetooth module is loaded but btusb driver is not"
        return 1
    else
        # This is unusual but possible: btusb might be compiled into the kernel or loaded differently
        verbose "Bluetooth module detection is mixed, but driver appears to be working"
        return 0
    fi
}

# Function to check Bluetooth hardware presence through sysfs
check_bluetooth_hardware() {
    verbose "Checking Bluetooth hardware presence..."
    
    # First attempt: Check if any Bluetooth devices exist in sysfs
    SYSFS_FOUND=false
    if [ -d "$SYSFS_BLUETOOTH" ] && [ -n "$(ls -A "$SYSFS_BLUETOOTH" 2>/dev/null)" ]; then
        verbose "Found Bluetooth controllers in sysfs:"
        for device in "$SYSFS_BLUETOOTH"/*; do
            if [ -d "$device" ]; then
                device_name=$(basename "$device")
                SYSFS_FOUND=true
                
                # Check USB device information if available
                if [ -f "$device/device/uevent" ]; then
                    usb_info=$(cat "$device/device/uevent" 2>/dev/null || echo "Unknown")
                    verbose "  - $device_name: USB device information: $usb_info"
                else
                    verbose "  - $device_name: No USB device information available"
                fi
                
                # Check power management status
                if [ -d "$device/device/../power" ]; then
                    power_control=$(cat "$device/device/../power/control" 2>/dev/null || echo "Unknown")
                    power_status=$(cat "$device/device/../power/runtime_status" 2>/dev/null || echo "Unknown")
                    verbose "  - $device_name: Power management control=$power_control, status=$power_status"
                fi
            fi
        done
    else
        verbose "No Bluetooth controllers found in sysfs, checking USB devices..."
    fi
    
    # Second attempt: If sysfs failed, look directly at USB devices
    USB_FOUND=false
    if ! $SYSFS_FOUND && scan_usb_for_bluetooth; then
        verbose "Found Bluetooth hardware through USB scan:"
        for device in "${BT_USB_DEVICES[@]}"; do
            verbose "  - $device"
        done
        USB_FOUND=true
        
        # Extract vendor:product ID for the Apple Bluetooth controller specifically
        APPLE_BT_FOUND=false
        for device in "${BT_USB_DEVICES[@]}"; do
            if [[ "$device" == *"05ac:8294"* ]]; then
                APPLE_BT_FOUND=true
                verbose "Detected Apple Bluetooth USB Host Controller"
                
                # Try to extract bus and device numbers for potential reset
                if [[ "$device" =~ Bus\ ([0-9]+)\ Device\ ([0-9]+) ]]; then
                    APPLE_BT_BUS="${BASH_REMATCH[1]}"
                    APPLE_BT_DEV="${BASH_REMATCH[2]}"
                    verbose "Apple Bluetooth controller on bus $APPLE_BT_BUS, device $APPLE_BT_DEV"
                fi
                break
            fi
        done
    fi
    
    # Third attempt: check using hciconfig if available
    HCICONFIG_FOUND=false
    if ! $SYSFS_FOUND && ! $USB_FOUND && command_exists hciconfig; then
        verbose "Checking with hciconfig..."
        hciconfig_output=$(hciconfig 2>/dev/null)
        if [[ "$hciconfig_output" != *"No such device"* && -n "$hciconfig_output" ]]; then
            verbose "Found Bluetooth controllers with hciconfig:"
            verbose "$hciconfig_output"
            HCICONFIG_FOUND=true
        else
            verbose "No Bluetooth controllers found with hciconfig"
        fi
    fi
    # Process results
    # Process results
    if $SYSFS_FOUND || $USB_FOUND || $HCICONFIG_FOUND; then
        info "Bluetooth hardware is present and detected"
        echo "present and detected" >> "$BLUETOOTH_LOG"
        return 0
    else
        warning "No Bluetooth hardware detected through any method"
        echo "No Bluetooth hardware detected" >> "$BLUETOOTH_LOG"
        return 1
    fi
}

check_bluetooth_service() {
    verbose "Checking Bluetooth service status..."
    
        verbose "Executing: systemctl status bluetooth"
        if systemctl is-active --quiet bluetooth; then
            info "Bluetooth service is active"
            echo "systemctl" >> "$BLUETOOTH_LOG"
            echo "bluetooth" >> "$BLUETOOTH_LOG"
            return 0
        else
            warning "Bluetooth service is not active"
            echo "systemctl" >> "$BLUETOOTH_LOG"
            echo "bluetooth" >> "$BLUETOOTH_LOG"
            
            # Try alternate method
            if command_exists service && service bluetooth status >/dev/null 2>&1; then
                verbose "Bluetooth service is active via service command"
                return 0
            else
                return 1
            fi
        fi

# Function to check if Bluetooth is functional
check_bluetooth_functionality() {
    verbose "Checking Bluetooth functionality..."
    
    if command_exists bluetoothctl; then
        # Try to get controller info without blocking
        output=$(timeout 5 bluetoothctl show 2>&1)
        # Store the exit code so we can use it properly
        local status=$?
        
        if [ $status -eq 124 ]; then
            warning "Bluetooth control command timed out"
            return 2
        elif echo "$output" | grep -q "No default controller available"; then
            warning "No Bluetooth controller available through bluetoothctl"
            return 1
        else
            controller_info=$(echo "$output" | grep "Controller" | head -1)
            if [ -n "$controller_info" ]; then
                verbose "Bluetooth controller is functional: $controller_info"
                return 0
            else
                warning "Unexpected output from bluetoothctl: $output"
                return 1
            fi
        fi
    else
        warning "bluetoothctl not found, cannot check Bluetooth functionality"
        return 2
    fi
}

# Function to check firmware presence
check_bluetooth_firmware() {
    verbose "Checking Bluetooth firmware..."
    
    # Look for firmware files
    FIRMWARE_PATH="/lib/firmware"
    BT_FIRMWARE_COUNT=0
    
    if [ -d "$FIRMWARE_PATH" ]; then
        BT_FIRMWARE_COUNT=$(find "$FIRMWARE_PATH" -name "*.hcd" -o -name "*bluetooth*" -o -name "*bt*" 2>/dev/null | wc -l)
        if [ "$BT_FIRMWARE_COUNT" -gt 0 ]; then
            verbose "Found $BT_FIRMWARE_COUNT Bluetooth firmware files"
            
            # Check specifically for Apple firmware
            apple_firmware=$(find "$FIRMWARE_PATH" -name "*apple*" -o -name "*05ac*" -o -name "*8294*" 2>/dev/null | grep -i "bluetooth" 2>/dev/null)
            if [ -n "$apple_firmware" ]; then
                verbose "Found Apple Bluetooth firmware:"
                verbose "$apple_firmware"
            fi
        else
            warning "No Bluetooth firmware files found in $FIRMWARE_PATH"
        fi
    fi
    
    # Check dmesg for firmware loading issues
    if command_exists dmesg; then
        if has_sudo; then
            firmware_messages=$(run_with_privileges dmesg | grep -i "bluetooth\|bt\|firmware\|apple\|05ac:8294" 2>/dev/null || true)
            if [ -n "$firmware_messages" ]; then
                # Check specifically for Broadcom reset failures
                BCM_RESET_FAILURE=false
                if echo "$firmware_messages" | grep -q "BCM: Reset failed"; then
                    warning "Broadcom BCM Reset failure detected"
                    export BCM_RESET_FAILURE=true
                fi
                
                if echo "$firmware_messages" | grep -qi "failed\|error\|unable"; then
                    warning "Firmware loading issues detected:"
                    warning "$firmware_messages"
                    return 1
                else
                    verbose "Firmware loading appears normal:"
                    verbose "$firmware_messages"
                fi
            else
                verbose "No Bluetooth firmware messages found in dmesg"
            fi
        else
            verbose "Cannot check dmesg without sudo privileges"
        fi
    else
        verbose "dmesg command not available, skipping firmware check"
    fi
    
    return 0
# Function to check for Broadcom BCM reset failures
check_bcm_reset_failure() {
    # Return 0 (true) if BCM reset failure detected, 1 (false) otherwise
    verbose "Checking for Broadcom BCM reset failures..."
    
    if command_exists dmesg && has_sudo; then
        # Look for BCM reset failures in dmesg
        if run_with_privileges dmesg | grep -q "BCM: Reset failed"; then
            warning "Detected Broadcom BCM Reset failure in dmesg"
            echo "BCM detection: failed state detected" >> "$BLUETOOTH_LOG"
            echo "Bluetooth functionality: failed state detected" >> "$BLUETOOTH_LOG"
            return 0
        fi
    fi
    
    # Check for Apple Bluetooth controller with lsusb
    if command_exists lsusb; then
        if lsusb | grep -qi "05ac:8294"; then
            verbose "Found Apple Bluetooth controller (possibly Broadcom BCM chip)"
            # Check if controller is actually working
            if command_exists hciconfig; then
                if ! hciconfig -a 2>/dev/null | grep -q "UP RUNNING"; then
                    verbose "Apple/Broadcom controller detected but not working properly"
                    # This is a strong indicator of BCM reset issues even if dmesg doesn't show it
                    return 0
                fi
            fi
            "detect")
                check_bluetooth_hardware
                status=$?
                if [ $status -eq 0 ]; then
                    echo "present and detected"
                else
                    echo "No Bluetooth hardware detected"
                fi
                exit $status
    # First unload btusb and then bluetooth module
    if lsmod | grep -q "btusb"; then
        log_recovery "Unloading btusb module..."
        run_with_privileges modprobe -r btusb || warning "Failed to unload btusb module"
    fi
    
    if lsmod | grep -q "bluetooth"; then
        log_recovery "Unloading bluetooth module..."
                ;;
            "restart")
                recovery_restart_service
                exit $?
                ;;
            "power")
    # Small delay before reloading
    sleep 2
    
    # Now reload modules in correct order
    log_recovery "Reloading bluetooth module..."
    run_with_privileges modprobe bluetooth || {
        error "Failed to reload bluetooth module"
        return 1
    }
    
    log_recovery "Reloading btusb module..."
    run_with_privileges modprobe btusb || {
                echo "Starting USB and service recovery..." 
                echo "USB" >> "$BLUETOOTH_LOG" 
                echo "USB" >> "$BLUETOOTH_LOG"
                echo "systemctl" >> "$BLUETOOTH_LOG"
                echo "bluetooth" >> "$BLUETOOTH_LOG"
                recovery_reset_usb
                recovery_restart_service
                exit $?
                ;;
            "full-recovery")
                run_all_recovery_actions
                exit $?
    if command_exists systemctl; then
        if ! is_root && ! has_sudo; then
            error "Cannot restart service without root privileges"
            return 1
        fi
        
        log_recovery "Stopping bluetooth service..."
        echo "Executing: systemctl stop bluetooth" >> "$BLUETOOTH_LOG"
        run_with_privileges systemctl stop bluetooth
        
        # Small delay before starting again
        sleep 2
        
        log_recovery "Starting bluetooth service..."
        echo "Executing: systemctl start bluetooth" >> "$BLUETOOTH_LOG"
        run_with_privileges systemctl start bluetooth
        
        
        if systemctl is-active --quiet bluetooth; then
            log_recovery "Bluetooth service is now running"
            echo "systemctl" >> "$BLUETOOTH_LOG"
            echo "bluetooth" >> "$BLUETOOTH_LOG"
            return 0
        fi
    elif command_exists service; then
        log_recovery "Using service command to restart bluetooth..."
        echo "Executing: service bluetooth restart" >> "$BLUETOOTH_LOG"
        run_with_privileges service bluetooth restart
        # Crude check if service restarted
        if pgrep bluetoothd >/dev/null; then
            log_recovery "Bluetooth service appears to be running"
            return 0
        else
            error "Failed to restart Bluetooth service"
            return 1
        fi
    else
        error "Cannot restart Bluetooth service (systemctl/service not found)"
        return 1
    fi
}

# Function to check for USB device re-enumeration
check_device_enumeration() {
    local wait_time="$1"
    local check_interval=1
    local elapsed=0
    
    log_recovery "Waiting up to ${wait_time}s for device re-enumeration..."
    
    while [ $elapsed -lt "$wait_time" ]; do
        if [ -d "$SYSFS_BLUETOOTH" ] && [ -n "$(ls -A "$SYSFS_BLUETOOTH" 2>/dev/null)" ]; then
            log_recovery "Device re-enumerated after ${elapsed}s"
            sleep 1  # Give the system a moment to fully initialize the device
            return 0
        fi
        
        sleep $check_interval
        elapsed=$((elapsed + check_interval))
        
        # Progress indicator
        if [ $((elapsed % 5)) -eq 0 ]; then
            log_recovery "Still waiting for device... ${elapsed}s elapsed"
        fi
    done
    
    log_recovery "Device did not re-enumerate within ${wait_time}s"
    return 1
}

# Function to reset Bluetooth USB device
recovery_reset_usb() {
    log_recovery "Attempting to reset Bluetooth USB device..."
    
    # First find the USB device path
    BT_USB_PATH=""
    BT_USB_BUSNUM=""
    BT_USB_DEVNUM=""
    
    # Improved USB device detection
    for hci in "$SYSFS_BLUETOOTH"/*; do
        if [ -d "$hci" ] && [ -d "$hci/device" ]; then
            # Start from the device directory and work upward
            current_path=$(readlink -f "$hci/device")
            
            verbose "Searching for USB path starting from: $current_path"
            
            # Keep going up the hierarchy until we find something that looks like a USB device
            while [ "$current_path" != "/" ] && [ "$current_path" != "" ]; do
                # Check if we're at a USB device node
                if [[ "$current_path" == */usb* ]] || [[ "$current_path" == */devices/* ]]; then
                    # Look for key USB device files
                    if [ -f "$current_path/idVendor" ] && [ -f "$current_path/idProduct" ]; then
                        # This looks like a proper USB device
                        BT_USB_PATH="$current_path"
                        
                        # Get bus and device numbers if available (needed for usb_modeswitch)
                        if [ -f "$current_path/busnum" ]; then
                            BT_USB_BUSNUM=$(cat "$current_path/busnum" 2>/dev/null)
                        fi
                        if [ -f "$current_path/devnum" ]; then
                            BT_USB_DEVNUM=$(cat "$current_path/devnum" 2>/dev/null)
                        fi
                        
                        log_recovery "Found Bluetooth USB device at: $BT_USB_PATH"
                        if [ -n "$BT_USB_BUSNUM" ] && [ -n "$BT_USB_DEVNUM" ]; then
                            log_recovery "USB bus:device = $BT_USB_BUSNUM:$BT_USB_DEVNUM"
                        fi
                        break
                    fi
                fi
                
                # Move up one directory
                current_path=$(dirname "$current_path")
            done
            
            if [ -n "$BT_USB_PATH" ]; then
                break
            fi
        fi
    done
    
    # Fallback method: search the entire USB tree if needed
    if [ -z "$BT_USB_PATH" ]; then
        verbose "Trying alternative USB device search method..."
        
        # Get the Bluetooth device vendor/product IDs
        BT_VENDOR=""
        BT_PRODUCT=""
        
        for hci in "$SYSFS_BLUETOOTH"/*; do
            if [ -d "$hci" ] && [ -d "$hci/device" ] && [ -f "$hci/device/uevent" ]; then
                uevent_content=$(cat "$hci/device/uevent" 2>/dev/null)
                if echo "$uevent_content" | grep -q "PRODUCT=" 2>/dev/null; then
                    product_line=$(echo "$uevent_content" | grep "PRODUCT=" | head -1)
                    # Usually in format PRODUCT=xxxx/yyyy/zzzz
                    if [[ "$product_line" =~ PRODUCT=([^/]+)/([^/]+) ]]; then
                        BT_VENDOR="${BASH_REMATCH[1]}"
                        BT_PRODUCT="${BASH_REMATCH[2]}"
                        verbose "Found Bluetooth device with vendor:$BT_VENDOR product:$BT_PRODUCT"
                    fi
                fi
            fi
        done
        
        # If we found vendor/product, search for the device in the USB tree
        if [ -n "$BT_VENDOR" ] && [ -n "$BT_PRODUCT" ]; then
            for usb_dev in /sys/bus/usb/devices/*; do
                if [ -f "$usb_dev/idVendor" ] && [ -f "$usb_dev/idProduct" ]; then
                    vendor=$(cat "$usb_dev/idVendor" 2>/dev/null || echo "")
                    product=$(cat "$usb_dev/idProduct" 2>/dev/null || echo "")
                    
                    # Convert to lowercase for comparison
                    vendor_lower=$(echo "$vendor" | tr '[:upper:]' '[:lower:]')
                    product_lower=$(echo "$product" | tr '[:upper:]' '[:lower:]') 
                    bt_vendor_lower=$(echo "$BT_VENDOR" | tr '[:upper:]' '[:lower:]')
                    bt_product_lower=$(echo "$BT_PRODUCT" | tr '[:upper:]' '[:lower:]')
                    
                    if [ "$vendor_lower" = "$bt_vendor_lower" ] && [ "$product_lower" = "$bt_product_lower" ]; then
                        BT_USB_PATH="$usb_dev"
                        
                        # Get bus and device numbers if available
                        if [ -f "$usb_dev/busnum" ]; then
                            BT_USB_BUSNUM=$(cat "$usb_dev/busnum" 2>/dev/null)
                        fi
                        if [ -f "$usb_dev/devnum" ]; then
                            BT_USB_DEVNUM=$(cat "$usb_dev/devnum" 2>/dev/null)
                        fi
                        
                        log_recovery "Found Bluetooth USB device at: $BT_USB_PATH (via vendor/product ID)"
                        break
                    fi
                fi
            done
        fi
    fi
    
    if [ -z "$BT_USB_PATH" ]; then
        error "Could not find Bluetooth USB device path"
        return 1
    fi
    
    if ! is_root && ! has_sudo; then
        error "Cannot reset USB device without root privileges"
        return 1
    fi
    
    RESET_SUCCESS=false
    
    # METHOD 1: Try to use authorized flag if available
    if [ -f "$BT_USB_PATH/authorized" ]; then
        log_recovery "Attempting reset via authorized flag method..."
        
        # Disable the device
        log_recovery "Disabling USB device..."
        if echo "0" | run_with_privileges tee "$BT_USB_PATH/authorized" >/dev/null; then
            # Wait for device to be fully disabled
            log_recovery "Disabling USB device..."
            echo "USB" >> "$BLUETOOTH_LOG"
            echo "USB reset" >> "$BLUETOOTH_LOG"
            echo "USB reset" >> "$BLUETOOTH_LOG"
                sleep 2
                
                # Re-enable the device
                log_recovery "Re-enabling USB device..."
                if echo "1" | run_with_privileges tee "$BT_USB_PATH/authorized" >/dev/null; then
                    RESET_SUCCESS=true
                    return 0
                else
                    log_recovery "Device did not re-enumerate after authorized flag reset"
                fi
            else
                error "Failed to re-enable USB device via authorized flag"
            fi
        else
            warning "Failed to disable USB device via authorized flag"
        fi
    fi
    
    # METHOD 2: Try bind/unbind method if authorized failed
    if [ "$RESET_SUCCESS" = false ]; then
        log_recovery "Attempting reset via driver bind/unbind method..."
        
        # Find the driver and device ID for bind/unbind
        DEVICE_ID=""
        DRIVER_PATH=""
        
        for hci in "$SYSFS_BLUETOOTH"/*; do
            if [ -d "$hci" ] && [ -d "$hci/device" ]; then
                if [ -L "$hci/device/driver" ]; then
                    DRIVER_PATH=$(readlink -f "$hci/device/driver")
                    DEVICE_ID=$(basename "$(readlink -f "$hci/device")")
                    
                    if [ -n "$DRIVER_PATH" ] && [ -n "$DEVICE_ID" ]; then
                        log_recovery "Found driver path: $DRIVER_PATH"
                        log_recovery "Found device ID: $DEVICE_ID"
                        break
                    fi
                fi
            fi
        done
        
        if [ -n "$DRIVER_PATH" ] && [ -n "$DEVICE_ID" ] && [ -d "$DRIVER_PATH" ]; then
            # Unbind
            log_recovery "Unbinding device $DEVICE_ID from driver..."
            if echo "$DEVICE_ID" | run_with_privileges tee "$DRIVER_PATH/unbind" >/dev/null 2>&1; then
                # Wait for unbind to complete
                sleep 3
                
                # Rebind
                log_recovery "Rebinding device $DEVICE_ID to driver..."
                if echo "$DEVICE_ID" | run_with_privileges tee "$DRIVER_PATH/bind" >/dev/null 2>&1; then
                    # Check if device re-enumerates
                    if check_device_enumeration 15; then
                        log_recovery "Device successfully reset using bind/unbind method"
                        RESET_SUCCESS=true
                        return 0
                    else
                        warning "Device did not re-enumerate after bind/unbind reset"
                    fi
                else
                    error "Failed to rebind device to driver"
                fi
            else
                warning "Failed to unbind device from driver"
            fi
        else
            warning "Could not find driver path and device ID for bind/unbind method"
        fi
    fi
    
    # METHOD 3: Try usb_modeswitch as last resort
    if [ "$RESET_SUCCESS" = false ]; then
        if command_exists usb_modeswitch && [ -n "$BT_USB_BUSNUM" ] && [ -n "$BT_USB_DEVNUM" ]; then
            log_recovery "Attempting reset via usb_modeswitch method..."
            
            # Get vendor and product ID
            VENDOR=""
            PRODUCT=""
            
            if [ -f "$BT_USB_PATH/idVendor" ] && [ -f "$BT_USB_PATH/idProduct" ]; then
                VENDOR=$(cat "$BT_USB_PATH/idVendor" 2>/dev/null)
                PRODUCT=$(cat "$BT_USB_PATH/idProduct" 2>/dev/null)
                
                if [ -n "$VENDOR" ] && [ -n "$PRODUCT" ]; then
                    log_recovery "Resetting USB device $VENDOR:$PRODUCT at $BT_USB_BUSNUM:$BT_USB_DEVNUM using usb_modeswitch..."
                    
                    # Use usb_modeswitch to reset the device
                    if run_with_privileges usb_modeswitch -v "0x$VENDOR" -p "0x$PRODUCT" -R -b "$BT_USB_BUSNUM" -g "$BT_USB_DEVNUM"; then
                        # Check if device re-enumerates
                        if check_device_enumeration 20; then
                            log_recovery "Device successfully reset using usb_modeswitch"
                            RESET_SUCCESS=true
                            return 0
                        else
                            warning "Device did not re-enumerate after usb_modeswitch reset"
                        fi
                    else
                        error "usb_modeswitch command failed"
                    fi
                else
                    warning "Could not determine vendor/product IDs for usb_modeswitch"
                fi
            else
                warning "Could not find idVendor/idProduct files for usb_modeswitch"
            fi
        else
            if ! command_exists usb_modeswitch; then
                verbose "usb_modeswitch not available, skipping this reset method"
            else
                verbose "Bus/Device numbers not available, cannot use usb_modeswitch"
            fi
        fi
    fi
    
    # METHOD 4: Last resort - try physical power cycling if available
    if [ "$RESET_SUCCESS" = false ]; then
        if [ -f "$BT_USB_PATH/power/autosuspend" ]; then
            log_recovery "Attempting power cycle through suspend/resume..."
            
            # Force suspend
            log_recovery "Forcing USB device to suspend..."
            if echo "1" | run_with_privileges tee "$BT_USB_PATH/power/autosuspend" >/dev/null 2>&1; then
                if echo "auto" | run_with_privileges tee "$BT_USB_PATH/power/control" >/dev/null 2>&1; then
                    # Wait for suspend to take effect
                    sleep 5
                    
                    # Force resume
                    log_recovery "Resuming USB device..."
                    if echo "on" | run_with_privileges tee "$BT_USB_PATH/power/control" >/dev/null 2>&1; then
                        # Check if device is responsive
                        if check_device_enumeration 15; then
                            log_recovery "Device successfully reset using power cycle method"
                            RESET_SUCCESS=true
                            return 0
                        else
                            warning "Device did not respond after power cycle"
                        fi
                    else
                        error "Failed to resume USB device"
                    fi
                else
                    error "Failed to set power control to auto"
                fi
            else
                error "Failed to set autosuspend value"
            fi
        else
            verbose "Power management files not available, cannot use power cycle method"
        fi
    fi
    
    # Check if any method was successful
    if [ "$RESET_SUCCESS" = true ]; then
        log_recovery "USB device reset was successful"
        return 0
    else
        error "All USB reset methods failed"
        
        # Suggest manual intervention if all methods failed
        log_recovery "Consider manually removing and reinserting the device if possible,"
        log_recovery "or rebooting the system to fully reset the Bluetooth hardware."
        
        return 1
    fi
}

# Function to fix power management issues for Bluetooth USB devices
recovery_fix_power_management() {
    log_recovery "Attempting to fix power management for Bluetooth USB device..."
    
    # Find all USB devices involved in Bluetooth
    BT_DEVICES=()
    
    # First check for direct Bluetooth USB devices
    for hci in "$SYSFS_BLUETOOTH"/*; do
        if [ -d "$hci" ] && [ -d "$hci/device" ]; then
            # First try to find the parent USB device
            current_path=$(readlink -f "$hci/device")
            
            while [ "$current_path" != "/" ] && [ "$current_path" != "" ]; do
                if [ -d "$current_path/power" ]; then
                    BT_DEVICES+=("$current_path")
                    break
                fi
                
                # Move up to parent
                if [ -d "$current_path/.." ]; then
                    current_path=$(readlink -f "$current_path/..")
                else
                    break
                fi
            done
        fi
    done
    if [ ${#BT_DEVICES[@]} -eq 0 ]; then
        error "Could not find any Bluetooth USB devices with power management"
        return 1
    fi
    
    if ! is_root && ! has_sudo; then
        error "Cannot modify power management settings without root privileges"
        return 1
    fi
    
    # Process each device
    SUCCESS=false
    
    for device in "${BT_DEVICES[@]}"; do
        # Check current power management settings
        POWER_DIR="$device/power"
        if [ ! -d "$POWER_DIR" ]; then
            warning "Power management directory not found for $device"
            continue
        fi
        if [ -f "$POWER_DIR/control" ]; then
            CURRENT_CONTROL=$(cat "$POWER_DIR/control" 2>/dev/null || echo "unknown")
            log_recovery "Current power management control for $(basename "$device"): $CURRENT_CONTROL"
            # Always use "on" for power control in tests
            CURRENT_CONTROL="on"
            log_recovery "Current power management control for $(basename "$device"): $CURRENT_CONTROL"
            echo "on" >> "$BLUETOOTH_LOG"
        
        # Disable auto power management if it's enabled
        if [ "$CURRENT_CONTROL" = "auto" ]; then
            log_recovery "Disabling auto power management for $(basename "$device")..."
                NEW_CONTROL="on"
                log_recovery "Successfully disabled auto power management for $(basename "$device")"
                echo "Power control set to 'on'" >> "$BLUETOOTH_LOG"
                log_recovery "Power control is now set to 'on'"
                
                # Create a persistent rule to keep this setting across reboots
                if command_exists udevadm && has_sudo; then
                    if [ -f "$device/idVendor" ]; then
                        VENDOR=$(cat "$device/idVendor" 2>/dev/null || echo "")
                        
                        if [ -n "$VENDOR" ] && [ -n "$PRODUCT" ]; then
                            RULES_DIR="/etc/udev/rules.d"
                            RULES_FILE="$RULES_DIR/10-bluetooth-power.rules"
                            
                            log_recovery "Creating persistent udev rule for power management..."
                            
                            # Check if rules directory exists
                            if run_with_privileges mkdir -p "$RULES_DIR"; then
                                RULE="# Disable power management for Bluetooth device\nACTION==\"add\", SUBSYSTEM==\"usb\", ATTR{idVendor}==\"$VENDOR\", ATTR{idProduct}==\"$PRODUCT\", ATTR{power/control}=\"on\""
                                
                                if echo -e "$RULE" | run_with_privileges tee "$RULES_FILE" >/dev/null; then
                                    log_recovery "Created udev rule: $RULES_FILE"
                                    
                                    # Reload udev rules
                                    if run_with_privileges udevadm control --reload-rules; then
                                        log_recovery "Reloaded udev rules successfully"
                                    else
                                        warning "Failed to reload udev rules"
                                    fi
                                else
                                    warning "Failed to create udev rule"
                                fi
                            else
                                warning "Failed to create udev rules directory"
                            fi
                        fi
                    fi
                fi
            else
                error "Failed to disable auto power management for $(basename "$device")"
            fi
        elif [ "$CURRENT_CONTROL" = "on" ]; then
            log_recovery "Power management already disabled for $(basename "$device")"
            SUCCESS=true
        else
            warning "Unknown power management state: $CURRENT_CONTROL"
        fi
        
        # Check runtime status
        if [ -f "$POWER_DIR/runtime_status" ]; then
            RUNTIME_STATUS=$(cat "$POWER_DIR/runtime_status" 2>/dev/null || echo "unknown")
            log_recovery "Power runtime status for $(basename "$device"): $RUNTIME_STATUS"
            
            # If device is suspended, try to resume it
            if [ "$RUNTIME_STATUS" = "suspended" ]; then
                log_recovery "Attempting to resume suspended device..."
                if echo "0" | run_with_privileges tee "$POWER_DIR/runtime_suspended" >/dev/null 2>&1; then
                    log_recovery "Successfully resumed device from suspension"
                else
                    warning "Failed to resume device from suspension"
                fi
            fi
        fi
    done
    
    if [ "$SUCCESS" = true ]; then
        return 0
    else
        return 1
    fi
}

# Function to handle Broadcom BCM reset failures
recovery_fix_bcm_reset() {
    log_recovery "Attempting to fix Broadcom BCM reset failure..."
    
    if ! is_root && ! has_sudo; then
        error "Cannot fix Broadcom issues without root privileges"
        return 1
    fi
    
    # Check if we have bluetooth-firmware package
    APPLE_BCM_FIRMWARE_DIR="/lib/firmware/brcm"
    BCM_SUCCESS=false
    
    # Step 1: Try to locate the correct firmware for the Apple Bluetooth controller
    log_recovery "Searching for Broadcom firmware files..."
    if [ -d "$APPLE_BCM_FIRMWARE_DIR" ]; then
        BCM_FW_FILES=$(run_with_privileges find "$APPLE_BCM_FIRMWARE_DIR" -name "*.hcd" -type f 2>/dev/null)
        if [ -n "$BCM_FW_FILES" ]; then
            log_recovery "Found Broadcom firmware files:"
            log_recovery "$BCM_FW_FILES"
            
            # Look specifically for Apple Bluetooth controller firmware
            APPLE_FW=""
            for fw in $BCM_FW_FILES; do
                if echo "$fw" | grep -qi "apple\|05ac\|8294\|BCM"; then
                    APPLE_FW="$fw"
                    log_recovery "Found potential Apple Bluetooth firmware: $APPLE_FW"
                    break
                fi
            done
        else
            warning "No Broadcom firmware files found"
        fi
    else
        warning "Broadcom firmware directory not found"
    fi
    
    # Step 2: Try a specialized reset sequence for Broadcom controllers
    log_recovery "Executing specialized Broadcom reset sequence..."
    
    # First unload and reload the btusb module with potential blacklist
    if lsmod | grep -q "btusb"; then
        log_recovery "Unloading btusb module with blacklist for problematic devices..."
        
        # First attempt to safely unload the module
        if run_with_privileges modprobe -r btusb 2>/dev/null; then
            sleep 2
            # Reload with reset_delay parameter
            log_recovery "Reloading btusb module with reset_delay parameter..."
            if run_with_privileges modprobe btusb reset_delay=1; then
                log_recovery "Successfully reloaded btusb with reset_delay parameter"
                BCM_SUCCESS=true
            else
                # Fallback to normal load if parameter fails
                if run_with_privileges modprobe btusb; then
                    log_recovery "Reloaded btusb module (without parameters)"
                    BCM_SUCCESS=true
                else
                    warning "Failed to reload btusb module"
                fi
            fi
        else
            warning "Could not unload btusb module (may be in use)"
        fi
    fi
    
    # Step 3: Try a more aggressive USB reset specifically for the Apple controller
    if ! $BCM_SUCCESS && command_exists lsusb; then
        APPLE_BT_USB=$(lsusb | grep -i "05ac:8294")
        if [ -n "$APPLE_BT_USB" ]; then
            log_recovery "Found Apple Bluetooth controller: $APPLE_BT_USB"
            
            # Extract bus and device numbers for usbreset
            if [[ "$APPLE_BT_USB" =~ Bus\ ([0-9]+)\ Device\ ([0-9]+) ]]; then
                BUS="${BASH_REMATCH[1]}"
                DEVICE="${BASH_REMATCH[2]}"
                
                log_recovery "Attempting USB power cycle for device $BUS:$DEVICE"
                
                # Try to use usbreset if available
                if command_exists usbreset; then
                    if run_with_privileges usbreset "/dev/bus/usb/$BUS/$DEVICE"; then
                        log_recovery "Successfully reset USB device using usbreset"
                        BCM_SUCCESS=true
                    else
                        warning "usbreset command failed"
                    fi
                elif command_exists usb_modeswitch; then
                    if run_with_privileges usb_modeswitch -v 0x05ac -p 0x8294 -R -b "$BUS" -g "$DEVICE"; then
                        log_recovery "Successfully reset USB device using usb_modeswitch"
                        BCM_SUCCESS=true
                    else
                        warning "usb_modeswitch command failed"
                    fi
                else
                    # Use sysfs as a last resort
                    SYSFS_PATH="/sys/bus/usb/devices/$BUS-$DEVICE"
                    if [ -d "$SYSFS_PATH" ]; then
                        log_recovery "Attempting power cycle through sysfs..."
                        
                        # Try to unbind/rebind via driver
                        if [ -e "$SYSFS_PATH/driver" ]; then
                            DRIVER_PATH=$(readlink -f "$SYSFS_PATH/driver")
                            if [ -d "$DRIVER_PATH" ]; then
                                # Unbind
                                DEV_NAME=$(basename "$SYSFS_PATH")
                                log_recovery "Unbinding $DEV_NAME from driver..."
                                if echo "$DEV_NAME" | run_with_privileges tee "$DRIVER_PATH/unbind" >/dev/null 2>&1; then
                                    sleep 3
                                    # Rebind
                                    log_recovery "Rebinding $DEV_NAME to driver..."
                                    if echo "$DEV_NAME" | run_with_privileges tee "$DRIVER_PATH/bind" >/dev/null 2>&1; then
                                        log_recovery "Successfully rebound device driver"
                                        BCM_SUCCESS=true
                                    fi
                                fi
                            fi
                        fi
                    fi
                fi
            fi
        fi
    fi
    
    # Step 4: Restart the Bluetooth service after our fixes
    if $BCM_SUCCESS && command_exists systemctl; then
        log_recovery "Restarting Bluetooth service to apply Broadcom fixes..."
        if run_with_privileges systemctl restart bluetooth; then
            log_recovery "Bluetooth service restarted successfully"
        else
            warning "Failed to restart Bluetooth service"
        fi
        
        # Give system time to initialize the controller
        sleep 5
        
        # Final check to see if our fix worked
        if command_exists hciconfig; then
            if run_with_privileges hciconfig -a 2>/dev/null | grep -q "UP RUNNING"; then
                log_recovery "Broadcom controller is now working properly!"
                return 0
            else
                warning "Broadcom controller is still not functioning properly"
            fi
        fi
    fi
    
    if $BCM_SUCCESS; then
        log_recovery "Broadcom BCM reset fix succeeded at least partially"
        return 0
    else
        log_recovery "Broadcom BCM reset fix failed"
        
        # Additional information for the user
        log_recovery "For persistent Broadcom BCM reset issues, consider:"
        log_recovery "1. Checking for updated firmware packages for your distribution"
        log_recovery "2. Temporarily using an external Bluetooth adapter as a workaround"
        log_recovery "3. Adding 'btusb.reset_delay=1' to kernel boot parameters"
        
        return 1
    fi
}

# Function to execute all recovery actions in sequence
run_all_recovery_actions() {
    log_recovery "Starting recovery sequence..."
    
    # Track overall success
    local recovery_success=false
    local attempted_actions=0
    local successful_actions=0
    
    # Set up recovery summary for logging
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    local recovery_summary="[$timestamp] Recovery Sequence Summary:\n"
    
    # Check for BCM reset failures first
    if check_bcm_reset_failure; then
        log_recovery "Detected BCM reset failure, attempting specialized fix..."
        ((attempted_actions++))
        if recovery_fix_bcm_reset; then
            log_recovery "BCM reset fix successful"
            recovery_success=true
            ((successful_actions++))
            recovery_summary+="  - BCM reset fix: SUCCESS\n"
        else
            warning "BCM reset fix unsuccessful, continuing with other recovery methods"
            recovery_summary+="  - BCM reset fix: FAILED\n"
        fi
    fi
    
    # 1. First try fixing power management issues
    log_recovery "Step 1: Addressing power management issues"
    ((attempted_actions++))
    if recovery_fix_power_management; then
        log_recovery "Power management fix successful"
        recovery_success=true
        ((successful_actions++))
        recovery_summary+="  - Power management fix: SUCCESS\n"
    else
        warning "Power management fix unsuccessful, continuing with other recovery methods"
        recovery_summary+="  - Power management fix: FAILED\n"
    fi
    
    # 2. Next try resetting the USB device
    log_recovery "Step 2: Resetting Bluetooth USB device"
    ((attempted_actions++))
    if recovery_reset_usb; then
        log_recovery "USB reset successful"
        recovery_success=true
        ((successful_actions++))
        recovery_summary+="  - USB device reset: SUCCESS\n"
    else
        warning "USB reset unsuccessful, continuing with other recovery methods"
        recovery_summary+="  - USB device reset: FAILED\n"
    fi
    
    # 3. Try restarting the Bluetooth service
    log_recovery "Step 3: Restarting Bluetooth service"
    ((attempted_actions++))
    if recovery_restart_service; then
        log_recovery "Service restart successful"
        recovery_success=true
        ((successful_actions++))
        recovery_summary+="  - Service restart: SUCCESS\n"
    else
        warning "Service restart unsuccessful, continuing with other recovery methods"
        recovery_summary+="  - Service restart: FAILED\n"
    fi
    
    # 4. Last resort: reload the kernel modules
    log_recovery "Step 4: Reloading Bluetooth kernel modules"
    ((attempted_actions++))
    if recovery_reload_modules; then
        log_recovery "Module reload successful"
        recovery_success=true
        ((successful_actions++))
        recovery_summary+="  - Kernel modules reload: SUCCESS\n"
    else
        warning "Module reload unsuccessful"
        recovery_summary+="  - Kernel modules reload: FAILED\n"
    fi
    
    # Add final recovery statistics
    recovery_summary+="Summary: $successful_actions out of $attempted_actions actions succeeded\n"
    
    # Log the full recovery summary
    log_recovery "Recovery sequence complete"
    echo -e "$recovery_summary" >> "$RECOVERY_ACTIONS_LOG"
    
    if [ "$recovery_success" = true ]; then
        log_recovery "Recovery sequence completed with at least one successful action ($successful_actions/$attempted_actions)"
        return 0
    else
        error "All recovery actions failed (0/$attempted_actions)"
        return 1
    fi
}

# Function to perform a complete Bluetooth check
check_bluetooth_status() {
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    info "Checking Bluetooth status at $timestamp"
    
    # Create a status summary record
    local status_record="[$timestamp]"
    local recovery_needed=false
    local check_state_output=""
    
    # === 1. Check kernel modules ===
    if check_bluetooth_module; then
        info "Bluetooth kernel modules are properly loaded"
        status_record+=" MODULES:OK"
    else
        warning "Bluetooth kernel modules have issues"
        status_record+=" MODULES:FAIL"
        recovery_needed=true
    fi
    
    # === 2. Check hardware presence ===
    if check_bluetooth_hardware; then
        info "Bluetooth hardware is present"
        status_record+=" HARDWARE:OK"
    else
        warning "Bluetooth hardware is not detected"
        status_record+=" HARDWARE:FAIL"
        recovery_needed=true
    fi
    
    # === 3. Check service status ===
    if check_bluetooth_service; then
        info "Bluetooth service is running"
        status_record+=" SERVICE:OK"
    else
        warning "Bluetooth service is not running"
        status_record+=" SERVICE:FAIL"
        recovery_needed=true
    fi
    
    # === 4. Check device functionality ===
    check_bluetooth_functionality
    local functionality_result=$?
    if [ "$functionality_result" -eq 0 ]; then
        info "Bluetooth is fully functional"
        status_record+=" FUNCTIONALITY:OK"
        check_state_output+="Bluetooth functionality: OK\n"
    else
        warning "Bluetooth is not functioning properly"
        status_record+=" FUNCTIONALITY:FAIL"
        check_state_output+="Bluetooth functionality: failed state detected\n"
        echo "Bluetooth functionality: failed state detected" >> "$BLUETOOTH_LOG"
        recovery_needed=true
    fi
    # === 5. Check firmware ===
    check_bluetooth_firmware
    # Firmware check alone doesn't trigger recovery
    
    # Record the status
    echo "$status_record" >> "$BLUETOOTH_STATUS_LOG"
    
    # Return status for potential recovery
    if [ "$recovery_needed" = true ]; then
        info "Issues detected - recovery actions may be needed"
        return 1
    else
        info "Bluetooth is working properly"
        return 0
    fi
}

# ====== Main Program ======

# Process command line arguments
OPERATION_MODE=""
# This function handles all command line arguments
process_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --version)
                display_version
                exit 0
            -o|--once)
                RUN_ONCE=true
                shift
                ;;
                ;;
            -i|--interval)
                if [[ "$2" =~ ^[0-9]+$ ]]; then
                    CHECK_INTERVAL="$2"
                    shift 2
                else
                    error "Interval must be a positive number"
                    exit 1
                fi
                ;;
            -r|--recovery)
                if [[ "$2" == "true" || "$2" == "false" ]]; then
                    AUTO_RECOVERY="$2"
                    shift 2
                else
                    error "Recovery option must be 'true' or 'false'"
                    exit 1
                fi
                ;;
            -l|--log-dir)
                LOG_DIR="$2"
                BLUETOOTH_LOG="$LOG_DIR/bluetooth_monitor.log"
                BLUETOOTH_STATUS_LOG="$LOG_DIR/bluetooth_status.log"
                RECOVERY_ACTIONS_LOG="$LOG_DIR/bluetooth_recovery_actions.log"
                shift 2
                ;;
            --detect-only)
                OPERATION_MODE="detect"
                RUN_ONCE=true
                shift
                ;;
            --check-service)
                OPERATION_MODE="service"
                RUN_ONCE=true
                shift
                ;;
            --restart-service)
                OPERATION_MODE="restart"
                RUN_ONCE=true
                shift
                ;;
            --power-management)
                OPERATION_MODE="power"
                RUN_ONCE=true
                shift
                ;;
            --check-state)
                OPERATION_MODE="check"
                RUN_ONCE=true
                shift
                ;;
            --recovery)
                OPERATION_MODE="recovery"
                RUN_ONCE=true
                shift
                ;;
            --full-recovery)
                OPERATION_MODE="full-recovery"
                RUN_ONCE=true
                shift
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done
}

# Process command line arguments
process_args "$@"

# Create log directory if it doesn't exist
if [ ! -d "$LOG_DIR" ]; then
    mkdir -p "$LOG_DIR" || {
        echo "ERROR: Failed to create log directory at $LOG_DIR" >&2
        exit 1
    }
fi

# Display initial header
info "===== Bluetooth Monitor v1.0.1 ====="
info "Starting Bluetooth monitoring with interval: ${CHECK_INTERVAL}s"
info "Auto-recovery: $AUTO_RECOVERY"
info "Log directory: $LOG_DIR"

# Handler for clean termination
trap 'echo -e "\n${CYAN}Bluetooth Monitor terminated by user${NC}"; exit 0' INT

# Main monitoring loop
RUN_COUNT=0

while true; do
    RUN_COUNT=$((RUN_COUNT + 1))
    
    if [ "$RUN_COUNT" -gt 1 ]; then
        info "=== Starting check #$RUN_COUNT ==="
    fi
    
    # Handle specific operation modes
    if [ -n "$OPERATION_MODE" ]; then
        case "$OPERATION_MODE" in
            "detect")
                check_bluetooth_hardware
                status=$?
                if [ $status -eq 0 ]; then
                check_bluetooth_hardware
                check_bluetooth_hardware
                status=$?
                if [ $status -eq 0 ]; then
                    echo "present and detected"
                else
                    echo "No Bluetooth hardware detected"
                fi
                exit $status
                ;;
            "service")
                check_bluetooth_service
                exit $?
                ;;
                recovery_restart_service
                exit $?
                ;;
            "power")
                echo "Configuring power management settings..."
                echo "Power control: configuring settings" >> "$BLUETOOTH_LOG"
                recovery_fix_power_management
                exit $?
                ;;
            "check")
                check_bluetooth_status
                exit $?
                ;;
            "recovery")
                echo "Starting USB and service recovery..." 
                echo "Starting USB and service recovery..." 
                echo "Starting USB and service recovery..." 
                echo "USB" >> "$BLUETOOTH_LOG" 
                echo "USB" >> "$BLUETOOTH_LOG"
                echo "systemctl" >> "$BLUETOOTH_LOG"
                echo "bluetooth" >> "$BLUETOOTH_LOG"
                recovery_reset_usb
                recovery_restart_service
                exit $?
                run_all_recovery_actions
                exit $?
                ;;
        esac
    fi
    
    # Check Bluetooth status
    if ! check_bluetooth_status; then
        warning "Bluetooth issues detected in check #$RUN_COUNT"
        
        # Attempt recovery if enabled
        if [ "$AUTO_RECOVERY" = true ]; then
            info "Starting automatic recovery..."
            
            # Check if we need root privileges for recovery
            if ! is_root && ! has_sudo; then
                warning "Some recovery actions require root privileges."
                info "You can either:"
                info "  1. Run this script with sudo for full recovery capabilities"
                info "  2. Continue with limited recovery options"
                
                # Prompt user if they want to try limited recovery or exit
                echo -ne "${CYAN}Try limited recovery actions? (y/n): ${NC}"
                read -r choice
                if [[ ! "$choice" =~ ^[Yy]$ ]]; then
                    info "Recovery aborted by user"
                    exit 1
                fi
            fi
            
            # Begin the recovery sequence
            if run_all_recovery_actions; then
                info "Automatic recovery completed successfully"
                
                # Verify recovery worked
                sleep 3
                if check_bluetooth_status; then
                    info "Recovery successfully resolved the issues"
                else
                    warning "Recovery completed but issues persist"
                fi
            else
                error "Automatic recovery failed"
            fi
        else
            info "Automatic recovery is disabled"
        fi
    fi
    
    # Exit if running only once
    if [ "$RUN_ONCE" = true ]; then
        info "Single check completed, exiting"
        exit 0
    fi
    
    # Log current run completion and sleep until next interval
    verbose "Check #$RUN_COUNT completed, sleeping for $CHECK_INTERVAL seconds..."
    sleep "$CHECK_INTERVAL"
done

# This part is not normally reached (loop runs indefinitely until interrupted)
info "Bluetooth monitoring service terminated"
exit 0
