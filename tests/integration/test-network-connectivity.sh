#!/bin/bash
set -e

# Test script to verify network connectivity between proxy and project containers
# This script is part of the integration testing for Milestone 2: Proxy and Project Container Integration

# Set up colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Get the directory of the script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions if available
if [ -f "$PROJECT_ROOT/scripts/common.sh" ]; then
    source "$PROJECT_ROOT/scripts/common.sh"
fi

echo "=== Testing Network Connectivity Between Proxy and Project Containers ==="

# Check if we're in the Nix environment
if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please run this script inside the Nix environment (nix develop)${NC}"
    exit 1
fi

# Create a test project for network connectivity testing
echo "Creating test project for network testing..."
TEST_PROJECT="test-network-project"
TEST_DOMAIN="test-network.local"

# Check if create-project.sh exists and is executable
if [ ! -x "$PROJECT_ROOT/scripts/create-project.sh" ]; then
    echo -e "${RED}Error: create-project.sh script not found or not executable${NC}"
    exit 1
fi

# Create the test project
"$PROJECT_ROOT/scripts/create-project.sh" "$TEST_PROJECT" "$TEST_DOMAIN" "dev" || {
    echo -e "${RED}Failed to create test project${NC}"
    exit 1
}

echo "Starting proxy and test project containers..."
# Start the proxy container
cd "$PROJECT_ROOT/proxy" && docker-compose up -d || {
    echo -e "${RED}Failed to start proxy container${NC}"
    exit 1
}

# Start the test project container
cd "$PROJECT_ROOT/projects/$TEST_PROJECT" && docker-compose up -d || {
    echo -e "${RED}Failed to start test project container${NC}"
    exit 1
}

# Wait for containers to be fully up
echo "Waiting for containers to be ready..."
sleep 5

# Get container IDs
PROXY_CONTAINER=$(docker ps --filter "name=nginx-proxy" --format "{{.ID}}")
PROJECT_CONTAINER=$(docker ps --filter "name=$TEST_PROJECT" --format "{{.ID}}")

if [ -z "$PROXY_CONTAINER" ]; then
    echo -e "${RED}Error: Proxy container not found${NC}"
    exit 1
fi

if [ -z "$PROJECT_CONTAINER" ]; then
    echo -e "${RED}Error: Project container not found${NC}"
    exit 1
fi

echo "Proxy container ID: $PROXY_CONTAINER"
echo "Project container ID: $PROJECT_CONTAINER"

# Test 1: Verify proxy can reach project container
echo "Testing proxy to project container connectivity..."
docker exec "$PROXY_CONTAINER" ping -c 3 "$TEST_PROJECT" > /dev/null 2>&1
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Proxy can reach project container${NC}"
else
    echo -e "${RED}✗ Proxy cannot reach project container${NC}"
    exit 1
fi

# Test 2: Verify project container can reach proxy
echo "Testing project container to proxy connectivity..."
docker exec "$PROJECT_CONTAINER" ping -c 3 nginx-proxy > /dev/null 2>&1
RESULT=$?
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✓ Project container can reach proxy${NC}"
else
    echo -e "${RED}✗ Project container cannot reach proxy${NC}"
    exit 1
fi

# Test 3: Verify HTTP connectivity
echo "Testing HTTP connectivity from proxy to project..."
docker exec "$PROXY_CONTAINER" curl -s -o /dev/null -w "%{http_code}" "http://$TEST_PROJECT" > /tmp/http_status
HTTP_STATUS=$(cat /tmp/http_status)
if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "404" ]; then
    echo -e "${GREEN}✓ HTTP connectivity successful (status: $HTTP_STATUS)${NC}"
else
    echo -e "${RED}✗ HTTP connectivity failed (status: $HTTP_STATUS)${NC}"
    exit 1
fi

# Test 4: Verify network isolation between projects
echo "Creating second test project for isolation testing..."
TEST_PROJECT2="test-network-project2"
TEST_DOMAIN2="test-network2.local"

# Create the second test project
"$PROJECT_ROOT/scripts/create-project.sh" "$TEST_PROJECT2" "$TEST_DOMAIN2" "dev" || {
    echo -e "${RED}Failed to create second test project${NC}"
    exit 1
}

# Start the second test project container
cd "$PROJECT_ROOT/projects/$TEST_PROJECT2" && docker-compose up -d || {
    echo -e "${RED}Failed to start second test project container${NC}"
    exit 1
}

# Wait for container to be fully up
sleep 5

PROJECT2_CONTAINER=$(docker ps --filter "name=$TEST_PROJECT2" --format "{{.ID}}")

if [ -z "$PROJECT2_CONTAINER" ]; then
    echo -e "${RED}Error: Second project container not found${NC}"
    exit 1
fi

echo "Second project container ID: $PROJECT2_CONTAINER"

# Test network isolation
echo "Testing network isolation between projects..."
docker exec "$PROJECT_CONTAINER" ping -c 1 "$TEST_PROJECT2" > /dev/null 2>&1
RESULT=$?
if [ $RESULT -ne 0 ]; then
    echo -e "${GREEN}✓ Projects are properly isolated${NC}"
else
    echo -e "${RED}✗ Projects are not isolated${NC}"
    exit 1
fi

echo "Cleaning up test containers..."
# Clean up
cd "$PROJECT_ROOT/projects/$TEST_PROJECT" && docker-compose down
cd "$PROJECT_ROOT/projects/$TEST_PROJECT2" && docker-compose down
cd "$PROJECT_ROOT/proxy" && docker-compose down

# Remove test projects
rm -rf "$PROJECT_ROOT/projects/$TEST_PROJECT"
rm -rf "$PROJECT_ROOT/projects/$TEST_PROJECT2"

echo -e "${GREEN}=== Network connectivity tests passed! ===${NC}"
exit 0 