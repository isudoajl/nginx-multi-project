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

# Function: Build and start proxy container
function start_proxy_container() {
  echo "Building and starting proxy container..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    return 1
  fi
  
  # Build and start the container
  docker-compose up -d --build
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to build and start proxy container${NC}"
    return 1
  fi
  
  # Wait for container to start
  echo "Waiting for container to start..."
  sleep 5
  
  # Check if container is running
  docker ps | grep -q "nginx-proxy"
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Proxy container is not running${NC}"
    return 1
  fi
  
  echo -e "${GREEN}Proxy container is running${NC}"
  return 0
}

# Function: Test HTTP to HTTPS redirection
function test_http_redirect() {
  echo "Testing HTTP to HTTPS redirection..."
  
  # Use curl to test redirection
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code},%{redirect_url}" http://localhost)
  
  HTTP_CODE=$(echo $RESPONSE | cut -d',' -f1)
  REDIRECT_URL=$(echo $RESPONSE | cut -d',' -f2)
  
  if [ "$HTTP_CODE" -eq 301 ] && [[ "$REDIRECT_URL" == https://* ]]; then
    echo -e "${GREEN}HTTP to HTTPS redirection is working${NC}"
    return 0
  else
    echo -e "${RED}Error: HTTP to HTTPS redirection is not working${NC}"
    echo "HTTP Code: $HTTP_CODE"
    echo "Redirect URL: $REDIRECT_URL"
    return 1
  fi
}

# Function: Test HTTPS default server
function test_https_default() {
  echo "Testing HTTPS default server..."
  
  # Use curl to test HTTPS default server (should return 444)
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" https://localhost --insecure)
  
  if [ "$RESPONSE" -eq 000 ]; then
    # 000 means connection closed (Nginx 444)
    echo -e "${GREEN}HTTPS default server is working (returns 444)${NC}"
    return 0
  else
    echo -e "${RED}Error: HTTPS default server is not working${NC}"
    echo "HTTP Code: $RESPONSE"
    return 1
  fi
}

# Function: Test bad bot rejection
function test_bad_bot_rejection() {
  echo "Testing bad bot rejection..."
  
  # Use curl with a bad bot user agent
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -A "nmap" http://localhost)
  
  if [ "$RESPONSE" -eq 000 ]; then
    # 000 means connection closed (Nginx 444)
    echo -e "${GREEN}Bad bot rejection is working${NC}"
    return 0
  else
    echo -e "${RED}Error: Bad bot rejection is not working${NC}"
    echo "HTTP Code: $RESPONSE"
    return 1
  fi
}

# Function: Test unusual HTTP method rejection
function test_method_rejection() {
  echo "Testing unusual HTTP method rejection..."
  
  # Use curl with TRACE method
  RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -X TRACE http://localhost)
  
  if [ "$RESPONSE" -eq 000 ]; then
    # 000 means connection closed (Nginx 444)
    echo -e "${GREEN}Unusual HTTP method rejection is working${NC}"
    return 0
  else
    echo -e "${RED}Error: Unusual HTTP method rejection is not working${NC}"
    echo "HTTP Code: $RESPONSE"
    return 1
  fi
}

# Function: Stop proxy container
function stop_proxy_container() {
  echo "Stopping proxy container..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Stop the container
  docker-compose down
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to stop proxy container${NC}"
    return 1
  fi
  
  echo -e "${GREEN}Proxy container stopped${NC}"
  return 0
}

# Function: Run all tests
function run_all_tests() {
  local FAILED=0
  
  start_proxy_container
  if [ $? -ne 0 ]; then
    FAILED=1
    echo -e "${RED}Skipping further tests due to container startup failure${NC}"
    return $FAILED
  fi
  
  test_http_redirect
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  test_https_default
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  test_bad_bot_rejection
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  test_method_rejection
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  stop_proxy_container
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some tests failed!${NC}"
    return 1
  fi
}

# Main script execution
check_environment
run_all_tests
exit $? 