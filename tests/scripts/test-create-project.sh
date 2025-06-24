#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_PROJECT="test-project"
TEST_DOMAIN="test-domain.local"
TEST_PORT="9876"
CREATE_PROJECT_SCRIPT="${PROJECT_ROOT}/scripts/create-project-modular.sh"
TEMP_DIR="${PROJECT_ROOT}/tests/temp"
PROJECTS_DIR="${TEMP_DIR}/projects"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create test directories
mkdir -p "${TEMP_DIR}"
mkdir -p "${PROJECTS_DIR}"

# Function: Display test header
function display_header() {
  echo -e "\n${YELLOW}=======================================${NC}"
  echo -e "${YELLOW}   Testing Project Creation Script   ${NC}"
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

# Function: Check if file exists
function check_file_exists() {
  local file_path="$1"
  
  if [ -f "$file_path" ]; then
    echo -e "${GREEN}✓ File exists: $file_path${NC}"
    return 0
  else
    echo -e "${RED}✗ File not found: $file_path${NC}"
    return 1
  fi
}

# Function: Check if directory exists
function check_dir_exists() {
  local dir_path="$1"
  
  if [ -d "$dir_path" ]; then
    echo -e "${GREEN}✓ Directory exists: $dir_path${NC}"
    return 0
  else
    echo -e "${RED}✗ Directory not found: $dir_path${NC}"
    return 1
  fi
}

# Function: Clean up test files
function cleanup() {
  echo -e "\n${YELLOW}Cleaning up test files...${NC}"
  rm -rf "${PROJECTS_DIR}/${TEST_PROJECT}"
}

# Function: Mock the create-project script for testing
function mock_create_project_script() {
  local temp_script="${TEMP_DIR}/create-project-mock.sh"
  
  # Create a temporary copy of the script with mocked functions
  cat "${CREATE_PROJECT_SCRIPT}" > "${temp_script}"
  
  # Replace directory paths
  sed -i "s|PROJECTS_DIR=\"\${PROJECT_ROOT}/projects\"|PROJECTS_DIR=\"${PROJECTS_DIR}\"|g" "${temp_script}"
  
  # Mock validate_environment function
  sed -i '/function validate_environment/,/^}/c\
function validate_environment() {\
  # Mock function for testing\
  CONTAINER_ENGINE="docker"\
  log "Using container engine: $CONTAINER_ENGINE"\
}' "${temp_script}"
  
  # Mock functions that call external scripts
  sed -i 's|"\${SCRIPT_DIR}/generate-certs.sh"|echo "Mock: generate-certs.sh"|g' "${temp_script}"
  sed -i 's|sudo "\${SCRIPT_DIR}/update-hosts.sh"|echo "Mock: update-hosts.sh"|g' "${temp_script}"
  sed -i 's|"\${SCRIPT_DIR}/dev-environment.sh"|echo "Mock: dev-environment.sh"|g' "${temp_script}"
  
  # Mock container commands
  sed -i 's/podman-compose up -d/echo "Mock: podman-compose up -d"/g' "${temp_script}"
  sed -i 's/docker-compose up -d/echo "Mock: docker-compose up -d"/g' "${temp_script}"
  
  # Mock container checks
  sed -i 's/if ! podman ps | grep -q "$container_name"; then/if false; then/g' "${temp_script}"
  sed -i 's/if ! docker ps | grep -q "$container_name"; then/if false; then/g' "${temp_script}"
  
  # Mock curl check
  sed -i 's/if ! curl -s -o \/dev\/null -w "%{http_code}" "http:\/\/localhost:\${PROJECT_PORT}" | grep -q "200"; then/if false; then/g' "${temp_script}"
  
  # Make the script executable
  chmod +x "${temp_script}"
  
  echo "${temp_script}"
}

# Set Nix environment variable for testing
export IN_NIX_SHELL=1

# Main test execution
display_header
cleanup

# Create mock script
MOCK_SCRIPT=$(mock_create_project_script)

# Test 1: Help message
run_test "Help message" "${MOCK_SCRIPT} --help" 0

# Test 2: Missing required parameters
run_test "Missing project name" "${MOCK_SCRIPT} --port ${TEST_PORT} --domain ${TEST_DOMAIN}" 1
run_test "Missing port" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --domain ${TEST_DOMAIN}" 1
run_test "Missing domain" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT}" 1

# Test 3: Invalid parameters
run_test "Invalid project name" "${MOCK_SCRIPT} --name 'invalid project' --port ${TEST_PORT} --domain ${TEST_DOMAIN}" 1
run_test "Invalid port" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port 100 --domain ${TEST_DOMAIN}" 1
run_test "Invalid domain" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT} --domain invalid-domain" 1
run_test "Invalid environment" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT} --domain ${TEST_DOMAIN} --env INVALID" 1

# Test 4: Create project in DEV environment
run_test "Create project in DEV environment" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT} --domain ${TEST_DOMAIN}" 0

# Check if project files were created
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}"
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}/html"
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}/conf.d"
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}/logs"

check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/Dockerfile"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/docker-compose.yml"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/nginx.conf"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/conf.d/security.conf"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/conf.d/compression.conf"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/html/index.html"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/html/404.html"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/html/50x.html"

# Clean up
cleanup

# Test 5: Create project in PRO environment
run_test "Create project in PRO environment" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT} --domain ${TEST_DOMAIN} --env PRO" 0

# Check if project files were created
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}"
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}/certs"

# Test 6: Create project with Cloudflare integration
cleanup
run_test "Create project with Cloudflare integration" "${MOCK_SCRIPT} --name ${TEST_PROJECT} --port ${TEST_PORT} --domain ${TEST_DOMAIN} --env PRO --cf-token test-token --cf-account test-account --cf-zone test-zone" 0

# Check if Cloudflare files were created
check_dir_exists "${PROJECTS_DIR}/${TEST_PROJECT}/cloudflare"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/cloudflare/main.tf"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/cloudflare/variables.tf"
check_file_exists "${PROJECTS_DIR}/${TEST_PROJECT}/cloudflare/terraform.tfvars.example"

# Clean up
cleanup
rm -f "${MOCK_SCRIPT}"

echo -e "\n${GREEN}All tests completed!${NC}"
exit 0 