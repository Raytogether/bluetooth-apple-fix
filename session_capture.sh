#!/bin/bash
# Script to capture and document our Warp AI session on the Bluetooth project

# Set up variables
SESSION_DIR="$HOME/Documents/warp-ai-sessions"
SESSION_FILE="$SESSION_DIR/20250408_bluetooth_fix.md"
REPO_PATH="$HOME/code/bluetooth-apple-fix"

# Create session directory if it doesn't exist
mkdir -p "$SESSION_DIR"

# Create session document with headers
cat > "$SESSION_FILE" << 'EOF'
# Bluetooth Apple Fix Project - Warp AI Session

**Date:** April 8, 2025  
**Goal:** Develop a robust solution for Apple Bluetooth issues on Linux

## Session Overview
This document captures the development process of a comprehensive Bluetooth monitoring and auto-recovery solution for Apple Bluetooth devices on Linux systems. The project addresses common issues with Bluetooth disconnections and failures.

## Problem Definition
Apple Bluetooth devices often experience issues on Linux systems:
- Devices disconnect randomly
- Power management settings cause device resets
- Bluetooth stack fails to recover properly
- Broadcom chips have well-known reset failures

## Solution Development

### 1. Monitoring Script
We developed a comprehensive `bluetooth_monitor.sh` script that:
- Detects Apple Bluetooth hardware
- Monitors Bluetooth service status
- Checks hardware functionality
- Identifies common failure modes
- Implements multiple recovery strategies
- Maintains logs of actions and status

### 2. Test Suite
We created a comprehensive test suite that uses mock commands to test:
- Command-line options
- Hardware detection
- Service management
- Power management
- Recovery mechanisms

## Key Technical Aspects

### Detection Methods
- USB device identification
- Sysfs interface monitoring
- Stack status checks
- Kernel module verification

### Recovery Strategies
1. Power management settings adjustment
2. Service restart
3. USB device reset (multiple methods)
4. Kernel module reload
5. Specialized Broadcom reset procedures
6. Persistent settings via udev rules

### Testing Approach
- Mock system commands
- Test isolation
- Comprehensive setup and teardown
- Detailed result validation

## Project Files

### Main Components
- `src/bluetooth_monitor.sh`: Main monitoring and recovery script
- `tests/run_tests.sh`: Comprehensive test suite
- `tests/test_utils.sh`: Testing utilities and mock functions
- Documentation and session capture

### Project Structure
```
bluetooth-apple-fix/
├── src/
│   └── bluetooth_monitor.sh
├── tests/
│   ├── run_tests.sh
│   └── test_utils.sh
├── README.md
└── docs/
    └── bluetooth_monitor.sh_documentation.md
```

## Session History
EOF

# Add content from terminal history
echo "## Terminal Session History" >> "$SESSION_FILE"
echo "" >> "$SESSION_FILE"
echo '```bash' >> "$SESSION_FILE"
history | grep -v "history" | tail -50 >> "$SESSION_FILE"
echo '```' >> "$SESSION_FILE"

# Add code snippets and explanations
cat >> "$SESSION_FILE" << 'EOF'

## Implementation Highlights

### Hardware Detection
```bash
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
                # Additional device info extraction...
            fi
        done
    fi
    
    # Process results
    if $SYSFS_FOUND || $USB_FOUND || $HCICONFIG_FOUND; then
        info "Bluetooth hardware is present and detected"
        return 0
    else
        warning "No Bluetooth hardware detected through any method"
        return 1
    fi
}
```

### USB Reset Recovery
```bash
# Function to reset Bluetooth USB device
recovery_reset_usb() {
    log_recovery "Attempting to reset

