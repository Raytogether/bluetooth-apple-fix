# Bluetooth Module Parameters for Apple Devices

This document describes the kernel module parameters used to optimize Bluetooth functionality on Apple devices.

## Overview

The file `config/modprobe.d/bluetooth-apple.conf` contains carefully tuned parameters for Apple Bluetooth hardware. These parameters address various issues discovered during our technical investigation documented in `docs/technical/technical-findings.md`.

## Parameter Details

### bluetooth Module

```
options bluetooth disable_ertm=1 disable_esco=0
```

- `disable_ertm=1` - Disable Enhanced Re-Transmission Mode, which can cause connection issues with Apple devices due to timing constraints
- `disable_esco=0` - Enable Enhanced SCO for better audio quality with Apple audio devices

### btusb Module

```
options btusb reset=1 external_amp=0 esco=1
```

- `reset=1` - Forces a hardware reset during module initialization, addressing the BCM reset failures common on Apple hardware
- `external_amp=0` - Disables external amplifier support which is not used in Apple devices and can cause conflicts
- `esco=1` - Enables enhanced SCO (eSCO) support for better audio quality in Bluetooth audio devices

### apple_bce Module (if present)

```
options apple_bce power_save=0
```

- `power_save=0` - Disables power saving features in the Apple BCE (Broadcom) driver which can cause stability issues and connection drops

### USB Core Configuration

```
options usbcore autosuspend=-1
```

- `autosuspend=-1` - Completely disables USB autosuspend for Bluetooth devices, preventing power management from causing device resets

### Module Dependencies

```
softdep btusb pre: btintel btbcm bluetooth
```

- Ensures the kernel modules load in the correct sequence for Apple hardware
- The sequence is essential: bluetooth → btbcm → btintel → btusb → apple_bce

## Installation

To install these parameters system-wide:

```bash
sudo mkdir -p /etc/modprobe.d/
sudo cp config/modprobe.d/bluetooth-apple.conf /etc/modprobe.d/
sudo update-initramfs -u    # On Debian/Ubuntu systems
sudo dracut -f               # On Fedora/RHEL systems
```

## Testing

After installation, reboot the system and verify that parameters are applied:

```bash
systool -vm btusb | grep -A2 parameters
```

Parameters should match those specified in the configuration file.

