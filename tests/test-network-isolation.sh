#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/../proxy"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please enter Nix environment with 'nix develop' first${NC}"
    exit 1
  fi
  
  # Check if docker/podman is available
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: docker/podman is not installed or not in PATH${NC}"
    exit 1
  fi
}

# Function: Setup test environment
function setup_test_environment() {
  echo "Setting up test environment..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    return 1
  fi
  
  # Create test projects
  echo "Creating test project containers..."
  
  # Create temporary directory for test projects
  mkdir -p "${SCRIPT_DIR}/tmp/project1"
  mkdir -p "${SCRIPT_DIR}/tmp/project2"
  
  # Create docker-compose.yml for test projects
  cat > "${SCRIPT_DIR}/tmp/project1/docker-compose.yml" << EOF
version: '3'

services:
  project1:
    image: nginx:alpine
    container_name: test-project1
    networks:
      - proxy-network
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html

networks:
  proxy-network:
    external: true
    name: proxy-network
EOF

  cat > "${SCRIPT_DIR}/tmp/project2/docker-compose.yml" << EOF
version: '3'

services:
  project2:
    image: nginx:alpine
    container_name: test-project2
    networks:
      - proxy-network
    volumes:
      - ./index.html:/usr/share/nginx/html/index.html

networks:
  proxy-network:
    external: true
    name: proxy-network
EOF

  # Create test content for projects
  echo "<html><body>Project 1</body></html>" > "${SCRIPT_DIR}/tmp/project1/index.html"
  echo "<html><body>Project 2</body></html>" > "${SCRIPT_DIR}/tmp/project2/index.html"
  
  # Start proxy container
  echo "Starting proxy container..."
  docker-compose up -d --build
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start proxy container${NC}"
    return 1
  fi
  
  # Start test project containers
  echo "Starting test project containers..."
  cd "${SCRIPT_DIR}/tmp/project1"
  docker-compose up -d
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start project1 container${NC}"
    return 1
  fi
  
  cd "${SCRIPT_DIR}/tmp/project2"
  docker-compose up -d
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start project2 container${NC}"
    return 1
  fi
  
  # Wait for containers to start
  echo "Waiting for containers to start..."
  sleep 5
  
  return 0
}

# Function: Test network isolation
function test_network_isolation() {
  echo "Testing network isolation between projects..."
  
  # Test if project1 can access project2 directly
  echo "Testing if project1 can access project2 directly..."
  RESPONSE=$(docker exec test-project1 wget -qO- --timeout=5 http://test-project2 2>/dev/null)
  
  if [ $? -eq 0 ] && [[ "$RESPONSE" == *"Project 2"* ]]; then
    echo -e "${RED}Error: Project1 can directly access Project2${NC}"
    return 1
  else
    echo -e "${GREEN}Project1 cannot directly access Project2 - Good!${NC}"
  fi
  
  # Test if project2 can access project1 directly
  echo "Testing if project2 can access project1 directly..."
  RESPONSE=$(docker exec test-project2 wget -qO- --timeout=5 http://test-project1 2>/dev/null)
  
  if [ $? -eq 0 ] && [[ "$RESPONSE" == *"Project 1"* ]]; then
    echo -e "${RED}Error: Project2 can directly access Project1${NC}"
    return 1
  else
    echo -e "${GREEN}Project2 cannot directly access Project1 - Good!${NC}"
  fi
  
  # Test if both projects can access the proxy
  echo "Testing if projects can access the proxy..."
  RESPONSE=$(docker exec test-project1 wget -qO- --timeout=5 http://nginx-proxy 2>/dev/null)
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Project1 cannot access the proxy${NC}"
    return 1
  else
    echo -e "${GREEN}Project1 can access the proxy - Good!${NC}"
  fi
  
  RESPONSE=$(docker exec test-project2 wget -qO- --timeout=5 http://nginx-proxy 2>/dev/null)
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Project2 cannot access the proxy${NC}"
    return 1
  else
    echo -e "${GREEN}Project2 can access the proxy - Good!${NC}"
  fi
  
  return 0
}

# Function: Cleanup test environment
function cleanup_test_environment() {
  echo "Cleaning up test environment..."
  
  # Stop test project containers
  cd "${SCRIPT_DIR}/tmp/project1"
  docker-compose down
  
  cd "${SCRIPT_DIR}/tmp/project2"
  docker-compose down
  
  # Stop proxy container
  cd "${PROXY_DIR}"
  docker-compose down
  
  # Remove temporary files
  rm -rf "${SCRIPT_DIR}/tmp"
  
  echo -e "${GREEN}Test environment cleaned up${NC}"
  return 0
}

# Function: Run all tests
function run_all_tests() {
  local FAILED=0
  
  setup_test_environment
  if [ $? -ne 0 ]; then
    FAILED=1
    echo -e "${RED}Skipping further tests due to setup failure${NC}"
    cleanup_test_environment
    return $FAILED
  fi
  
  test_network_isolation
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  cleanup_test_environment
  
  if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All network isolation tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some network isolation tests failed!${NC}"
    return 1
  fi
}

# Main script execution
check_environment
run_all_tests
exit $? 