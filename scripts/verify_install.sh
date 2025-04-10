#!/bin/bash
#
# Verification script for Bluetooth Apple Fix
# Version: 1.1.0
# Created: April 10, 2025
#
# This script verifies the Bluetooth Apple Fix installation

# ANSI color codes for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Display header
echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}   Bluetooth Apple Fix Verification      ${NC}"
echo -e "${BOLD}   Version 1.1.0                         ${NC}"
echo -e "${BOLD}=========================================${NC}"
echo

# Initialize counters
ERRORS=0
WARNINGS=0
PASSED=0

# Log function for successes
pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    PASSED=$((PASSED + 1))
}

# Log function for warnings
warn() {
    echo -e "${YELLOW}⚠ WARNING${NC}: $1"
    WARNINGS=$((WARNINGS + 1))
}

# Log function for errors
fail() {
    echo -e "${RED}✗ FAIL${NC}: $1" >&2
    ERRORS=$((ERRORS + 1))
}

# Function to check file existence and permissions
check_file() {
    local file="$1"
    local expected_perm="$2"
    local description="$3"
    
    if [ ! -f "$file" ]; then
        fail "$description not found: $file"
        return 1
    fi
    
    if [ -n "$expected_perm" ]; then
        local actual_perm=$(stat -c %a "$file")
        if [ "$actual_perm" != "$expected_perm" ]; then
            warn "$description has incorrect permissions: $actual_perm (expected $expected_perm)"
            return 2
        fi
    fi
    
    pass "$description is properly installed: $file"
    return 0
}

# Function to check directory existence and permissions
check_directory() {
    local dir="$1"
    local expected_perm="$2"
    local description="$3"
    
    if [ ! -d "$dir" ]; then
        fail "$description not found: $dir"
        return 1
    fi
    
    if [ -n "$expected_perm" ]; then
        local actual_perm=$(stat -c %a "$dir")
        if [ "$actual_perm" != "$expected_perm" ]; then
            warn "$description has incorrect permissions: $actual_perm (expected $expected_perm)"
            return 2
        fi
    fi
    
    pass "$description is properly set up: $dir"
    return 0
}

# Function to check kernel module parameters
check_module_param() {
    local module="$1"
    local param="$2"
    local expected="$3"
    
    if [ ! -d "/sys/module/$module" ]; then
        warn "Module $module is not loaded, cannot check parameters"
        return 2
    fi
    
    if [ ! -f "/sys/module/$module/parameters/$param" ]; then
        warn "Parameter $module.$param does not exist"
        return 2
    fi
    
    local value=$(cat "/sys/module/$module/parameters/$param" 2>/dev/null)
    if [ "$value" = "$expected" ]; then
        pass "Module parameter $module.$param = $value (correct)"
        return 0
    else
        warn "Module parameter $module.$param = $value (expected $expected)"
        return 2
    fi
}

echo -e "${BOLD}1. Checking installed files${NC}"

# Check main script
check_file "/usr/local/bin/bluetooth_monitor.sh" "755" "Main monitor script"

# Check configuration files
check_file "/etc/bluetooth-monitor/config" "644" "Configuration file"
check_file "/etc/modprobe.d/bluetooth-apple.conf" "644" "Module parameters configuration"
check_file "/etc/udev/rules.d/99-bluetooth-apple.rules" "644" "udev rules"
check_file "/etc/systemd/system/bluetooth-monitor.service" "644" "systemd service"
check_file "/etc/logrotate.d/bluetooth-monitor" "644" "Log rotation configuration"

# Check directories
echo -e "\n${BOLD}2. Checking directories${NC}"
check_directory "/var/log/bluetooth-monitor" "755" "Log directory"
check_directory "/etc/bluetooth-monitor" "755" "Configuration directory"

# Check if backup directory exists in the project
if [ -d "$(dirname "$0")/../backup" ]; then
    pass "Project backup directory exists"
else
    warn "Project backup directory not found"
fi

# Check kernel module parameters
echo -e "\n${BOLD}3. Checking kernel module parameters${NC}"

# Check if modules are loaded
if lsmod | grep -q "bluetooth"; then
    pass "Bluetooth module is loaded"
    
    # Check bluetooth module parameters
    check_module_param "bluetooth" "disable_ertm" "1"
    check_module_param "bluetooth" "disable_esco" "0"
else
    warn "Bluetooth module is not loaded, cannot check parameters"
fi

if lsmod | grep -q "btusb"; then
    pass "btusb module is loaded"
    
    # Check btusb module parameters
    check_module_param "btusb" "reset" "Y"
    check_module_param "btusb" "enable_autosuspend" "N"
else
    warn "btusb module is not loaded, cannot check parameters"
fi

# Check service status
echo -e "\n${BOLD}4. Checking service status${NC}"

if command -v systemctl >/dev/null; then
    if systemctl is-active --quiet bluetooth-monitor; then
        pass "bluetooth-monitor service is running"
    else
        warn "bluetooth-monitor service is not running"
        echo "   Start it with: sudo systemctl start bluetooth-monitor"
    fi

    if systemctl is-enabled --quiet bluetooth-monitor; then
        pass "bluetooth-monitor service is enabled at boot"
    else
        warn "bluetooth-monitor service is not enabled at boot"
        echo "   Enable it with: sudo systemctl enable bluetooth-monitor"
    fi
else
    warn "systemctl not found, cannot check service status"
fi

# Check for Bluetooth functionality
echo -e "\n${BOLD}5. Checking Bluetooth functionality${NC}"

# Check if Bluetooth hardware is present
if [ -d "/sys/class/bluetooth" ] && [ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]; then
    pass "Bluetooth hardware is detected"
