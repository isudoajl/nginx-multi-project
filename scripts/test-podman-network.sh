#!/bin/bash

# This script tests podman network connectivity
# It creates two test containers and verifies they can communicate

# See https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Check if we're in Nix environment
if [ -z "${IN_NIX_SHELL:-}" ]; then
  echo "ERROR: Please enter Nix environment with 'nix develop' first"
  exit 1
fi

echo "Testing podman network connectivity..."

# Create the nginx-proxy network if it doesn't exist
if ! podman network ls | grep -q "nginx-proxy-network"; then
  echo "Creating nginx-proxy network..."
  podman network create nginx-proxy-network
fi

# Clean up any existing test containers
echo "Cleaning up existing test containers..."
podman rm -f test-server test-client &>/dev/null || true

# Create a test server container with nginx
echo "Creating test server container with nginx..."
podman run -d --name test-server --network nginx-proxy-network nginx:alpine

# Create a test client container with tools
echo "Creating test client container..."
podman run -d --name test-client --network nginx-proxy-network alpine sh -c "apk add --no-cache curl && sleep 3600"

# Wait for containers to initialize
echo "Waiting for containers to initialize..."
sleep 5

# Get the IP address of the server
SERVER_IP=$(podman inspect test-server | grep -A 20 "\"nginx-proxy-network\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')

echo "Server IP address: ${SERVER_IP}"

# Test HTTP connectivity using curl
echo "Testing HTTP connectivity by IP..."
if podman exec test-client curl -s --max-time 5 "http://${SERVER_IP}/" | grep -q "Welcome to nginx"; then
  echo "HTTP connectivity test by IP successful!"
else
  echo "ERROR: HTTP connectivity test by IP failed!"
  podman exec test-client curl -v "http://${SERVER_IP}/"
  exit 1
fi

# Test hostname resolution and connectivity
echo "Testing hostname resolution and HTTP connectivity..."
if podman exec test-client curl -s --max-time 5 "http://test-server/" | grep -q "Welcome to nginx"; then
  echo "Hostname resolution and HTTP connectivity test successful!"
else
  echo "WARNING: Hostname resolution test failed. This may cause issues with container-to-container communication."
  echo "Consider using IP addresses instead of hostnames in your proxy configurations."
fi

# Clean up test containers
echo "Cleaning up test containers..."
podman rm -f test-server test-client

echo "Podman network connectivity test completed successfully!" 