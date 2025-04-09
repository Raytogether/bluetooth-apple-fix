# Bluetooth Apple Fix

## Overview
A comprehensive solution for handling Bluetooth connectivity issues on Apple devices, particularly focusing on BCM reset failures and power management issues.

## Features
- Automatic detection of Bluetooth issues
- Smart recovery mechanisms
- Persistent fixes across reboots
- Detailed logging and monitoring
- Systemd service integration
- udev rules for consistent device management

## Quick Start
```bash
# Clone the repository
git clone https://github.com/yourusername/bluetooth-apple-fix.git
cd bluetooth-apple-fix

# Install the service
sudo ./install.sh

# Verify installation
sudo ./verify_install.sh

# Manual run (if needed)
./src/bluetooth_monitor.sh --verbose
```

## Persistence Mechanisms
This solution implements several layers of persistence to ensure reliable Bluetooth operation:

1. **Systemd Service**
   - Automatic startup at boot
   - Continuous monitoring
   - Automatic recovery

2. **udev Rules**
   - Consistent power management
   - Hardware-specific optimizations
   - Automatic device configuration

3. **Power Management**
   - Optimized power settings
   - Automatic USB device management
   - Prevention of sleep-related issues

## Documentation
- [User Guide](docs/user/usage.md)
- [Technical Documentation](docs/technical/implementation.md)
- [Persistence Details](docs/technical/persistence.md)

## Requirements
- Linux-based system
- systemd (for service installation)
- Root privileges for some recovery actions
- udev system

## Troubleshooting
1. Run the verification script:
   ```bash
   sudo ./verify_install.sh
   ```
2. Check the logs:
   ```bash
   journalctl -u bluetooth-monitor
   cat /var/log/bluetooth-monitor/bluetooth_monitor.log
   ```
3. Verify udev rules:
   ```bash
   udevadm control --reload-rules
   ```

## Contributing
Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run the test suite
5. Submit a pull request

## Testing
```bash
# Run the test suite
./tests/run_tests.sh
```

## License
MIT