else
    if command -v lsusb >/dev/null && lsusb | grep -qi "bluetooth"; then
        pass "Bluetooth USB device is detected"
    else
        warn "No Bluetooth hardware detected"
    fi
fi

# Check if bluetoothctl is working
if command -v bluetoothctl >/dev/null; then
    if bluetoothctl show 2>/dev/null | grep -q "Controller"; then
        pass "Bluetooth controller is functional"
    else
        warn "Bluetooth controller is not functional"
    fi
else
    warn "bluetoothctl not found, cannot check Bluetooth functionality"
fi

# Check power management settings for USB devices
echo -e "\n${BOLD}6. Checking USB power management${NC}"

BT_DEVICES_FOUND=0
for device in /sys/bus/usb/devices/*; do
    # Look for Bluetooth devices
    if [ -f "$device/idVendor" ] && [ -f "$device/idProduct" ]; then
        vendor=$(cat "$device/idVendor" 2>/dev/null)
        product=$(cat "$device/idProduct" 2>/dev/null)
        
        # Check if this is an Apple Bluetooth device or any Bluetooth device
        if [ "$vendor" = "05ac" ] && [ "$product" = "8294" ]; then
            BT_DEVICES_FOUND=$((BT_DEVICES_FOUND + 1))
            if [ -f "$device/power/control" ]; then
                power_control=$(cat "$device/power/control" 2>/dev/null)
                if [ "$power_control" = "on" ]; then
                    pass "Apple Bluetooth device power management is correctly set to 'on'"
                else
                    warn "Apple Bluetooth device power management is set to '$power_control' (expected 'on')"
                fi
            fi
            
            if [ -f "$device/power/autosuspend" ]; then
                autosuspend=$(cat "$device/power/autosuspend" 2>/dev/null)
                if [ "$autosuspend" = "-1" ]; then
                    pass "Apple Bluetooth device autosuspend is correctly set to '-1'"
                else
                    warn "Apple Bluetooth device autosuspend is set to '$autosuspend' (expected '-1')"
                fi
            fi
        fi
    fi
done

if [ "$BT_DEVICES_FOUND" -eq 0 ]; then
    warn "No Apple Bluetooth devices found, cannot check USB power management"
fi

# Check for common issues
echo -e "\n${BOLD}7. Checking for common issues${NC}"

# Check for BCM reset failures in dmesg
if command -v dmesg >/dev/null && [ "$(id -u)" -eq 0 ]; then
    if dmesg | grep -q "BCM: Reset failed"; then
        fail "BCM reset failures detected in dmesg"
        echo "   Run the recovery script: sudo /usr/local/bin/bluetooth_monitor.sh --full-recovery"
    else
        pass "No BCM reset failures detected in dmesg"
    fi
else
    warn "Cannot check for BCM reset failures (need root privileges)"
fi

# Check for firmware files
if [ -d "/lib/firmware/brcm" ]; then
    if find "/lib/firmware/brcm" -name "*.hcd" | grep -q .; then
        pass "Bluetooth firmware files are present"
    else
        warn "No Bluetooth firmware files found in /lib/firmware/brcm"
    fi
else
    warn "Broadcom firmware directory not found"
fi

# Final summary
echo
echo -e "${BOLD}=========================================${NC}"
echo -e "${BOLD}       Verification Summary              ${NC}"
echo -e "${BOLD}=========================================${NC}"
echo -e "Checks passed:  ${GREEN}$PASSED${NC}"
echo -e "Warnings:       ${YELLOW}$WARNINGS${NC}"
echo -e "Errors:         ${RED}$ERRORS${NC}"
echo

if [ $ERRORS -eq 0 ]; then
    if [ $WARNINGS -eq 0 ]; then
        echo -e "${GREEN}All checks passed successfully!${NC}"
    else
        echo -e "${YELLOW}Installation verified with warnings.${NC}"
        echo "Review the warnings above and address them if needed."
    fi
    exit 0
else
    echo -e "${RED}Verification failed with $ERRORS errors.${NC}"
    echo "Please fix the issues identified above."
    exit 1
fi
    check_status "Configuration file is missing"
fi

# Check log rotation
if [ -f "/etc/logrotate.d/bluetooth-monitor" ]; then
    check_status "Log rotation is configured"
else
    check_status "Log rotation configuration is missing"
fi

# Check Bluetooth hardware detection
echo -e "\n${YELLOW}Checking Bluetooth hardware...${NC}"
if lsusb | grep -q "05ac:8294\|0a5c"; then
    check_status "Apple/Broadcom Bluetooth hardware detected"
else
    echo -e "${YELLOW}! No Apple/Broadcom Bluetooth hardware detected${NC}"
fi

# Check power management settings
echo -e "\n${YELLOW}Checking power management settings...${NC}"
for dev in /sys/bus/usb/devices/*; do
    if [ -f "$dev/idVendor" ] && [ -f "$dev/idProduct" ]; then
        vendor=$(cat "$dev/idVendor" 2>/dev/null)
        product=$(cat "$dev/idProduct" 2>/dev/null)
        if [ "$vendor" = "05ac" ] || [ "$vendor" = "0a5c" ]; then
            if [ -f "$dev/power/control" ]; then
                power_control=$(cat "$dev/power/control")
                if [ "$power_control" = "on" ]; then
                    check_status "Power management is properly configured"
                else
                    check_status "Power management settings are incorrect"
                fi
            fi
        fi
    fi
done

echo -e "\n${YELLOW}Checking logs...${NC}"
if [ -f "/var/log/bluetooth-monitor/bluetooth_monitor.log" ]; then
    echo "Recent log entries:"
    tail -n 5 /var/log/bluetooth-monitor/bluetooth_monitor.log
else
    echo -e "${RED}No log file found${NC}"
fi

echo -e "\n${YELLOW}Verification complete${NC}"
