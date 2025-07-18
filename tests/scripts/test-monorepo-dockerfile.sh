#!/bin/bash

# Test script for monorepo Dockerfile generation functionality
# Tests the multi-stage Dockerfile generation for monorepo projects

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/temp/dockerfile-test"
PROJECT_FILES_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/project_files.sh"
COMMON_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/common.sh"
ARGS_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/args.sh"

# Test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Functions for test output
function log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

function log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

function log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

function handle_error() {
  log_error "$1"
  exit 1
}

# Function to run a test
function run_test() {
  local test_name="$1"
  local test_function="$2"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  log "Running test: $test_name"
  
  if $test_function; then
    log "✅ PASSED: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ FAILED: $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  echo ""
}

# Setup test environment
function setup_test_environment() {
  log "Setting up test environment..."
  
  # Create test directory
  mkdir -p "$TEST_DIR"
  
  # Create mock monorepo structures
  mkdir -p "$TEST_DIR/nix-monorepo/frontend"
  mkdir -p "$TEST_DIR/nix-monorepo/dist"
  mkdir -p "$TEST_DIR/npm-monorepo/web"
  mkdir -p "$TEST_DIR/npm-monorepo/web/dist"
  
  # Create mock flake.nix for Nix monorepo
  cat > "$TEST_DIR/nix-monorepo/flake.nix" << 'EOF'
{
  description = "Mock Nix monorepo for testing";
  
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.frontend = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
EOF

  # Create mock package.json for Nix monorepo
  cat > "$TEST_DIR/nix-monorepo/frontend/package.json" << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building frontend...'"
  }
}
EOF

  # Create mock package.json for npm monorepo
  cat > "$TEST_DIR/npm-monorepo/web/package.json" << 'EOF'
{
  "name": "web-frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building web frontend...'"
  }
}
EOF

  # Create test project directories
  mkdir -p "$TEST_DIR/test-nix-project"
  mkdir -p "$TEST_DIR/test-npm-project"
  mkdir -p "$TEST_DIR/test-standard-project"
  
  log "Test environment setup complete"
}

# Cleanup test environment
function cleanup_test_environment() {
  log "Cleaning up test environment..."
  rm -rf "$TEST_DIR"
  log "Cleanup complete"
}

# Source the modules for testing
function source_modules() {
  # Set up required global variables
  export PROJECT_ROOT="$PROJECT_ROOT"
  export LOG_FILE="$TEST_DIR/test.log"
  export PROJECTS_DIR="$PROJECT_ROOT/projects"
  
  # Create log file
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  
  # Source modules
  source "$COMMON_MODULE"
  source "$ARGS_MODULE"
  source "$PROJECT_FILES_MODULE"
}

# Test 1: Standard Dockerfile generation (non-monorepo)
function test_standard_dockerfile() {
  # Setup variables for standard project
  IS_MONOREPO=false
  PROJECT_NAME="test-standard"
  DOMAIN_NAME="test-standard.local"
  FRONTEND_MOUNT="./html"
  
  # Generate Dockerfile
  local test_project_dir="$TEST_DIR/test-standard-project"
  generate_dockerfile "$test_project_dir"
  
  # Verify Dockerfile was created
  if [[ ! -f "$test_project_dir/Dockerfile" ]]; then
    return 1
  fi
  
  # Verify it's a standard single-stage Dockerfile
  if ! grep -q "FROM nginx:alpine" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Should NOT contain multi-stage build keywords
  if grep -q "AS frontend-builder" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  return 0
}

# Test 2: Nix-based monorepo Dockerfile generation
function test_nix_monorepo_dockerfile() {
  # Setup variables for Nix monorepo project
  IS_MONOREPO=true
  USE_EXISTING_NIX=true
  PROJECT_NAME="test-nix"
  DOMAIN_NAME="test-nix.local"
  MONOREPO_DIR="$TEST_DIR/nix-monorepo"
  FRONTEND_SUBDIR="frontend"
  NIX_BUILD_CMD="nix build .#frontend"
  BUILD_OUTPUT_DIR="dist"
  
  # Generate Dockerfile
  local test_project_dir="$TEST_DIR/test-nix-project"
  generate_dockerfile "$test_project_dir"
  
  # Verify Dockerfile was created
  if [[ ! -f "$test_project_dir/Dockerfile" ]]; then
    return 1
  fi
  
  # Verify it's a multi-stage Dockerfile with Nix
  if ! grep -q "FROM nixos/nix:latest AS frontend-builder" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Verify Nix command is present
  if ! grep -q "RUN $NIX_BUILD_CMD" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Verify flakes are enabled
  if ! grep -q "experimental-features = nix-command flakes" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Verify copy from builder stage
  if ! grep -q "COPY --from=frontend-builder" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  return 0
}

