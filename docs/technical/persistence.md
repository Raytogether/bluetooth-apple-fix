# Bluetooth Monitor Persistence Mechanisms

## Overview
This document details the persistence mechanisms implemented to ensure reliable Bluetooth operation across system reboots and various system states.

## Core Persistence Components

### 1. Systemd Service Integration
- Automatic startup at boot via systemd
- Service dependencies properly configured
- Automatic restart on failures
- Proper shutdown handling

### 2. USB Device Management
- Persistent udev rules for device detection
- Power management settings preservation
- USB device reset handling
- BCM chip-specific configurations

### 3. Power Management
- Automatic power management optimization
- Sleep/resume handling
- USB autosuspend control
- Device state preservation

### 4. Logging and State Tracking
- Persistent log storage in /var/log/bluetooth-monitor/
- Log rotation configuration
- State tracking across reboots
- Recovery action history

## Configuration Files

### 1. Systemd Service File
Location: `/etc/systemd/system/bluetooth-monitor.service`
Purpose: Ensures the monitoring service starts automatically and persists across reboots.

### 2. udev Rules
Location: `/etc/udev/rules.d/99-bluetooth-apple.rules`
Purpose: Provides persistent device configuration and power management settings.

### 3. Logging Configuration
Location: `/etc/logrotate.d/bluetooth-monitor`
Purpose: Ensures proper log management and rotation.

## Recovery Persistence

### 1. Hardware Reset Handling
- Persistent storage of device states
- Recovery action tracking
- Progressive recovery strategies

### 2. Firmware Management
- Firmware presence verification
- Proper firmware loading
- Version tracking

### 3. Error State Management
- Persistent error tracking
- Recovery success rate monitoring
- Issue pattern recognition

## Manual Intervention

In cases where automatic persistence mechanisms fail:

1. Check systemd service status:
   ```bash
   sudo systemctl status bluetooth-monitor
   ```

2. Verify udev rules:
   ```bash
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

3. Review logs:
   ```bash
   journalctl -u bluetooth-monitor
   cat /var/log/bluetooth-monitor/bluetooth_monitor.log
   ```

4. Reset persistence:
   ```bash
   sudo systemctl restart bluetooth-monitor
   ```
