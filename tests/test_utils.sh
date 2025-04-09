#!/bin/bash

# Test utilities and helper functions for run_tests.sh

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Mock directory
MOCK_DIR=""

# Function to set up the mock directory
setup_mock_dir() {
    MOCK_DIR=$(mktemp -d)
    echo "Mock directory set up at $MOCK_DIR"
    
    # Set up bin directory for mock commands
    mkdir -p "$MOCK_DIR/bin"
    
    # Add the mock directory to PATH inside the function
    export PATH="$MOCK_DIR/bin:$PATH"
}

# Function to clean up the mock directory
cleanup_mocks() {
    if [ -n "$MOCK_DIR" ] && [ -d "$MOCK_DIR" ]; then
        rm -rf "$MOCK_DIR"
        echo "Cleaned up mock directory"
    fi
}

# Function to create a mock command
create_mock_command() {
    local command=$1
    local exit_code=$2
    local output=$3
    
    # Create the mock command script
    cat > "$MOCK_DIR/bin/$command" << EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    chmod +x "$MOCK_DIR/bin/$command"
    
    echo "Created mock for command: $command"
}

# Function to assert equality
assert_equals() {
    ((TEST_COUNT++))
    if [ "$1" = "$2" ]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${3:-Test passed}"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ ${3:-Test failed} (got '$1', expected '$2')${NC}"
        return 1
    fi
    return 0
}

# Function to assert inequality
assert_not_equals() {
    ((TEST_COUNT++))
    if [ "$1" != "$2" ]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${3:-Test passed}"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ ${3:-Test failed} (got '$1', expected not '$2')${NC}"
        return 1
    fi
    return 0
}

# Function to assert command success
assert_success() {
    ((TEST_COUNT++))
    if [ "$1" -eq 0 ]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${2:-Command should succeed}"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ ${2:-Command should succeed} (exit code: $1)${NC}"
        return 1
    fi
    return 0
}

# Function to assert command failure
assert_failure() {
    ((TEST_COUNT++))
    if [ "$1" -ne 0 ]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${2:-Command should fail} (exit code: $1)"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ Expected failure test passed (got exit code $1, expected ${2:-Command should fail})${NC}"
        return 1
    fi
    return 0
}

# Function to assert string contains substring
assert_contains() {
    ((TEST_COUNT++))
    if [[ "$1" == *"$2"* ]]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${3:-String contains expected substring}"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ ${3:-String does not contain expected substring} (string does not contain '$2')${NC}"
        return 1
    fi
    return 0
}

# Function to assert file exists
assert_file_exists() {
    ((TEST_COUNT++))
    if [ -f "$1" ]; then
        ((PASS_COUNT++))
        echo -e "${GREEN}✓ ${NC}${2:-File exists}"
    else
        ((FAIL_COUNT++))
        echo -e "${RED}✗ ${2:-File does not exist} ($1)${NC}"
        return 1
    fi
    return 0
}

# Function to print test summary
print_test_summary() {
    echo -e "\nTests passed: $PASS_COUNT"
    echo -e "Tests failed: $FAIL_COUNT"
    echo -e "Total tests: $TEST_COUNT"
    
    if [ $FAIL_COUNT -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

#!/bin/bash

# Test utilities for Bluetooth Monitor testing

# Colors for better readability
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Global variables for test tracking
TEST_COUNT=0
PASS_COUNT=0
FAIL_COUNT=0

# Enhanced assertion utilities
assert_success() {
    local exit_code=$1
    local message=${2:-"Test passed"}
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓ $message${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}✗ $message (got exit code $exit_code, expected 0)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_failure() {
    local exit_code=$1
    local expected_code=${2:-1}
    local message=${3:-"Expected failure test passed"}
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ $exit_code -eq $expected_code ]; then
        echo -e "${GREEN}✓ $message (got expected exit code $exit_code)${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}✗ $message (got exit code $exit_code, expected $expected_code)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# Additional assertion types
assert_equals() {
    local actual="$1"
    local expected="$2"
    local message=${3:-"Values should be equal"}
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ "$actual" = "$expected" ]; then
        echo -e "${GREEN}✓ $message${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}✗ $message (got '$actual', expected '$expected')${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message=${3:-"String should contain substring"}
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓ $message${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}✗ $message (string does not contain '$needle')${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message=${2:-"File should exist"}
    
    TEST_COUNT=$((TEST_COUNT + 1))
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓ $message${NC}"
        PASS_COUNT=$((PASS_COUNT + 1))
        return 0
    else
        echo -e "${RED}✗ $message (file '$file' does not exist)${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        return 1
    fi
}

# Basic mocking utilities
setup_mock_dir() {
    # Create a temporary directory for mocks
    MOCK_DIR=$(mktemp -d)
    mkdir -p "$MOCK_DIR/bin"
    export PATH="$MOCK_DIR/bin:$PATH"
    echo -e "${YELLOW}Mock directory set up at $MOCK_DIR${NC}"
}

create_mock_command() {
    local command="$1"
    local exit_code="${2:-0}"
    local output="$3"
    
    cat > "$MOCK_DIR/bin/$command" << EOF
#!/bin/bash
echo "$output"
exit $exit_code
EOF
    
    chmod +x "$MOCK_DIR/bin/$command"
    echo -e "${YELLOW}Created mock for command: $command${NC}"
}

cleanup_mocks() {
    # Remove the mock directory
    if [ -d "$MOCK_DIR" ]; then
        rm -rf "$MOCK_DIR"
        echo -e "${YELLOW}Cleaned up mock directory${NC}"
    fi
}

# Function to print test summary
print_test_summary() {
    echo
    echo -e "${GREEN}Tests passed: $PASS_COUNT${NC}"
    echo -e "${RED}Tests failed: $FAIL_COUNT${NC}"
    echo -e "Total tests: $TEST_COUNT"
    
    # Return failure if any tests failed
    [ $FAIL_COUNT -eq 0 ]
    return $?
}
