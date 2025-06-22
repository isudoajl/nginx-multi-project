#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_DOMAIN="test-domain.local"
TEST_OUTPUT_DIR="${PROJECT_ROOT}/tests/temp/certs"
GENERATE_CERTS_SCRIPT="${PROJECT_ROOT}/scripts/generate-certs.sh"

# Create test output directory
mkdir -p "${TEST_OUTPUT_DIR}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function: Display test header
function display_header() {
  echo -e "\n${YELLOW}=======================================${NC}"
  echo -e "${YELLOW}   Testing Certificate Generation Script   ${NC}"
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

# Function: Check if file exists and has expected permissions
function check_file() {
  local file_path="$1"
  local expected_perms="$2"
  
  if [ ! -f "$file_path" ]; then
    echo -e "${RED}✗ File not found: $file_path${NC}"
    return 1
  fi
  
  local actual_perms=$(stat -c "%a" "$file_path")
  if [ "$actual_perms" != "$expected_perms" ]; then
    echo -e "${RED}✗ Wrong permissions: $file_path (Expected: $expected_perms, Got: $actual_perms)${NC}"
    return 1
  fi
  
  echo -e "${GREEN}✓ File exists with correct permissions: $file_path${NC}"
  return 0
}

# Function: Clean up test files
function cleanup() {
  echo -e "\n${YELLOW}Cleaning up test files...${NC}"
  rm -rf "${TEST_OUTPUT_DIR}"
  mkdir -p "${TEST_OUTPUT_DIR}"
}

# Set Nix environment variable for testing
export IN_NIX_SHELL=1

# Main test execution
display_header
cleanup

# Test 1: Help message
run_test "Help message" "${GENERATE_CERTS_SCRIPT} --help" 0

# Test 2: Missing required parameters
run_test "Missing domain parameter" "${GENERATE_CERTS_SCRIPT} --output ${TEST_OUTPUT_DIR}" 1
run_test "Missing output parameter" "${GENERATE_CERTS_SCRIPT} --domain ${TEST_DOMAIN}" 1

# Test 3: Invalid domain format
run_test "Invalid domain format" "${GENERATE_CERTS_SCRIPT} --domain invalid-domain --output ${TEST_OUTPUT_DIR}" 1

# Test 4: Invalid environment type
run_test "Invalid environment type" "${GENERATE_CERTS_SCRIPT} --domain ${TEST_DOMAIN} --output ${TEST_OUTPUT_DIR} --env INVALID" 1

# Test 5: Generate DEV certificate
run_test "Generate DEV certificate" "${GENERATE_CERTS_SCRIPT} --domain ${TEST_DOMAIN} --output ${TEST_OUTPUT_DIR} --env DEV" 0

# Check if DEV certificate files exist with correct permissions
check_file "${TEST_OUTPUT_DIR}/cert.pem" "644"
check_file "${TEST_OUTPUT_DIR}/cert-key.pem" "600"
check_file "${TEST_OUTPUT_DIR}/openssl.cnf" "644"

# Test 6: Generate PRO certificate request
cleanup
run_test "Generate PRO certificate request" "${GENERATE_CERTS_SCRIPT} --domain ${TEST_DOMAIN} --output ${TEST_OUTPUT_DIR} --env PRO" 0

# Check if PRO certificate files exist with correct permissions
check_file "${TEST_OUTPUT_DIR}/cert.csr" "644"
check_file "${TEST_OUTPUT_DIR}/cert-key.pem" "600"
check_file "${TEST_OUTPUT_DIR}/openssl.cnf" "644"

# Test 7: Custom days parameter
cleanup
run_test "Custom days parameter" "${GENERATE_CERTS_SCRIPT} --domain ${TEST_DOMAIN} --output ${TEST_OUTPUT_DIR} --days 30" 0

# Final cleanup
cleanup

echo -e "\n${GREEN}All tests completed!${NC}"
exit 0 