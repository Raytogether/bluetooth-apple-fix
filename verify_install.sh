#!/bin/bash

# Post-installation verification script

# Colors for output
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
NC="\033[0m"

check_status() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ $1${NC}"
        return 0
    else
        echo -e "${RED}✗ $1${NC}"
        return 1
    fi
}

# Check system requirements
echo -e "\n${YELLOW}Checking system requirements...${NC}"

# Check systemd service
systemctl is-active --quiet bluetooth-monitor
check_status "Bluetooth monitor service is running"

systemctl is-enabled --quiet bluetooth-monitor
check_status "Bluetooth monitor service is enabled at boot"

# Check udev rules
if [ -f "/etc/udev/rules.d/99-bluetooth-apple.rules" ]; then
    check_status "udev rules are installed"
else
    check_status "udev rules are missing"
fi

# Check script installation
if [ -x "/usr/local/bin/bluetooth_monitor.sh" ]; then
    check_status "Bluetooth monitor script is installed"
else
    check_status "Bluetooth monitor script is missing"
fi

# Check log directory
if [ -d "/var/log/bluetooth-monitor" ]; then
    check_status "Log directory exists"
else
    check_status "Log directory is missing"
fi

# Check config file
if [ -f "/etc/bluetooth-monitor/config" ]; then
    check_status "Configuration file exists"
else
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
