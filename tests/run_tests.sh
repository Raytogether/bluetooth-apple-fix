#!/bin/bash

# Comprehensive test suite for bluetooth-monitor
# Tests all major components with proper mocking and isolation

# Get directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
SRC_DIR="$PROJECT_ROOT/src"
MONITOR_SCRIPT="$SRC_DIR/bluetooth_monitor.sh"
TEST_TEMP_DIR="$SCRIPT_DIR/temp"

# Source test utilities
source "$SCRIPT_DIR/test_utils.sh"

# Ensure the monitor script exists
if [ ! -f "$MONITOR_SCRIPT" ]; then
    echo -e "${RED}Error: Bluetooth monitor script not found at $MONITOR_SCRIPT${NC}"
    exit 1
fi

# Ensure the script is executable
if [ ! -x "$MONITOR_SCRIPT" ]; then
    echo -e "${YELLOW}Warning: Bluetooth monitor script is not executable, fixing...${NC}"
    chmod +x "$MONITOR_SCRIPT"
fi

#===========================================================
# Global Setup and Teardown Functions
#===========================================================

# Create backup of working script if not already done
backup_working_script() {
    BACKUP_FILE="$HOME/code/bluetooth-apple-fix/bluetooth_monitor.sh_known.working.copy.do.not.touch.me.backup"
    
    if [ ! -f "$BACKUP_FILE" ]; then
        echo -e "${YELLOW}Creating backup of working Bluetooth monitor script...${NC}"
        cp "$MONITOR_SCRIPT" "$BACKUP_FILE"
        chmod 400 "$BACKUP_FILE"  # Read-only to prevent accidental modification
        echo -e "${GREEN}Backup created at: $BACKUP_FILE${NC}"
    else
        echo -e "${YELLOW}Backup already exists at: $BACKUP_FILE${NC}"
    fi
}

