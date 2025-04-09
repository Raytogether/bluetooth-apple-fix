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
