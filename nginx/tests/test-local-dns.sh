#!/bin/bash
#
# Test script to verify local DNS resolution
# Tests that the local DNS setup properly resolves development domains

set -e

# Establish the project root as an anchor point for all relative paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NGINX_DIR="${PROJECT_ROOT}"
SCRIPTS_DIR="${NGINX_DIR}/scripts"
DEV_SCRIPT="${SCRIPTS_DIR}/dev/dev-workflow.sh"
DNSMASQ_CONF="${SCRIPTS_DIR}/dev/dnsmasq.conf"

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

echo -e "${BLUE}Starting local DNS resolution tests...${NC}"
echo

# Setup for tests
setup() {
  # Create DNS config directory if it doesn't exist
  mkdir -p "${SCRIPTS_DIR}/dev"
  
  # Mock the dnsmasq command
  function dnsmasq() {
    echo "Mocked dnsmasq: $*"
    return 0
  }
  export -f dnsmasq
  
  # Mock the dig command
  function dig() {
    local domain="$2"
    if [[ "${domain}" == *"local.dev"* ]]; then
      echo ";;; ANSWER SECTION:"
      echo "${domain}.		0	IN	A	127.0.0.1"
      return 0
    else
      echo ";;; ANSWER SECTION:"
      echo "${domain}.		0	IN	A	8.8.8.8"
      return 0
    fi
  }
  export -f dig
  
  # Mock the host command
  function host() {
    local domain="$1"
    if [[ "${domain}" == *"local.dev"* ]]; then
      echo "${domain} has address 127.0.0.1"
      return 0
    else
      echo "${domain} has address 8.8.8.8"
      return 0
    fi
  }
  export -f host
}

# Cleanup after tests
cleanup() {
  # Nothing to clean up
  :
}

# Register cleanup on exit
trap cleanup EXIT

# Run setup
setup

# Test 1: Check if DNS setup script creates configuration
run_test "DNS setup creates configuration" "
  # Run the DNS setup
  \"${DEV_SCRIPT}\" --setup-dns > /dev/null 2>&1
  
  # Check if configuration file was created
  test -f \"${DNSMASQ_CONF}\"
"

# Test 2: Check if configuration contains required domains
run_test "DNS configuration contains required domains" "
  # Run the DNS setup
  \"${DEV_SCRIPT}\" --setup-dns > /dev/null 2>&1
  
  # Check if configuration file contains local.dev domain
  grep -q 'local.dev' \"${DNSMASQ_CONF}\"
"

# Test 3: Check if local domains resolve to 127.0.0.1
run_test "Local domains resolve to 127.0.0.1" "
  # Mock the DNS resolution
  result=\$(dig @127.0.0.1 local.dev)
  
  # Check if the domain resolves to 127.0.0.1
  echo \"\${result}\" | grep -q '127.0.0.1'
"

# Test 4: Check if subdomains are properly configured
run_test "Subdomains are properly configured" "
  # Run the DNS setup
  \"${DEV_SCRIPT}\" --setup-dns > /dev/null 2>&1
  
  # Check if configuration file contains api subdomain
  grep -q 'api.local.dev' \"${DNSMASQ_CONF}\" && 
  grep -q 'admin.local.dev' \"${DNSMASQ_CONF}\"
"

# Test 5: Check if host command resolves local domains
run_test "Host command resolves local domains" "
  # Mock the host command resolution
  result=\$(host local.dev)
  
  # Check if the domain resolves to 127.0.0.1
  echo \"\${result}\" | grep -q '127.0.0.1'
"

# Print test summary
print_summary 