# Test 3: npm-based monorepo Dockerfile generation
function test_npm_monorepo_dockerfile() {
  # Setup variables for npm monorepo project
  IS_MONOREPO=true
  USE_EXISTING_NIX=false
  PROJECT_NAME="test-npm"
  DOMAIN_NAME="test-npm.local"
  MONOREPO_DIR="$TEST_DIR/npm-monorepo"
  FRONTEND_SUBDIR="web"
  FRONTEND_BUILD_CMD="npm run build"
  BUILD_OUTPUT_DIR="dist"
  
  # Generate Dockerfile
  local test_project_dir="$TEST_DIR/test-npm-project"
  generate_dockerfile "$test_project_dir"
  
  # Verify Dockerfile was created
  if [[ ! -f "$test_project_dir/Dockerfile" ]]; then
    return 1
  fi
  
  # Verify it's a multi-stage Dockerfile with Node.js
  if ! grep -q "FROM node:18-alpine AS frontend-builder" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Verify npm commands are present
  if ! grep -q "RUN npm ci" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  if ! grep -q "RUN ${FRONTEND_BUILD_CMD:-npm run build}" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  # Verify copy from builder stage
  if ! grep -q "COPY --from=frontend-builder" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  return 0
}

# Test 4: Monorepo docker-compose generation
function test_monorepo_docker_compose() {
  # Setup variables for monorepo project
  IS_MONOREPO=true
  PROJECT_NAME="test-compose"
  DOMAIN_NAME="test-compose.local"
  MONOREPO_DIR="$TEST_DIR/nix-monorepo"
  FRONTEND_SUBDIR="frontend"
  BUILD_OUTPUT_DIR="dist"
  
  # Generate docker-compose.yml
  local test_project_dir="$TEST_DIR/test-nix-project"
  generate_docker_compose "$test_project_dir"
  
  # Verify docker-compose.yml was created
  if [[ ! -f "$test_project_dir/docker-compose.yml" ]]; then
    return 1
  fi
  
  # Verify monorepo-specific context
  if ! grep -q "context: ${MONOREPO_DIR}" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  # Verify monorepo environment variables
  if ! grep -q "IS_MONOREPO=true" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  if ! grep -q "MONOREPO_DIR=${MONOREPO_DIR}" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  # Verify proxy network is included
  if ! grep -q "nginx-proxy-network" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  return 0
}

# Test 5: Standard docker-compose generation
function test_standard_docker_compose() {
  # Setup variables for standard project
  IS_MONOREPO=false
  PROJECT_NAME="test-standard-compose"
  DOMAIN_NAME="test-standard-compose.local"
  FRONTEND_MOUNT="./html"
  
  # Generate docker-compose.yml
  local test_project_dir="$TEST_DIR/test-standard-project"
  generate_docker_compose "$test_project_dir"
  
  # Verify docker-compose.yml was created
  if [[ ! -f "$test_project_dir/docker-compose.yml" ]]; then
    return 1
  fi
  
  # Verify standard context (current directory)
  if ! grep -q "context: ." "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  # Verify frontend mount is present
  if ! grep -q "${FRONTEND_MOUNT}:/usr/share/nginx/html:ro" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  # Should NOT contain monorepo environment variables
  if grep -q "IS_MONOREPO=true" "$test_project_dir/docker-compose.yml"; then
    return 1
  fi
  
  return 0
}

# Test 6: Dockerfile path variables substitution
function test_dockerfile_variable_substitution() {
  # Setup variables for Nix monorepo
  IS_MONOREPO=true
  USE_EXISTING_NIX=true
  PROJECT_NAME="test-vars"
  DOMAIN_NAME="test-vars.local"
  MONOREPO_DIR="$TEST_DIR/nix-monorepo"
  FRONTEND_SUBDIR="frontend"
  NIX_BUILD_CMD="nix build .#frontend"
  BUILD_OUTPUT_DIR="dist"
  
  # Generate Dockerfile
  local test_project_dir="$TEST_DIR/test-nix-project"
  generate_dockerfile "$test_project_dir"
  
  # Verify variables are properly substituted
  if ! grep -q "COPY $MONOREPO_DIR ." "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  if ! grep -q "WORKDIR /opt/$PROJECT_NAME" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  if ! grep -q "/build/result/$BUILD_OUTPUT_DIR" "$test_project_dir/Dockerfile"; then
    return 1
  fi
  
  return 0
}

# Main test runner
function main() {
  log "Starting monorepo Dockerfile generation tests..."
  log "Project root: $PROJECT_ROOT"
  
  # Check if Nix environment is available
  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    log_warn "Not running in Nix shell - some tests may not work as expected"
  fi
  
  # Setup
  setup_test_environment
  source_modules
  
  # Run tests
  run_test "Standard Dockerfile generation" test_standard_dockerfile
  run_test "Nix-based monorepo Dockerfile generation" test_nix_monorepo_dockerfile
  run_test "npm-based monorepo Dockerfile generation" test_npm_monorepo_dockerfile
  run_test "Monorepo docker-compose generation" test_monorepo_docker_compose
  run_test "Standard docker-compose generation" test_standard_docker_compose
  run_test "Dockerfile variable substitution" test_dockerfile_variable_substitution
  
  # Cleanup
  cleanup_test_environment
  
  # Results
  log "Test Results:"
  log "  Total tests: $TESTS_TOTAL"
  log "  Passed: $TESTS_PASSED"
  log "  Failed: $TESTS_FAILED"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 All tests passed!"
    exit 0
  else
    log_error "❌ Some tests failed!"
    exit 1
  fi
}

# Run main function
main "$@"
