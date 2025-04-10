# Bluetooth Recovery Procedures

This document provides detailed step-by-step recovery procedures for resolving Bluetooth connectivity issues on Apple devices running Linux. These procedures are based on the technical findings related to module loading order and power management.

## Quick Recovery Procedure

For immediate recovery without system restart:

1. **Stop Bluetooth Services**
   ```bash
   sudo systemctl stop bluetooth
   sudo systemctl stop bluetooth-monitor
   ```

2. **Unload Bluetooth Modules (in correct order)**
   ```bash
   sudo modprobe -r btusb
   sudo modprobe -r btintel
   sudo modprobe -r btbcm
   sudo modprobe -r bluetooth
   sudo modprobe -r apple_bce # If present
   ```

3. **Reset USB Device**
   ```bash
   # Find the USB device ID
   lsusb | grep -i bluetooth
   
   # Reset the device (replace X:X with your device ID)
   echo "0" > /sys/bus/usb/devices/X:X/authorized
   sleep 2
   echo "1" > /sys/bus/usb/devices/X:X/authorized
   ```

4. **Reload Modules (in correct order)**
   ```bash
   sudo modprobe bluetooth
   sleep 1
   sudo modprobe btbcm
   sleep 1
   sudo modprobe btintel
   sleep 1
   sudo modprobe btusb reset=1 esco=1
   sleep 2
   sudo modprobe apple_bce # If applicable
   ```

5. **Restart Bluetooth Services**
   ```bash
   sudo systemctl start bluetooth
   sleep 5
   sudo systemctl start bluetooth-monitor
   ```

6. **Verify Recovery**
   ```bash
   hciconfig
   bluetoothctl show
   ```

## Automated Recovery Script

For convenience, the automated recovery script can be used:

```bash
sudo bluetooth_monitor.sh --full-recovery --once
```

## Recovery for Specific Issues

### BCM Reset Failures

If you see "BCM: Reset failed" in dmesg:

1. **Apply firmware workaround**
   ```bash
   sudo mkdir -p /lib/firmware/brcm
   sudo cp firmware/BCM*.hcd /lib/firmware/brcm/
   ```

2. **Force firmware reload**
   ```bash
   sudo modprobe -r btusb
   sleep 2
   sudo modprobe btusb reset=1 esco=1
   ```

### Power Management Issues

If disconnections occur during system idle:

1. **Disable USB autosuspend**
   ```bash
   echo "options usbcore autosuspend=-1" | sudo tee /etc/modprobe.d/usb-bluetooth.conf
   ```

2. **Apply udev rules**
   ```bash
sudo cp config/udev/99-bluetooth-apple.rules /etc/udev/rules.d/
   sudo udevadm control --reload-rules
   sudo udevadm trigger
   ```

### No Bluetooth Adapter Found

If the system reports "No default controller available":

1. **Check hardware detection**
   ```bash
   lsusb | grep -i bluetooth
   dmesg | grep -i bluetooth
   ```

2. **Reset the Bluetooth stack completely**
   ```bash
   sudo systemctl stop bluetooth
   sudo rfkill block bluetooth
   sleep 2
   sudo rfkill unblock bluetooth
   sleep 2
   sudo systemctl start bluetooth
   ```

## Persistent Fix Implementation

To make these fixes persistent across reboots:

1. **Install the monitoring service**
   ```bash
   sudo cp config/systemd/bluetooth-monitor.service /etc/systemd/system/
   sudo systemctl enable bluetooth-monitor
   sudo systemctl start bluetooth-monitor
   ```

2. **Configure module loading order**
   ```bash
   echo "softdep btusb pre: btintel btbcm bluetooth" | sudo tee /etc/modprobe.d/bluetooth-deps.conf
   ```

3. **Set correct module parameters**
   ```bash
   echo "options btusb reset=1 esco=1" | sudo tee /etc/modprobe.d/btusb.conf
   ```

## Troubleshooting Recovery Failures

If recovery fails:

1. **Check system logs**
   ```bash
   dmesg | grep -i bluetooth
   journalctl -u bluetooth
   ```

2. **Verify USB device status**
   ```bash
   lsusb -v | grep -A 20 -i bluetooth
   ```

3. **Check firmware availability**
   ```bash
   ls -l /lib/firmware/brcm/
   ```

4. **Look for interfering services**
   ```bash
   systemctl list-units | grep -i blue
   ```

## System Configuration Requirements

For successful recovery, ensure your system meets these requirements:

- Linux kernel 5.10 or newer
- BlueZ 5.50 or newer
- systemd 245 or newer
- udev rules support
- Access to /sys filesystem
- sudo/root privileges for module management

These procedures have been tested on Ubuntu 22.04 LTS, Fedora 36, and Arch Linux with Apple MacBook Pro and MacBook Air models from 2018-2022.

