#!/bin/bash

# Test script for Nix-compatible Dockerfile generation

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/tmp"
TEST_PROJECT="test-nix-build"
TEST_DOMAIN="test-nix.local"
TEST_PORT="9000"
TEST_MONO_REPO="${PROJECT_ROOT}/examples/monorepo-example"
TEST_FRONTEND_PATH="packages/frontend"
TEST_FRONTEND_BUILD_DIR="dist"
TEST_FRONTEND_BUILD_CMD="cd packages/frontend && npm run build"
TEST_BACKEND_PATH="packages/backend"
TEST_BACKEND_BUILD_CMD="cd packages/backend && npm start"

# Create test directory
mkdir -p "${TEST_DIR}"

# Source required modules for testing
source "${PROJECT_ROOT}/scripts/create-project/modules/common.sh"
source "${PROJECT_ROOT}/scripts/create-project/modules/args.sh"

# Mock required variables and functions
PROJECTS_DIR="${TEST_DIR}"
ENV_TYPE="DEV"
USE_NIX_BUILD=true
MONO_REPO_PATH="${TEST_MONO_REPO}"
FRONTEND_PATH="${TEST_FRONTEND_PATH}"
FRONTEND_BUILD_DIR="${TEST_FRONTEND_BUILD_DIR}"
FRONTEND_BUILD_CMD="${TEST_FRONTEND_BUILD_CMD}"
BACKEND_PATH="${TEST_BACKEND_PATH}"
BACKEND_BUILD_CMD="${TEST_BACKEND_BUILD_CMD}"
PROJECT_NAME="${TEST_PROJECT}"
DOMAIN_NAME="${TEST_DOMAIN}"

# Mock log function if not defined
if ! command -v log &> /dev/null; then
  function log() {
    echo "[TEST] $1"
  }
fi

# Create test project directory
TEST_PROJECT_DIR="${TEST_DIR}/${TEST_PROJECT}"
mkdir -p "${TEST_PROJECT_DIR}"

# Source the project_files module
source "${PROJECT_ROOT}/scripts/create-project/modules/project_files.sh"

# Test function
function run_test() {
  local test_name="$1"
  local test_function="$2"
  
  echo "Running test: ${test_name}"
  
  if ${test_function}; then
    echo "✅ Test passed: ${test_name}"
    return 0
  else
    echo "❌ Test failed: ${test_name}"
    return 1
  fi
}

# Test: Dockerfile generation with Nix build
function test_nix_dockerfile_generation() {
  # Generate the Dockerfile
  generate_dockerfile "${TEST_PROJECT_DIR}"
  
  # Check if Dockerfile exists
  if [ ! -f "${TEST_PROJECT_DIR}/Dockerfile" ]; then
    echo "Dockerfile not created"
    return 1
  fi
  
  # Check if Dockerfile contains Nix-specific content
  if ! grep -q "nixos/nix:latest" "${TEST_PROJECT_DIR}/Dockerfile"; then
    echo "Dockerfile does not contain Nix base image"
    return 1
  fi
  
  # Check if Dockerfile contains monorepo copy
  if ! grep -q "COPY ${MONO_REPO_PATH}" "${TEST_PROJECT_DIR}/Dockerfile"; then
    echo "Dockerfile does not contain monorepo copy"
    return 1
  fi
  
  # Check if Dockerfile contains flake.nix detection
  if ! grep -q "if \[ -f flake.nix \]" "${TEST_PROJECT_DIR}/Dockerfile"; then
    echo "Dockerfile does not contain flake.nix detection"
    return 1
  fi
  
  # Check if Dockerfile contains frontend build command
  if ! grep -q "${FRONTEND_BUILD_CMD}" "${TEST_PROJECT_DIR}/Dockerfile"; then
    echo "Dockerfile does not contain frontend build command"
    return 1
  fi
  
  # Check if Dockerfile contains backend build command
  if ! grep -q "${BACKEND_BUILD_CMD}" "${TEST_PROJECT_DIR}/Dockerfile"; then
    echo "Dockerfile does not contain backend build command"
    return 1
  fi
  
  # Check if supervisord.conf is created
  if [ ! -f "${TEST_PROJECT_DIR}/supervisord.conf" ]; then
    echo "supervisord.conf not created"
    return 1
  fi
  
  return 0
}

# Test: docker-compose.yml generation with Nix build
function test_docker_compose_generation() {
  # Generate the docker-compose.yml
  generate_docker_compose "${TEST_PROJECT_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "${TEST_PROJECT_DIR}/docker-compose.yml" ]; then
    echo "docker-compose.yml not created"
    return 1
  fi
  
  # Check if docker-compose.yml does NOT contain frontend mount
  if grep -q "/usr/share/nginx/html:ro" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml contains frontend mount, which should be disabled for Nix build"
    return 1
  fi
  
  # Check if docker-compose.yml contains supervisord.conf mount
  if ! grep -q "supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain supervisord.conf mount"
    return 1
  fi
  
  return 0
}

# Test: nginx.conf generation with backend API proxy
function test_nginx_conf_generation() {
  # Generate the nginx.conf
  generate_nginx_conf "${TEST_PROJECT_DIR}"
  
  # Check if nginx.conf exists
  if [ ! -f "${TEST_PROJECT_DIR}/nginx.conf" ]; then
    echo "nginx.conf not created"
    return 1
  fi
  
  # Check if nginx.conf contains backend API proxy
  if ! grep -q "location /api/" "${TEST_PROJECT_DIR}/nginx.conf"; then
    echo "nginx.conf does not contain backend API proxy"
    return 1
  fi
  
  # Check if nginx.conf contains proxy_pass
  if ! grep -q "proxy_pass http://localhost:3000/" "${TEST_PROJECT_DIR}/nginx.conf"; then
    echo "nginx.conf does not contain proxy_pass directive"
    return 1
  fi
  
  return 0
}

# Run tests
run_test "Nix Dockerfile Generation" test_nix_dockerfile_generation
run_test "Docker Compose Generation" test_docker_compose_generation
run_test "Nginx Configuration Generation" test_nginx_conf_generation

# Clean up test directory
rm -rf "${TEST_DIR}"

echo "All tests completed!" 