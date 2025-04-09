# Bluetooth Monitor Usage Guide

## Overview
The Bluetooth Monitor script provides automated monitoring and recovery for Bluetooth connectivity issues, particularly focusing on Apple hardware running Linux.

## Installation
1. Install the service using the provided install script:
```bash
sudo ./install.sh
```

2. Verify the installation:
```bash
sudo ./verify_install.sh
```

## Usage Options
The script supports several command-line options:

- `-h, --help`: Display help message
- `-v, --verbose`: Enable verbose output
- `-o, --once`: Run once and exit
- `-i, --interval`: Set check interval (seconds)
- `-r, --recovery`: Enable/disable auto-recovery
- `-l, --log-dir`: Set custom log directory

## Common Commands
```bash
# Start the service
sudo systemctl start bluetooth-monitor

# Enable at boot
sudo systemctl enable bluetooth-monitor

# Check status
sudo systemctl status bluetooth-monitor

# View logs
journalctl -u bluetooth-monitor
```

## Troubleshooting
1. Check the logs in `/var/log/bluetooth-monitor/`
2. Verify Bluetooth hardware detection
3. Ensure proper permissions
4. Check systemd service status
