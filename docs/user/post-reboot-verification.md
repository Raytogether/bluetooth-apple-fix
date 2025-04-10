# Post-Reboot Verification Guide

This guide outlines the steps to verify that both WiFi and Bluetooth are working correctly together after a system reboot.

## Automatic Verification Steps

After rebooting your system, follow these steps to verify everything is working:

1. **Check Bluetooth Service Status**
   ```bash
   systemctl status bluetooth-monitor
   systemctl status bluetooth
   ```
   Both services should show as `active (running)`.

2. **Verify Bluetooth Hardware Detection**
   ```bash
   bluetoothctl show
   ```
   This should display your controller information, including address and state.

3. **Check WiFi and Bluetooth Connectivity**
   ```bash
   # Check WiFi
   nmcli device status | grep wifi
   
   # Check Bluetooth Devices
   bluetoothctl devices
   ```

4. **Test Bluetooth Functionality**
   - Try scanning for devices: `bluetoothctl scan on`
   - Connect to a paired device: `bluetoothctl connect XX:XX:XX:XX:XX:XX`

## Manual Intervention (If Needed)

If Bluetooth is not working after reboot:

1. **Run Verification Script**
   ```bash
   sudo /usr/local/bin/verify_install.sh
   ```
   This will check if all components are properly installed.

2. **Check Logs for Issues**
   ```bash
   journalctl -u bluetooth-monitor -n 50
   grep -i "fail\|error" /var/log/bluetooth-monitor/bluetooth_monitor.log
   ```

3. **Manually Trigger Recovery (If Needed)**
   ```bash
   sudo /usr/local/bin/bluetooth_monitor.sh --full-recovery
   ```
   This will execute a comprehensive recovery sequence.

## Troubleshooting Common Issues

### If WiFi Works But Bluetooth Doesn't

1. Check if the BCM reset failure error appears:
   ```bash
   dmesg | grep -i "BCM: Reset failed"
   ```

2. If the error is present, run:
   ```bash
   sudo /usr/local/bin/bluetooth_monitor.sh --full-recovery --once
   ```

### If Both WiFi and Bluetooth Fail

This is rare but may indicate a power management issue:

1. Check USB power state:
   ```bash
   lsusb -t | grep -i bluetooth
   ```

2. Reset USB and wireless subsystems:
   ```bash
   sudo modprobe -r btusb
   sudo modprobe -r bluetooth
   sudo rfkill block all
   sudo rfkill unblock all
   sudo modprobe bluetooth
   sudo modprobe btusb
   sudo systemctl restart NetworkManager
   sudo systemctl restart bluetooth
   ```

## Verifying WiFi and Bluetooth Coexistence

To verify WiFi and Bluetooth are working together properly:

1. **Activate Both Simultaneously**
   - Connect to WiFi network
   - Connect to Bluetooth device (headphones or speaker)
   - Stream audio over Bluetooth while using WiFi

2. **Check for Interference**
   ```bash
   # Watch for errors while using both
   tail -f /var/log/bluetooth-monitor/bluetooth_monitor.log
   ```

3. **Test Bandwidth Stability**
   - Download a large file via WiFi while streaming audio
   - Check if there are any disconnections or audio interruptions

If both remain stable during simultaneous use, the fixes have been successful, and both WiFi and Bluetooth are correctly coexisting.

