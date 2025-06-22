#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TEST_PROJECT="test-project"
DEV_ENV_SCRIPT="${PROJECT_ROOT}/scripts/dev-environment.sh"
TEMP_DIR="${PROJECT_ROOT}/tests/temp"
TEST_PORT="9999"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Create test directories
mkdir -p "${TEMP_DIR}/projects/${TEST_PROJECT}/html"
mkdir -p "${TEMP_DIR}/projects/${TEST_PROJECT}/conf.d"
mkdir -p "${TEMP_DIR}/conf"

# Function: Display test header
function display_header() {
  echo -e "\n${YELLOW}=======================================${NC}"
  echo -e "${YELLOW}   Testing Development Environment Script   ${NC}"
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

# Function: Create mock project files
function create_mock_project() {
  # Create basic docker-compose.yml
  cat > "${TEMP_DIR}/projects/${TEST_PROJECT}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${TEST_PROJECT}:
    image: nginx:alpine
    container_name: ${TEST_PROJECT}
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped

networks:
  ${TEST_PROJECT}-network:
    driver: bridge
EOF

  # Create basic index.html
  cat > "${TEMP_DIR}/projects/${TEST_PROJECT}/html/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Test Project</title>
</head>
<body>
  <h1>Test Project</h1>
  <p>This is a test project for development environment testing.</p>
</body>
</html>
EOF

  # Create Docker Compose override template
  cat > "${TEMP_DIR}/conf/docker-compose.override.dev.yml" << EOF
version: '3.8'

services:
  {project-name}:
    # Development-specific overrides
    volumes:
      # Add volume for live reloading
      - ./html:/usr/share/nginx/html:ro
      # Mount custom development configuration
      - ./conf.d/dev:/etc/nginx/conf.d/dev:ro
    environment:
      # Development environment variables
      - NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates
      - NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/conf.d
      - ENVIRONMENT=development
    # Enable development ports
    ports:
      - "{dev-port}:80"
    # Development-specific healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 5s
    # Development-specific restart policy
    restart: unless-stopped
    # Add development labels
    labels:
      - "dev.environment=true"
      - "dev.project={project-name}"

networks:
  {project-name}-network:
    driver: bridge
    # Development-specific network configuration
    ipam:
      config:
        - subnet: 172.28.{subnet-id}.0/24
EOF
}

# Function: Mock the dev-environment script for testing
function mock_dev_environment_script() {
  local temp_script="${TEMP_DIR}/dev-environment-mock.sh"
  
  # Create a temporary copy of the script with mocked functions
  cat "${DEV_ENV_SCRIPT}" > "${temp_script}"
  
  # Replace directory paths
  sed -i "s|PROJECTS_DIR=\"\${PROJECT_ROOT}/projects\"|PROJECTS_DIR=\"${TEMP_DIR}/projects\"|g" "${temp_script}"
  sed -i "s|CONF_DIR=\"\${PROJECT_ROOT}/conf\"|CONF_DIR=\"${TEMP_DIR}/conf\"|g" "${temp_script}"
  
  # Mock container engine commands
  sed -i 's/podman-compose up -d/echo "Mock: podman-compose up -d"/g' "${temp_script}"
  sed -i 's/docker-compose -f docker-compose.yml -f ${DOCKER_COMPOSE_OVERRIDE} up -d/echo "Mock: docker-compose up -d"/g' "${temp_script}"
  sed -i 's/podman-compose down/echo "Mock: podman-compose down"/g' "${temp_script}"
  sed -i 's/docker-compose -f docker-compose.yml -f ${DOCKER_COMPOSE_OVERRIDE} down/echo "Mock: docker-compose down"/g' "${temp_script}"
  sed -i 's/podman exec -it "${PROJECT_NAME}" nginx -s reload/echo "Mock: podman exec nginx reload"/g' "${temp_script}"
  sed -i 's/docker exec -it "${PROJECT_NAME}" nginx -s reload/echo "Mock: docker exec nginx reload"/g' "${temp_script}"
  
  # Mock container checks
  sed -i 's/if ! podman ps | grep -q "${PROJECT_NAME}"; then/if false; then/g' "${temp_script}"
  sed -i 's/if ! docker ps | grep -q "${PROJECT_NAME}"; then/if false; then/g' "${temp_script}"
  
  # Mock validate_environment function
  sed -i '/function validate_environment/,/^}/c\
function validate_environment() {\
  # Mock function for testing\
  CONTAINER_ENGINE="docker"\
  log "Using container engine: $CONTAINER_ENGINE"\
}' "${temp_script}"
  
  # Make the script executable
  chmod +x "${temp_script}"
  
  echo "${temp_script}"
}

# Function: Clean up test files
function cleanup() {
  echo -e "\n${YELLOW}Cleaning up test files...${NC}"
  rm -rf "${TEMP_DIR}/projects/${TEST_PROJECT}"
  rm -f "${TEMP_DIR}/dev-environment-mock.sh"
}

# Set Nix environment variable for testing
export IN_NIX_SHELL=1

# Main test execution
display_header
create_mock_project

# Create mock script
MOCK_SCRIPT=$(mock_dev_environment_script)

# Test 1: Help message
run_test "Help message" "${MOCK_SCRIPT} --help" 0

# Test 2: Missing required parameters
run_test "Missing project parameter" "${MOCK_SCRIPT} --action setup" 1
run_test "Missing action parameter" "${MOCK_SCRIPT} --project ${TEST_PROJECT}" 1

# Test 3: Invalid action
run_test "Invalid action" "${MOCK_SCRIPT} --project ${TEST_PROJECT} --action invalid" 1

# Test 4: Setup development environment
run_test "Setup development environment" "${MOCK_SCRIPT} --project ${TEST_PROJECT} --action setup --port ${TEST_PORT}" 0

# Check if files were created
if [ -f "${TEMP_DIR}/projects/${TEST_PROJECT}/docker-compose.override.yml" ]; then
  echo -e "${GREEN}✓ Docker Compose override file created${NC}"
else
  echo -e "${RED}✗ Docker Compose override file not created${NC}"
fi

if [ -d "${TEMP_DIR}/projects/${TEST_PROJECT}/conf.d/dev" ]; then
  echo -e "${GREEN}✓ Development configuration directory created${NC}"
else
  echo -e "${RED}✗ Development configuration directory not created${NC}"
fi

if [ -f "${TEMP_DIR}/projects/${TEST_PROJECT}/conf.d/dev/development.conf" ]; then
  echo -e "${GREEN}✓ Development configuration file created${NC}"
else
  echo -e "${RED}✗ Development configuration file not created${NC}"
fi

if [ -f "${TEMP_DIR}/projects/${TEST_PROJECT}/html/health/index.html" ]; then
  echo -e "${GREEN}✓ Health check endpoint created${NC}"
else
  echo -e "${RED}✗ Health check endpoint not created${NC}"
fi

# Test 5: Start development environment
run_test "Start development environment" "${MOCK_SCRIPT} --project ${TEST_PROJECT} --action start --port ${TEST_PORT}" 0

# Test 6: Reload development environment
run_test "Reload development environment" "${MOCK_SCRIPT} --project ${TEST_PROJECT} --action reload" 0

# Test 7: Stop development environment
run_test "Stop development environment" "${MOCK_SCRIPT} --project ${TEST_PROJECT} --action stop" 0

# Clean up
cleanup

echo -e "\n${GREEN}All tests completed!${NC}"
exit 0 