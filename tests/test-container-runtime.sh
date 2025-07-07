#!/bin/bash

# Test script for container runtime configuration
# This script tests the implementation of Milestone 3: Container Runtime Configuration

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_PROJECT="test-runtime"
TEST_DOMAIN="test-runtime.local"
TEST_PORT="8099"
TEST_REPO="${PROJECT_ROOT}/tests/test-repo"
TEST_LOG="${PROJECT_ROOT}/tests/logs/test-container-runtime.log"

# Create test log directory
mkdir -p "$(dirname "$TEST_LOG")"

# Log function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$TEST_LOG"
}

# Error handling
handle_error() {
  log "ERROR: $1"
  exit 1
}

# Test cleanup
cleanup() {
  log "Cleaning up test environment..."
  
  # Stop and remove test containers
  nix --extra-experimental-features "nix-command flakes" develop --command podman stop "$TEST_PROJECT" 2>/dev/null || true
  nix --extra-experimental-features "nix-command flakes" develop --command podman rm "$TEST_PROJECT" 2>/dev/null || true
  
  # Remove test project directory
  rm -rf "${PROJECT_ROOT}/projects/${TEST_PROJECT}"
  
  # Remove test domain configuration
  rm -f "${PROJECT_ROOT}/proxy/conf.d/domains/${TEST_DOMAIN}.conf"
  
  log "Cleanup completed."
}

# Run test
run_test() {
  log "Starting container runtime configuration test..."
  
  # Clean up any previous test artifacts
  cleanup
  
  # Create test repository structure
  log "Creating test repository structure..."
  mkdir -p "$TEST_REPO"
  mkdir -p "${TEST_REPO}/frontend/dist"
  mkdir -p "${TEST_REPO}/backend/src"
  
  # Create flake.nix
  cat > "${TEST_REPO}/flake.nix" << EOF
{
  description = "Test project for container runtime configuration";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\${system};
      in
      {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.npm
          ];
        };
      }
    );
}
EOF
  
  # Create frontend files
  cat > "${TEST_REPO}/frontend/package.json" << EOF
{
  "name": "test-frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building frontend...' && cp -r src/* dist/"
  }
}
EOF
  
  mkdir -p "${TEST_REPO}/frontend/src"
  cat > "${TEST_REPO}/frontend/src/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Test Frontend</title>
</head>
<body>
  <h1>Test Frontend</h1>
  <p>This is a test frontend for container runtime configuration.</p>
</body>
</html>
EOF
  
  # Create backend files
  cat > "${TEST_REPO}/backend/package.json" << EOF
{
  "name": "test-backend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building backend...'",
    "start": "echo 'Starting backend server...' && node src/server.js"
  }
}
EOF
  
  cat > "${TEST_REPO}/backend/src/server.js" << EOF
const http = require('http');

const server = http.createServer((req, res) => {
  if (req.url === '/health/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'backend' }));
    return;
  }
  
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ message: 'Hello from backend API!' }));
});

server.listen(3000, () => {
  console.log('Backend server running on port 3000');
});
EOF
  
  # Run create-project-modular.sh with Nix build
  log "Creating project with container runtime configuration..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  "${PROJECT_ROOT}/scripts/create-project-modular.sh" \
    --name "$TEST_PROJECT" \
    --port "$TEST_PORT" \
    --domain "$TEST_DOMAIN" \
    --env "DEV" \
    --use-nix-build \
    --mono-repo "$TEST_REPO" \
    --frontend-path "frontend" \
    --frontend-build-dir "dist" \
    --frontend-build-cmd "npm run build" \
    --backend-path "backend" \
    --backend-build-cmd "npm run build" \
    --backend-start-cmd "npm run start"
  
  # Check if project was created successfully
  if [ $? -ne 0 ]; then
    handle_error "Failed to create project with container runtime configuration."
  fi
  
  # Wait for container to start
  log "Waiting for container to start..."
  sleep 10
  
  # Check if container is running
  nix --extra-experimental-features "nix-command flakes" develop --command podman ps | grep "$TEST_PROJECT" > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Container is not running."
  fi
  
  # Test frontend health endpoint
  log "Testing frontend health endpoint..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" curl -s http://localhost/health/ | grep "OK" > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Frontend health endpoint test failed."
  fi
  
  # Test backend health endpoint
  log "Testing backend health endpoint..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" curl -s http://localhost/api/health/ | grep "status" > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Backend health endpoint test failed."
  fi
  
  # Test backend API
  log "Testing backend API..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" curl -s http://localhost/api/ | grep "Hello from backend API" > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Backend API test failed."
  fi
  
  # Check supervisord process
  log "Checking supervisord process..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" ps aux | grep supervisord > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Supervisord process not found."
  fi
  
  # Check nginx process
  log "Checking nginx process..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" ps aux | grep nginx | grep -v grep > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Nginx process not found."
  fi
  
  # Check node process (backend)
  log "Checking node process (backend)..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" ps aux | grep node | grep -v grep > /dev/null
  if [ $? -ne 0 ]; then
    handle_error "Node process (backend) not found."
  fi
  
  log "All tests passed successfully!"
  return 0
}

# Main execution
log "Container Runtime Configuration Test Script"
log "----------------------------------------"

# Run the test
run_test

# Clean up
cleanup

log "Test completed successfully!"
exit 0 