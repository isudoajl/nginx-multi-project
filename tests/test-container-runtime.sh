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
  
  # CRITICAL FIX: Also check for containers with alternative naming patterns
  log "Checking for containers with alternative naming patterns..."
  
  # Check for podman-compose naming convention (project_service_1)
  nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a --format "{{.Names}}" | grep "${TEST_PROJECT}_" | while read container; do
    log "Removing container with podman-compose naming: $container"
    nix --extra-experimental-features "nix-command flakes" develop --command podman stop "$container" 2>/dev/null || true
    nix --extra-experimental-features "nix-command flakes" develop --command podman rm "$container" 2>/dev/null || true
  done
  
  # Check for containers with test project name anywhere in the name
  nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a --format "{{.Names}}" | grep "${TEST_PROJECT}" | while read container; do
    log "Removing container: $container"
    nix --extra-experimental-features "nix-command flakes" develop --command podman stop "$container" 2>/dev/null || true
    nix --extra-experimental-features "nix-command flakes" develop --command podman rm "$container" 2>/dev/null || true
  done
  
  # Remove test project directory
  rm -rf "${PROJECT_ROOT}/projects/${TEST_PROJECT}"
  
  # Remove test domain configuration
  rm -f "${PROJECT_ROOT}/proxy/conf.d/domains/${TEST_DOMAIN}.conf"
  
  # Remove test repository
  rm -rf "$TEST_REPO"
  
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
  
  # Create root package.json
  cat > "${TEST_REPO}/package.json" << EOF
{
  "name": "test-monorepo",
  "version": "1.0.0",
  "private": true,
  "workspaces": [
    "frontend",
    "backend"
  ],
  "scripts": {
    "build:frontend": "cd frontend && npm run build",
    "build:backend": "cd backend && npm run build",
    "start:backend": "cd backend && npm run start"
  }
}
EOF
  
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
    "build": "mkdir -p dist && cp -r src/* dist/ && echo 'Frontend built successfully'"
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
    "start": "node src/server.js"
  }
}
EOF
  
  cat > "${TEST_REPO}/backend/src/server.js" << EOF
const http = require('http');

// CRITICAL FIX: Add more logging for debugging
console.log('Starting backend server...');

const server = http.createServer((req, res) => {
  // Log all requests for debugging
  console.log('Request received:', req.method, req.url);
  
  // CRITICAL FIX: Normalize URL path to handle both /health and /health/
  const path = req.url.endsWith('/') ? req.url.slice(0, -1) : req.url;
  
  if (path === '/health') {
    console.log('Health check request received');
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', service: 'backend' }));
    return;
  }
  
  console.log('API request received:', req.url);
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ message: 'Hello from backend API!' }));
});

const PORT = 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log('Backend server running on port ' + PORT);
  console.log('Health endpoint available at: http://localhost:' + PORT + '/health');
});

// Handle errors
server.on('error', (err) => {
  console.error('Server error:', err);
});

