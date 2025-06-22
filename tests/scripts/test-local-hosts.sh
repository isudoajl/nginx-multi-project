#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_DOMAIN="test-domain.local"
UPDATE_HOSTS_SCRIPT="${PROJECT_ROOT}/scripts/update-hosts.sh"
MOCK_HOSTS_FILE="${PROJECT_ROOT}/tests/temp/hosts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create test directory
mkdir -p "${PROJECT_ROOT}/tests/temp"

# Function: Display test header
function display_header() {
  echo -e "\n${YELLOW}=======================================${NC}"
  echo -e "${YELLOW}   Testing Local Hosts Update Script   ${NC}"
  echo -e "${YELLOW}=======================================${NC}\n"
}

# Function: Run a test case
function run_test() {
  local test_name="$1"
  local test_cmd="$2"
  local expected_exit_code="$3"
  
  echo -e "\n${YELLOW}Test: ${test_name}${NC}"
  echo "Command: $test_cmd"
  
  # Run the command and capture exit code
  eval "$test_cmd"
  local actual_exit_code=$?
  
  # Check if exit code matches expected
  if [ $actual_exit_code -eq $expected_exit_code ]; then
    echo -e "${GREEN}✓ Test passed (Exit code: $actual_exit_code)${NC}"
    return 0
  else
    echo -e "${RED}✗ Test failed (Expected: $expected_exit_code, Got: $actual_exit_code)${NC}"
    return 1
  fi
}

# Function: Create mock hosts file
function create_mock_hosts_file() {
  cat > "${MOCK_HOSTS_FILE}" << EOF
127.0.0.1 localhost
::1 localhost ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters

# Some existing entries
192.168.1.100 existing-domain.com
EOF
}

# Function: Check if domain exists in hosts file
function check_domain_exists() {
  local domain="$1"
  local ip="$2"
  local marker="# NGINX-MULTI-PROJECT"
  
  if grep -q "$ip $domain $marker" "${MOCK_HOSTS_FILE}"; then
    echo -e "${GREEN}✓ Domain $domain found with IP $ip${NC}"
    return 0
  else
    echo -e "${RED}✗ Domain $domain not found with IP $ip${NC}"
    return 1
  fi
}

# Function: Check if domain does not exist in hosts file
function check_domain_not_exists() {
  local domain="$1"
  local marker="# NGINX-MULTI-PROJECT"
  
  if grep -q "$domain $marker" "${MOCK_HOSTS_FILE}"; then
    echo -e "${RED}✗ Domain $domain found but should not exist${NC}"
    return 1
  else
    echo -e "${GREEN}✓ Domain $domain correctly not found${NC}"
    return 0
  fi
}

# Function: Clean up test files
function cleanup() {
  echo -e "\n${YELLOW}Cleaning up test files...${NC}"
  rm -f "${MOCK_HOSTS_FILE}"
  create_mock_hosts_file
}

# Set Nix environment variable for testing
export IN_NIX_SHELL=1

# Mock the check_root function for testing
function mock_update_hosts_script() {
  local temp_script="${PROJECT_ROOT}/tests/temp/update-hosts-mock.sh"
  
  # Create a temporary copy of the script with mocked functions
  cat "${UPDATE_HOSTS_SCRIPT}" > "${temp_script}"
  
  # Replace check_root function to do nothing
  sed -i 's/function check_root() {/function check_root() { return 0;/g' "${temp_script}"
  
  # Replace HOSTS_FILE variable to use our mock file
  sed -i "s|HOSTS_FILE=\"/etc/hosts\"|HOSTS_FILE=\"${MOCK_HOSTS_FILE}\"|g" "${temp_script}"
  
  # Make the script executable
  chmod +x "${temp_script}"
  
  echo "${temp_script}"
}

# Main test execution
display_header
cleanup

# Create mock script
MOCK_SCRIPT=$(mock_update_hosts_script)

# Test 1: Help message
run_test "Help message" "${MOCK_SCRIPT} --help" 0

# Test 2: Missing required parameters
run_test "Missing domain parameter" "${MOCK_SCRIPT} --action add" 1
run_test "Missing action parameter" "${MOCK_SCRIPT} --domain ${TEST_DOMAIN}" 1

# Test 3: Invalid domain format
run_test "Invalid domain format" "${MOCK_SCRIPT} --domain invalid-domain --action add" 1

# Test 4: Invalid action
run_test "Invalid action" "${MOCK_SCRIPT} --domain ${TEST_DOMAIN} --action invalid" 1

# Test 5: Invalid IP format
run_test "Invalid IP format" "${MOCK_SCRIPT} --domain ${TEST_DOMAIN} --action add --ip invalid-ip" 1

# Test 6: Add domain
run_test "Add domain" "${MOCK_SCRIPT} --domain ${TEST_DOMAIN} --action add" 0
check_domain_exists "${TEST_DOMAIN}" "127.0.0.1"
check_domain_exists "www.${TEST_DOMAIN}" "127.0.0.1"

# Test 7: Add domain with custom IP
run_test "Add domain with custom IP" "${MOCK_SCRIPT} --domain custom-ip.local --action add --ip 192.168.1.10" 0
check_domain_exists "custom-ip.local" "192.168.1.10"

# Test 8: Remove domain
run_test "Remove domain" "${MOCK_SCRIPT} --domain ${TEST_DOMAIN} --action remove" 0
check_domain_not_exists "${TEST_DOMAIN}"
check_domain_not_exists "www.${TEST_DOMAIN}"

# Test 9: Remove non-existent domain (should still succeed)
run_test "Remove non-existent domain" "${MOCK_SCRIPT} --domain non-existent.local --action remove" 0

# Clean up
rm -f "${MOCK_SCRIPT}"
rm -f "${MOCK_HOSTS_FILE}"

echo -e "\n${GREEN}All tests completed!${NC}"
exit 0 