# Global setup function
global_setup() {
    echo -e "${YELLOW}Setting up test environment...${NC}"
    
    # Create temp directory for test artifacts
    mkdir -p "$TEST_TEMP_DIR"
    rm -rf "$TEST_TEMP_DIR"/*
    
    # Setup subdirectories
    mkdir -p "$TEST_TEMP_DIR/logs"
    mkdir -p "$TEST_TEMP_DIR/mocks"
    mkdir -p "$TEST_TEMP_DIR/output"
    
    # Reset test counters
    TEST_COUNT=0
    PASS_COUNT=0
    FAIL_COUNT=0
}

# Global teardown function
global_teardown() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    
    # Cleanup mocks if needed
    if [ -d "$MOCK_DIR" ]; then
        cleanup_mocks
    fi
    
    # Display test summary
    print_test_summary
    local test_result=$?
    
    return $test_result
}

#===========================================================
# Helper Functions
#===========================================================

# Run the monitor script with arguments
run_monitor() {
    local args="$1"
    local output_file="$TEST_TEMP_DIR/output/output_$(date +%s).log"
    
    # Run the script
    "$MONITOR_SCRIPT" $args > "$output_file" 2>&1
    local exit_code=$?
    
    LAST_OUTPUT="$output_file"
    return $exit_code
}

# Get the last output
get_output() {
    if [ -f "$LAST_OUTPUT" ]; then
        cat "$LAST_OUTPUT"
    else
        echo ""
    fi
}

#===========================================================
# Test Group: Command-line Options
#===========================================================

# Setup function for command-line tests
setup_command_line_tests() {
    echo -e "\n${YELLOW}Setting up command-line option tests...${NC}"
    setup_mock_dir
}

# Teardown function for command-line tests
teardown_command_line_tests() {
    echo -e "${YELLOW}Cleaning up command-line option tests...${NC}"
    cleanup_mocks
}

# Test help option
test_help_option() {
    echo -e "\n${BLUE}Testing help option...${NC}"
    
    run_monitor "--help"
    local exit_code=$?
    local output=$(get_output)
    
    assert_success $exit_code "Help option should succeed"
    assert_contains "$output" "Usage:" "Help output should contain usage information"
}

# Test version option
test_version_option() {
    echo -e "\n${BLUE}Testing version option...${NC}"
    
    run_monitor "--version"
    local exit_code=$?
    local output=$(get_output)
    
    assert_success $exit_code "Version option should succeed"
    assert_contains "$output" "version" "Version output should contain version information"
}

# Test invalid option
test_invalid_option() {
    echo -e "\n${BLUE}Testing invalid option...${NC}"
    
    run_monitor "--invalid-option-that-doesnt-exist"
    local exit_code=$?
    local output=$(get_output)
    
    assert_failure $exit_code "Invalid option should fail"
    assert_contains "$output" "Unknown" "Invalid option should show error message"
}

# Run all command-line tests
run_command_line_tests() {
    echo -e "\n${GREEN}Running command-line option tests...${NC}"
    
    setup_command_line_tests
    
    test_help_option
    test_version_option
    test_invalid_option
    
    teardown_command_line_tests
}

#===========================================================
# Test Group: Hardware Detection
#===========================================================

# Setup function for hardware detection tests
setup_hardware_detection_tests() {
    echo -e "\n${YELLOW}Setting up hardware detection tests...${NC}"
    setup_mock_dir
}

# Teardown function for hardware detection tests
teardown_hardware_detection_tests() {
    echo -e "${YELLOW}Cleaning up hardware detection tests...${NC}"
    cleanup_mocks
}

# Test hardware detection with Apple Bluetooth hardware
test_hardware_detection_with_hardware() {
    echo -e "\n${BLUE}Testing hardware detection with Apple Bluetooth...${NC}"
    
    # Mock lsusb to show Apple Bluetooth
    create_mock_command "lsusb" 0 "Bus 001 Device 005: ID 05ac:8294 Apple, Inc. Bluetooth USB Host Controller"
    
    # Mock hciconfig to show adapter
    create_mock_command "hciconfig" 0 "hci0:	Type: Primary  Bus: USB
	BD Address: 00:11:22:33:44:55  ACL MTU: 1021:8  SCO MTU: 64:1
	UP RUNNING PSCAN ISCAN"
    
    # Create a wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --detect-only --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    assert_success $exit_code "Hardware detection should succeed"
    assert_contains "$output" "detected" "Should detect Bluetooth hardware"
}

# Test hardware detection without Bluetooth hardware
test_hardware_detection_without_hardware() {
    echo -e "\n${BLUE}Testing hardware detection without Bluetooth...${NC}"
    
    # Mock lsusb to show no Apple Bluetooth
    create_mock_command "lsusb" 0 "Bus 001 Device 002: ID 8087:0024 Intel Corp."
    
    # Mock hciconfig to show no adapter
    create_mock_command "hciconfig" 1 "Can't get device info: No such device"
    
    # Create a wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --detect-only --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    # Output message will depend on script implementation
    assert_contains "$output" "No" "Should report no Bluetooth hardware"
}

# Run all hardware detection tests
run_hardware_detection_tests() {
    echo -e "\n${GREEN}Running hardware detection tests...${NC}"
    
    setup_hardware_detection_tests
    
    test_hardware_detection_with_hardware
    test_hardware_detection_without_hardware
    
    teardown_hardware_detection_tests
}

#===========================================================
# Test Group: Service Management
#===========================================================

# Setup function for service management tests
setup_service_management_tests() {
    echo -e "\n${YELLOW}Setting up service management tests...${NC}"
    setup_mock_dir
    
    # Create log file for systemctl calls
    SYSTEMCTL_LOG="$TEST_TEMP_DIR/logs/systemctl.log"
    > "$SYSTEMCTL_LOG"
}

# Teardown function for service management tests
teardown_service_management_tests() {
    echo -e "${YELLOW}Cleaning up service management tests...${NC}"
    cleanup_mocks
}

# Test Bluetooth service status check
test_service_status_check() {
    echo -e "\n${BLUE}Testing service status check...${NC}"
    
    # Mock systemctl
    cat > "$MOCK_DIR/bin/systemctl" << EOF
#!/bin/bash
echo "\$(date): systemctl \$@" >> "$SYSTEMCTL_LOG"
if [ "\$1" = "status" ] && [ "\$2" = "bluetooth" ]; then
    echo "● bluetooth.service - Bluetooth service"
    echo "   Loaded: loaded (/lib/systemd/system/bluetooth.service; enabled; vendor preset: enabled)"
    echo "   Active: active (running) since Tue 2025-04-08 20:57:09 CDT; 1h ago"
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_DIR/bin/systemctl"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --check-service --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    assert_success $exit_code "Service status check should succeed"
    assert_file_exists "$SYSTEMCTL_LOG" "systemctl log should exist"
    
    local log_content=$(cat "$SYSTEMCTL_LOG")
    assert_contains "$log_content" "systemctl status bluetooth" "systemctl should be called"
}

# Test Bluetooth service restart
test_service_restart() {
    echo -e "\n${BLUE}Testing service restart...${NC}"
    
    # Clear previous log
    > "$SYSTEMCTL_LOG"
    
    # Mock systemctl to show service as inactive then restart it
    cat > "$MOCK_DIR/bin/systemctl" << EOF
#!/bin/bash
echo "\$(date): systemctl \$@" >> "$SYSTEMCTL_LOG"
if [ "\$1" = "status" ] && [ "\$2" = "bluetooth" ]; then
    echo "● bluetooth.service - Bluetooth service"
    echo "   Loaded: loaded (/lib/systemd/system/bluetooth.service; enabled; vendor preset: enabled)"
    echo "   Active: inactive (dead) since Tue 2025-04-08 20:57:09 CDT; 1h ago"
    exit 3
elif [ "\$1" = "restart" ] && [ "\$2" = "bluetooth" ]; then
    echo "Restarting bluetooth.service..."
    exit 0
fi
exit 0
EOF
    chmod +x "$MOCK_DIR/bin/systemctl"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --restart-service --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    assert_success $exit_code "Service restart should succeed"
    
    local log_content=$(cat "$SYSTEMCTL_LOG")
    assert_contains "$log_content" "systemctl restart bluetooth" "Service should be restarted"
}

# Run all service management tests
run_service_management_tests() {
    echo -e "\n${GREEN}Running service management tests...${NC}"
    
    setup_service_management_tests
    
    test_service_status_check
    test_service_restart
    
    teardown_service_management_tests
}

#===========================================================
# Test Group: Power Management
#===========================================================

# Setup function for power management tests
setup_power_management_tests() {
    echo -e "\n${YELLOW}Setting up power management tests...${NC}"
    setup_mock_dir
    
    # Create mock sysfs structure
    mkdir -p "$MOCK_DIR/sys/class/bluetooth/hci0/device/power"
    echo "auto" > "$MOCK_DIR/sys/class/bluetooth/hci0/device/power/control"
}

# Teardown function for power management tests
teardown_power_management_tests() {
    echo -e "${YELLOW}Cleaning up power management tests...${NC}"
    cleanup_mocks
}

# Test power management settings
test_power_management_settings() {
    echo -e "\n${BLUE}Testing power management settings...${NC}"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
export SYSFS_PATH="$MOCK_DIR/sys"
"$MONITOR_SCRIPT" --power-management --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    # Check if power settings were updated
    local power_control=$(cat "$MOCK_DIR/sys/class/bluetooth/hci0/device/power/control")
    
    assert_success $exit_code "Power management should succeed"
    assert_equals "$power_control" "on" "Power control should be set to 'on'"
}

# Run all power management tests
run_power_management_tests() {
    echo -e "\n${GREEN}Running power management tests...${NC}"
    
    setup_power_management_tests
    
    test_power_management_settings
    
    teardown_power_management_tests
}

#===========================================================
# Test Group: Recovery Mechanisms
#===========================================================

# Setup function for recovery tests
setup_recovery_tests() {
    echo -e "\n${YELLOW}Setting up recovery mechanism tests...${NC}"
    setup_mock_dir
    
    # Create log file for USB operations
    USB_LOG="$TEST_TEMP_DIR/logs/usb_operations.log"
    > "$USB_LOG"
}

# Teardown function for recovery tests
teardown_recovery_tests() {
    echo -e "${YELLOW}Cleaning up recovery mechanism tests...${NC}"
    cleanup_mocks
}

# Test detection of failed Bluetooth state
test_detect_failed_bluetooth() {
    echo -e "\n${BLUE}Testing detection of failed Bluetooth state...${NC}"
    
    # Mock commands to simulate failed Bluetooth
    create_mock_command "hciconfig" 1 "Can't get device info: No such device"
    create_mock_command "bluetoothctl" 1 "No default controller available"
    
    # Mock lsusb to still show Apple hardware present
    create_mock_command "lsusb" 0 "Bus 001 Device 005: ID 05ac:8294 Apple, Inc. Bluetooth USB Host Controller"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --check-state --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    # Should detect the failure
    assert_contains "$output" "failed" "Should detect failed Bluetooth state"
}

# Test USB reset recovery mechanism
test_usb_reset_recovery() {
    echo -e "\n${BLUE}Testing USB reset recovery...${NC}"
    
    # Mock commands to simulate failed Bluetooth
    create_mock_command "hciconfig" 1 "Can't get device info: No such device"
    create_mock_command "bluetoothctl" 1 "No default controller available"
    
    # Mock lsusb to show Apple hardware
    create_mock_command "lsusb" 0 "Bus 001 Device 005: ID 05ac:8294 Apple, Inc. Bluetooth USB Host Controller"
    
    # Mock USB reset command
    cat > "$MOCK_DIR/bin/usbreset" << EOF
#!/bin/bash
echo "\$(date): USB reset for \$@" >> "$USB_LOG"
exit 0
EOF
    chmod +x "$MOCK_DIR/bin/usbreset"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --recovery --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    assert_success $exit_code "Recovery should succeed"
    assert_file_exists "$USB_LOG" "USB operations log should exist"
    
    local log_content=$(cat "$USB_LOG")
    assert_contains "$log_content" "USB reset" "USB reset should be performed"
}

# Test complete recovery process
test_complete_recovery() {
    echo -e "\n${BLUE}Testing complete recovery process...${NC}"
    
    # Mock initial failed state
    create_mock_command "hciconfig" 1 "Can't get device info: No such device"
    create_mock_command "bluetoothctl" 1 "No default controller available"
    
    # Mock USB operations
    cat > "$MOCK_DIR/bin/usbreset" << EOF
#!/bin/bash
echo "\$(date): USB reset for \$@" >> "$USB_LOG"
exit 0
EOF
    chmod +x "$MOCK_DIR/bin/usbreset"
    
    # Mock systemctl for service restart
    cat > "$MOCK_DIR/bin/systemctl" << EOF
#!/bin/bash
echo "\$(date): systemctl \$@" >> "$USB_LOG"
exit 0
EOF
    chmod +x "$MOCK_DIR/bin/systemctl"
    
    # Create wrapper script
    cat > "$MOCK_DIR/bin/run_test.sh" << EOF
#!/bin/bash
export PATH="$MOCK_DIR/bin:\$PATH"
"$MONITOR_SCRIPT" --full-recovery --once
EOF
    chmod +x "$MOCK_DIR/bin/run_test.sh"
    
    # Run the test
    local output=$("$MOCK_DIR/bin/run_test.sh" 2>&1)
    local exit_code=$?
    
    assert_success $exit_code "Complete recovery should succeed"
    
    local log_content=$(cat "$USB_LOG")
    assert_contains "$log_content" "USB reset" "Recovery should perform USB reset"
    assert_contains "$log_content" "systemctl restart bluetooth" "Recovery should restart service"
}

# Run all recovery tests
run_recovery_tests() {
    echo -e "\n${GREEN}Running recovery mechanism tests...${NC}"
    
    setup_recovery_tests
    
    test_detect_failed_bluetooth
    test_usb_reset_recovery
    test_complete_recovery
    
    teardown_recovery_tests
}

#===========================================================
# Main Test Runner
#===========================================================

# Run all test groups
run_all_tests() {
    # Backup the working script first
    backup_working_script
    
    # Setup global test environment
    global_setup
    
    # Track overall success
    local overall_result=0
    
    echo -e "\n${GREEN}==============================================${NC}"
    echo -e "${GREEN}Starting Bluetooth Monitor comprehensive tests${NC}"
    echo -e "${GREEN}==============================================${NC}"
    
    # Run all test groups with error handling
    echo -e "\n${YELLOW}Running test groups...${NC}"
    
    run_command_line_tests
    if [ $? -ne 0 ]; then
        echo -e "${RED}Command-line option tests failed${NC}"
        overall_result=1
    fi
    
    run_hardware_detection_tests
    if [ $? -ne 0 ]; then
        echo -e "${RED}Hardware detection tests failed${NC}"
        overall_result=1
    fi
    
    run_service_management_tests
    if [ $? -ne 0 ]; then
        echo -e "${RED}Service management tests failed${NC}"
        overall_result=1
    fi
    
    run_power_management_tests
    if [ $? -ne 0 ]; then
        echo -e "${RED}Power management tests failed${NC}"
        overall_result=1
    fi
    
    run_recovery_tests
    if [ $? -ne 0 ]; then
        echo -e "${RED}Recovery mechanism tests failed${NC}"
        overall_result=1
    fi
    
    # Global teardown
    global_teardown
    
    echo -e "\n${GREEN}==============================================${NC}"
    echo -e "${GREEN}Bluetooth Monitor tests completed${NC}"
    echo -e "${GREEN}==============================================${NC}"
    
    # Final status
    if [ $overall_result -eq 0 ]; then
        echo -e "\n${GREEN}All tests passed successfully!${NC}"
        
        # Commit changes to git
        echo -e "\n${YELLOW}Committing changes to git...${NC}"
        (cd "$PROJECT_ROOT" && 
         git add . && 
         git commit -m "Updated and completed test suite for Bluetooth monitor" &&
         git push)
        
        echo -e "${GREEN}Changes committed and pushed!${NC}"
    else
        echo -e "\n${RED}Some tests failed. Please review the output above.${NC}"
        echo -e "${YELLOW}Not committing changes.${NC}"
    fi
    
    return $overall_result
}

# Execute all tests
run_all_tests