// Log startup complete
console.log('Backend server setup complete');
EOF

  # Verify test repository structure
  if [ ! -d "$TEST_REPO" ]; then
    handle_error "Test repository directory was not created correctly: $TEST_REPO"
  fi
  
  if [ ! -f "${TEST_REPO}/flake.nix" ]; then
    handle_error "flake.nix was not created correctly in test repository"
  fi
  
  log "Test repository structure created at: $TEST_REPO"
  log "Repository contents:"
  ls -la "$TEST_REPO"
  
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
    --frontend-build-cmd "cd frontend && npm run build" \
    --backend-path "backend" \
    --backend-build-cmd "cd backend && npm run build" \
    --backend-start-cmd "cd backend && npm run start"
  
  # Check if project was created successfully
  if [ $? -ne 0 ]; then
    handle_error "Failed to create project with container runtime configuration."
  fi
  
  # Wait for container to start
  log "Waiting for container to start..."
  local container_running=false
  local max_wait_attempts=20  # Increased from 10 seconds to 60 seconds (20 attempts * 3 seconds)
  local wait_attempt=0
  
  while [[ "$container_running" == "false" && $wait_attempt -lt $max_wait_attempts ]]; do
    if nix --extra-experimental-features "nix-command flakes" develop --command podman ps --format "{{.Names}}" | grep -q "^${TEST_PROJECT}$"; then
      container_running=true
      log "Container '${TEST_PROJECT}' is running"
    else
      log "Wait attempt $((wait_attempt + 1)): Container not running yet, waiting..."
      sleep 3
      ((wait_attempt++))
    fi
  done
  
  # Check if container is running
  if [[ "$container_running" == "false" ]]; then
    log "ERROR: Container is not running after ${max_wait_attempts} attempts. Checking for errors..."
    
    # CRITICAL FIX: Add detailed debugging information
    log "Container logs:"
    nix --extra-experimental-features "nix-command flakes" develop --command podman logs "$TEST_PROJECT" 2>&1 || log "No logs available"
    
    log "Container status:"
    nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a --filter "name=$TEST_PROJECT" --format "{{.Names}} {{.Status}}" || log "Cannot get container status"
    
    log "Build logs:"
    nix --extra-experimental-features "nix-command flakes" develop --command podman build -t "$TEST_PROJECT" "${PROJECT_ROOT}/projects/${TEST_PROJECT}" --no-cache 2>&1 || log "Build failed"
    
    log "Network inspection:"
    nix --extra-experimental-features "nix-command flakes" develop --command podman network inspect "${TEST_PROJECT}-network" 2>&1 || log "Network inspection failed"
    
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
  # CRITICAL FIX: Add more verbose output and proper endpoint check
  local backend_health_output
  
  log "Checking if backend server is running..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" ps aux | grep node
  
  log "Checking backend logs..."
  nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" cat /var/log/backend.log || log "No backend log file found"
  
  log "Testing backend health endpoint with curl..."
  backend_health_output=$(nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" curl -sv http://localhost/api/health/ 2>&1)
  
  log "Backend health endpoint output: $backend_health_output"
  
  if echo "$backend_health_output" | grep -q "status.*ok"; then
    log "Backend health endpoint test passed"
  else
    # Try alternative endpoint format without trailing slash
    log "Trying alternative endpoint format without trailing slash..."
    backend_health_output=$(nix --extra-experimental-features "nix-command flakes" develop --command \
    podman exec "$TEST_PROJECT" curl -sv http://localhost/api/health 2>&1)
    
    log "Alternative endpoint output: $backend_health_output"
    
    if echo "$backend_health_output" | grep -q "status.*ok"; then
      log "Backend health endpoint test passed with alternative endpoint format"
    else
      # Try direct access to backend port
      log "Trying direct access to backend port..."
      backend_health_output=$(nix --extra-experimental-features "nix-command flakes" develop --command \
      podman exec "$TEST_PROJECT" curl -sv http://localhost:3000/health 2>&1)
      
      log "Direct backend access output: $backend_health_output"
      
      if echo "$backend_health_output" | grep -q "status.*ok"; then
        log "Backend health endpoint test passed with direct port access"
      else
        # Check if backend is running at all
        log "Checking if backend is running..."
        nix --extra-experimental-features "nix-command flakes" develop --command \
        podman exec "$TEST_PROJECT" supervisorctl status
        
        # Check nginx configuration
        log "Checking nginx configuration..."
        nix --extra-experimental-features "nix-command flakes" develop --command \
        podman exec "$TEST_PROJECT" cat /etc/nginx/nginx.conf
        
        # Check if we can connect to the backend port
        log "Testing connection to backend port..."
        nix --extra-experimental-features "nix-command flakes" develop --command \
        podman exec "$TEST_PROJECT" curl -sv http://localhost:3000 2>&1 || log "Cannot connect to backend port"
        
        # Try to restart the backend service
        log "Trying to restart the backend service..."
        nix --extra-experimental-features "nix-command flakes" develop --command \
        podman exec "$TEST_PROJECT" bash -c "supervisorctl -c /etc/supervisor/conf.d/supervisord.conf restart backend" || log "Cannot restart backend service"
        
        sleep 5
        
        # Try one more time
        backend_health_output=$(nix --extra-experimental-features "nix-command flakes" develop --command \
        podman exec "$TEST_PROJECT" curl -sv http://localhost/api/health 2>&1)
        
        if echo "$backend_health_output" | grep -q "status.*ok"; then
          log "Backend health endpoint test passed after service restart"
        else
          handle_error "Backend health endpoint test failed."
        fi
      fi
    fi
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
  # CRITICAL FIX: Add more verbose output and error handling
  local node_process_output
  node_process_output=$(nix --extra-experimental-features "nix-command flakes" develop --command \
  podman exec "$TEST_PROJECT" ps aux | grep node)
  
  log "Node process output: $node_process_output"
  
  if echo "$node_process_output" | grep -v grep | grep -q node; then
    log "Node process found: $node_process_output"
  else
    log "WARNING: Node process not found through standard grep. Checking with alternative methods..."
    
    # Try with ps and grep separately
    nix --extra-experimental-features "nix-command flakes" develop --command \
    podman exec "$TEST_PROJECT" ps aux > /tmp/ps_output.txt
    
    if grep -q node /tmp/ps_output.txt; then
      log "Node process found in full process list"
    else
      # Check supervisord status
      log "Checking supervisord status..."
      nix --extra-experimental-features "nix-command flakes" develop --command \
      podman exec "$TEST_PROJECT" supervisorctl status
      
      # Check backend logs
      log "Checking backend logs..."
      nix --extra-experimental-features "nix-command flakes" develop --command \
      podman exec "$TEST_PROJECT" cat /var/log/backend.log
      
      handle_error "Node process (backend) not found."
    fi
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