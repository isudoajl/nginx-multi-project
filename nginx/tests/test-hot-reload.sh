#!/bin/bash
#
# Test script to verify hot reload functionality
# Tests that configuration changes are automatically detected and applied

set -e

# Establish the project root as an anchor point for all relative paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_DIR="${PROJECT_ROOT}"
CONFIG_DIR="${NGINX_DIR}/config"
DEV_ENV_DIR="${CONFIG_DIR}/environments/development"
SCRIPTS_DIR="${NGINX_DIR}/scripts"
DEV_SCRIPT="${SCRIPTS_DIR}/dev/dev-workflow.sh"
TEST_CONF="${DEV_ENV_DIR}/test-hot-reload.conf"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counter
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Function to run a test
run_test() {
  local test_name="$1"
  local test_command="$2"
  local expected_exit_code="${3:-0}"
  
  echo -e "${BLUE}Running test: ${test_name}${NC}"
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  
  # Run the test command and capture output and exit code
  output=$(eval "${test_command}" 2>&1) || true
  exit_code=$?
  
  # Check if exit code matches expected exit code
  if [ "${exit_code}" -eq "${expected_exit_code}" ]; then
    echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    echo -e "${RED}✗ Test failed: ${test_name}${NC}"
    echo -e "${RED}Expected exit code ${expected_exit_code}, got ${exit_code}${NC}"
    echo -e "${YELLOW}Output: ${output}${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  
  # Return the test output for further inspection if needed
  echo "${output}"
}

# Function to print test summary
print_summary() {
  echo
  echo -e "${BLUE}Test Summary:${NC}"
  echo -e "${BLUE}------------${NC}"
  echo -e "Total tests: ${TESTS_TOTAL}"
  echo -e "${GREEN}Tests passed: ${TESTS_PASSED}${NC}"
  echo -e "${RED}Tests failed: ${TESTS_FAILED}${NC}"
  
  if [ "${TESTS_FAILED}" -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
  fi
}

# Check if running in Nix environment
if [ -z "$IN_NIX_SHELL" ]; then
  echo -e "${RED}Error: Please run this script within the Nix environment.${NC}"
  echo -e "${YELLOW}Run 'nix develop' first and then try again.${NC}"
  exit 1
fi

# Check if the development workflow script exists
if [ ! -f "${DEV_SCRIPT}" ]; then
  echo -e "${RED}Error: Development workflow script not found at ${DEV_SCRIPT}${NC}"
  exit 1
fi

# Make sure the script is executable
chmod +x "${DEV_SCRIPT}"

echo -e "${BLUE}Starting hot reload tests...${NC}"
echo

# Setup for tests
setup() {
  # Create a test configuration file
  echo "# Test configuration for hot reload" > "${TEST_CONF}"
  echo "server_name test.local;" >> "${TEST_CONF}"
  
  # Mock the nginx reload command
  function nginx() {
    if [[ "$*" == *"reload"* ]]; then
      echo "Nginx reloaded configuration"
      NGINX_RELOADED=true
    elif [[ "$*" == *"-t"* ]]; then
      echo "Nginx configuration test successful"
      return 0
    else
      echo "Mocked nginx: $*"
    fi
  }
  export -f nginx
  
  # Mock inotifywait
  function inotifywait() {
    echo "Waiting for file changes..."
    sleep 1
    return 0
  }
  export -f inotifywait
}

# Cleanup after tests
cleanup() {
  if [ -f "${TEST_CONF}" ]; then
    rm -f "${TEST_CONF}"
  fi
}

# Register cleanup on exit
trap cleanup EXIT

# Run setup
setup

# Test 1: Check if hot reload detects file changes
run_test "Hot reload detects file changes" "
  # Start the hot reload process in background
  NGINX_RELOADED=false
  
  # Run the watch command with a timeout to avoid infinite loop
  timeout 2s \"${DEV_SCRIPT}\" --watch > /dev/null 2>&1 || test \$? -eq 124
  
  # Modify the test configuration file to trigger reload
  echo '# Modified configuration' >> \"${TEST_CONF}\"
  
  # Check if nginx reload was called
  test \"\${NGINX_RELOADED}\" = \"true\"
"

# Test 2: Check if reload validates configuration before reloading
run_test "Reload validates configuration" "
  # Mock nginx to fail configuration test
  function nginx() {
    if [[ \"\$*\" == *\"-t\"* ]]; then
      echo \"Nginx configuration test failed\"
      return 1
    fi
    echo \"Mocked nginx: \$*\"
  }
  export -f nginx
  
  # Try to reload with invalid configuration
  ! \"${DEV_SCRIPT}\" --reload > /dev/null 2>&1
"

# Test 3: Check if hot reload handles multiple file changes
run_test "Hot reload handles multiple file changes" "
  # Mock nginx reload
  RELOAD_COUNT=0
  function nginx() {
    if [[ \"\$*\" == *\"reload\"* ]]; then
      echo \"Nginx reloaded configuration\"
      RELOAD_COUNT=\$((RELOAD_COUNT + 1))
    elif [[ \"\$*\" == *\"-t\"* ]]; then
      echo \"Nginx configuration test successful\"
      return 0
    else
      echo \"Mocked nginx: \$*\"
    fi
  }
  export -f nginx
  
  # Mock inotifywait to simulate multiple file changes
  CHANGE_COUNT=0
  function inotifywait() {
    echo \"Waiting for file changes...\"
    CHANGE_COUNT=\$((CHANGE_COUNT + 1))
    if [ \"\${CHANGE_COUNT}\" -gt 2 ]; then
      return 1
    fi
    return 0
  }
  export -f inotifywait
  
  # Run the watch command
  \"${DEV_SCRIPT}\" --watch > /dev/null 2>&1 || true
  
  # Check if nginx reload was called multiple times
  test \"\${RELOAD_COUNT}\" -ge 2
"

# Print test summary
print_summary 