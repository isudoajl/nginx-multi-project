#!/bin/bash

# Test script for Docker Compose Integration with Nix build

# Set up test environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/tmp"
TEST_PROJECT="test-docker-compose"
TEST_DOMAIN="test-compose.local"
TEST_PORT="9001"
TEST_MONO_REPO="${PROJECT_ROOT}/examples/monorepo-example"
TEST_FRONTEND_PATH="packages/frontend"
TEST_FRONTEND_BUILD_DIR="dist"
TEST_FRONTEND_BUILD_CMD="cd packages/frontend && npm run build"
TEST_BACKEND_PATH="packages/backend"
TEST_BACKEND_BUILD_CMD="cd packages/backend && npm start"
TEST_ENV_VARS="NODE_ENV=development,API_URL=http://localhost:3000"

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
PROJECT_ENV_VARS="${TEST_ENV_VARS}"

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

# Test: Docker Compose generation with environment variables
function test_docker_compose_env_vars() {
  # Generate the docker-compose.yml
  generate_docker_compose "${TEST_PROJECT_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "${TEST_PROJECT_DIR}/docker-compose.yml" ]; then
    echo "docker-compose.yml not created"
    return 1
  fi
  
  # Check if docker-compose.yml contains environment variables
  if ! grep -q "NODE_ENV=development" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain NODE_ENV environment variable"
    return 1
  fi
  
  if ! grep -q "API_URL=http://localhost:3000" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain API_URL environment variable"
    return 1
  fi
  
  return 0
}

# Test: Docker Compose with health check configuration
function test_docker_compose_health_check() {
  # Generate the docker-compose.yml
  generate_docker_compose "${TEST_PROJECT_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "${TEST_PROJECT_DIR}/docker-compose.yml" ]; then
    echo "docker-compose.yml not created"
    return 1
  fi
  
  # Check if docker-compose.yml contains healthcheck configuration
  if ! grep -q "healthcheck:" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain healthcheck configuration"
    return 1
  fi
  
  # Check if docker-compose.yml contains healthcheck test
  if ! grep -q "test:" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain healthcheck test"
    return 1
  fi
  
  return 0
}

# Test: Docker Compose with network configuration
function test_docker_compose_network() {
  # Generate the docker-compose.yml
  generate_docker_compose "${TEST_PROJECT_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "${TEST_PROJECT_DIR}/docker-compose.yml" ]; then
    echo "docker-compose.yml not created"
    return 1
  fi
  
  # Check if docker-compose.yml contains network configuration
  if ! grep -q "${TEST_PROJECT}-network:" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain project network configuration"
    return 1
  fi
  
  # Check if docker-compose.yml contains external network configuration
  if ! grep -q "external: true" "${TEST_PROJECT_DIR}/docker-compose.yml"; then
    echo "docker-compose.yml does not contain external network configuration"
    return 1
  fi
  
  return 0
}

# Run tests
run_test "Docker Compose Environment Variables" test_docker_compose_env_vars
run_test "Docker Compose Health Check" test_docker_compose_health_check
run_test "Docker Compose Network Configuration" test_docker_compose_network

# Clean up test directory
rm -rf "${TEST_DIR}"

echo "All tests completed!" 