#!/bin/bash
#
# Test script to verify development environment setup
# Tests the functionality of the development environment configuration and scripts

set -e

# Establish the project root as an anchor point for all relative paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_DIR="${PROJECT_ROOT}"
CONFIG_DIR="${NGINX_DIR}/config"
DEV_ENV_DIR="${CONFIG_DIR}/environments/development"
SCRIPTS_DIR="${NGINX_DIR}/scripts"
DEV_SCRIPT="${SCRIPTS_DIR}/dev/dev-workflow.sh"

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

echo -e "${BLUE}Starting development environment tests...${NC}"
echo

# Test 1: Check if development workflow script exists
run_test "Development workflow script exists" "test -f \"${DEV_SCRIPT}\""

# Test 2: Check if development workflow script is executable
run_test "Development workflow script is executable" "test -x \"${DEV_SCRIPT}\""

# Test 3: Check if development environment configuration exists
run_test "Development environment configuration exists" "test -f \"${DEV_ENV_DIR}/env.conf\""

# Test 4: Check if nginx.conf exists
run_test "Nginx configuration file exists" "test -f \"${DEV_ENV_DIR}/nginx.conf\""

# Test 5: Check if nginx configuration is valid
run_test "Nginx configuration is valid" "nginx -t -c \"${DEV_ENV_DIR}/nginx.conf\" > /dev/null 2>&1" 

# Test 6: Check development workflow script help
run_test "Development workflow script help works" "\"${DEV_SCRIPT}\" --help > /dev/null 2>&1" 1

# Test 7: Check if script can setup DNS configuration
run_test "DNS setup creates configuration file" "
  # Mock dnsmasq command to avoid actual execution
  function dnsmasq { 
    echo 'Mocked dnsmasq'; 
    return 0; 
  }
  export -f dnsmasq
  
  # Run the script with DNS setup and check if config file is created
  \"${DEV_SCRIPT}\" --setup-dns > /dev/null 2>&1 || true
  test -f \"${SCRIPTS_DIR}/dev/dnsmasq.conf\"
"

# Test 8: Check if script can setup certificates
run_test "Certificate setup creates certificate files" "
  # Mock openssl command to avoid actual execution
  function openssl { 
    echo 'Mocked openssl'; 
    return 0; 
  }
  export -f openssl
  
  # Run the script with certificate setup
  \"${DEV_SCRIPT}\" --setup-certs > /dev/null 2>&1 || true
  
  # Check if directory was created
  test -d \"${NGINX_DIR}/certs\"
"

# Test 9: Check if hot reload functionality works
run_test "Hot reload functionality" "
  # Mock inotifywait command
  function inotifywait { 
    echo 'Mocked inotifywait'; 
    return 0; 
  }
  export -f inotifywait
  
  # Mock nginx command
  function nginx { 
    echo 'Mocked nginx'; 
    return 0; 
  }
  export -f nginx
  
  # Run the watch command with a timeout to avoid infinite loop
  timeout 1s \"${DEV_SCRIPT}\" --watch > /dev/null 2>&1 || test \$? -eq 124
"

# Print test summary
print_summary 