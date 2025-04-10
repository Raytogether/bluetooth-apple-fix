#!/bin/bash

# Installation script for Bluetooth Monitor

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root" >&2
    exit 1
fi

# Create necessary directories
mkdir -p /usr/local/bin
mkdir -p /etc/bluetooth-monitor
mkdir -p /var/log/bluetooth-monitor

# Install udev rules
cp udev/99-bluetooth-apple.rules /etc/udev/rules.d/
udevadm control --reload-rules

# Copy main script
cp src/bluetooth_monitor.sh /usr/local/bin/
chmod +x /usr/local/bin/bluetooth_monitor.sh

# Install systemd service
cp systemd/bluetooth-monitor.service /etc/systemd/system/
systemctl daemon-reload

# Create default config
if [ ! -f /etc/bluetooth-monitor/config ]; then
    cat > /etc/bluetooth-monitor/config <<EOF
VERBOSE=true
CHECK_INTERVAL=60
AUTO_RECOVERY=true
LOG_DIR=/var/log/bluetooth-monitor
EOF
fi

# Setup log rotation
cat > /etc/logrotate.d/bluetooth-monitor <<EOF
/var/log/bluetooth-monitor/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF

echo "Installation complete. Use the following commands to manage the service:"
echo "systemctl start bluetooth-monitor   # Start the service"
echo "systemctl enable bluetooth-monitor  # Enable at boot"
echo "systemctl status bluetooth-monitor  # Check status"
