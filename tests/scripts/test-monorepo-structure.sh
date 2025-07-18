#!/bin/bash

# Test script for monorepo project structure functionality
# Tests the project structure setup for monorepo projects

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/temp/structure-test"
PROJECT_STRUCTURE_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/project_structure.sh"
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
  
  # Create mock certificate directories
  mkdir -p "$TEST_DIR/certs"
  
  # Create mock certificates
  echo "mock-cert-content" > "$TEST_DIR/certs/cert.pem"
  echo "mock-key-content" > "$TEST_DIR/certs/cert-key.pem"
  
  # Create mock monorepo structures
  mkdir -p "$TEST_DIR/nix-monorepo/frontend"
  mkdir -p "$TEST_DIR/nix-monorepo/dist"
  mkdir -p "$TEST_DIR/npm-monorepo/web"
  mkdir -p "$TEST_DIR/npm-monorepo/web/dist"
  
  # Create mock flake.nix for Nix monorepo
  cat > "$TEST_DIR/nix-monorepo/flake.nix" << 'EOF'
{
  description = "Mock Nix monorepo for testing";
}
EOF

  # Create mock package.json files
  cat > "$TEST_DIR/nix-monorepo/frontend/package.json" << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building frontend...'"
  }
}
EOF

  cat > "$TEST_DIR/npm-monorepo/web/package.json" << 'EOF'
{
  "name": "web-frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building web frontend...'"
  }
}
EOF

  # Create projects directory
  mkdir -p "$TEST_DIR/projects"
  
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
  export PROJECTS_DIR="$TEST_DIR/projects"
  export CERTS_DIR="$TEST_DIR/certs"
  
  # Create log file
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  
  # Source modules
  source "$COMMON_MODULE"
  source "$ARGS_MODULE"
  source "$PROJECT_STRUCTURE_MODULE"
}

# Test 1: Standard project structure setup
function test_standard_project_structure() {
  # Setup variables for standard project
  IS_MONOREPO=false
  PROJECT_NAME="test-standard"
  DOMAIN_NAME="test-standard.local"
  
  # Setup project structure
  setup_project_structure
  
  local project_dir="$PROJECTS_DIR/$PROJECT_NAME"
  
  # Verify standard directories were created
  if [[ ! -d "$project_dir/html" ]]; then
    return 1
  fi
  
  if [[ ! -d "$project_dir/conf.d" ]]; then
    return 1
  fi
  
  if [[ ! -d "$project_dir/logs" ]]; then
    return 1
  fi
  
  if [[ ! -d "$project_dir/certs" ]]; then
    return 1
  fi
  
  # Verify health endpoint was created
  if [[ ! -f "$project_dir/html/health/index.html" ]]; then
    return 1
  fi
  
  if [[ "$(cat "$project_dir/html/health/index.html")" != "OK" ]]; then
    return 1
  fi
  
  # Verify certificates were copied
  if [[ ! -f "$project_dir/certs/cert.pem" ]]; then
    return 1
  fi
  
  if [[ ! -f "$project_dir/certs/cert-key.pem" ]]; then
    return 1
  fi
  
  return 0
}

# Test 2: Monorepo project structure setup
function test_monorepo_project_structure() {
  # Setup variables for monorepo project
  IS_MONOREPO=true
  USE_EXISTING_NIX=true
  PROJECT_NAME="test-monorepo"
  DOMAIN_NAME="test-monorepo.local"
  MONOREPO_DIR="$TEST_DIR/nix-monorepo"
  FRONTEND_SUBDIR="frontend"
  BUILD_OUTPUT_DIR="dist"
  NIX_BUILD_CMD="nix build .#frontend"
  FRONTEND_BUILD_CMD="npm run build"
  
  # Setup project structure
  setup_project_structure
  
  local project_dir="$PROJECTS_DIR/$PROJECT_NAME"
  
  # Verify necessary directories were created
  if [[ ! -d "$project_dir/conf.d" ]]; then
    return 1
  fi
  
  if [[ ! -d "$project_dir/logs" ]]; then
    return 1
  fi
  
  if [[ ! -d "$project_dir/certs" ]]; then
    return 1
  fi
  
  # Verify html directory was NOT created (content comes from build)
  if [[ -d "$project_dir/html" ]]; then
    return 1
  fi
  
  # Verify monorepo.env file was created
  if [[ ! -f "$project_dir/monorepo.env" ]]; then
    return 1
  fi
  
  # Verify monorepo configuration content
  if ! grep -q "MONOREPO_DIR=$MONOREPO_DIR" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  if ! grep -q "FRONTEND_SUBDIR=$FRONTEND_SUBDIR" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  if ! grep -q "BUILD_OUTPUT_DIR=$BUILD_OUTPUT_DIR" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  if ! grep -q "USE_EXISTING_NIX=$USE_EXISTING_NIX" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  # Verify certificates were copied
  if [[ ! -f "$project_dir/certs/cert.pem" ]]; then
    return 1
  fi
  
  if [[ ! -f "$project_dir/certs/cert-key.pem" ]]; then
    return 1
  fi
  
  return 0
}

# Test 3: Domain-specific certificate handling
function test_domain_specific_certificates() {
  # Setup variables
  IS_MONOREPO=false
  PROJECT_NAME="test-domain-certs"
  DOMAIN_NAME="test-domain.local"
  
  # Setup project structure
  setup_project_structure
  
  # Verify domain-specific certificate directory was created
  local domain_certs_dir="$CERTS_DIR/$DOMAIN_NAME"
  if [[ ! -d "$domain_certs_dir" ]]; then
    return 1
  fi
  
  # Verify certificates were copied to domain directory
  if [[ ! -f "$domain_certs_dir/cert.pem" ]]; then
    return 1
  fi
  
  if [[ ! -f "$domain_certs_dir/cert-key.pem" ]]; then
    return 1
  fi
  
  # Verify certificates were then copied to project
  local project_dir="$PROJECTS_DIR/$PROJECT_NAME"
  if [[ ! -f "$project_dir/certs/cert.pem" ]]; then
    return 1
  fi
  
  if [[ ! -f "$project_dir/certs/cert-key.pem" ]]; then
    return 1
  fi
  
  return 0
}

# Test 4: Monorepo path validation
function test_monorepo_path_validation() {
  # Setup variables with invalid monorepo path
  IS_MONOREPO=true
  PROJECT_NAME="test-invalid-path"
  DOMAIN_NAME="test-invalid.local"
  MONOREPO_DIR="/non/existent/path"
  FRONTEND_SUBDIR="frontend"
  
  # Override handle_error to not exit during test
  function handle_error() {
    log_error "TEST: $1"
    return 1
  }
  
  # This should fail with error
  if setup_project_structure 2>/dev/null; then
    return 1  # Test should have failed
  fi
  
  # Restore original handle_error function
  source "$COMMON_MODULE"
  
  return 0  # Expected failure
}

# Test 5: Frontend subdirectory validation
function test_frontend_subdir_validation() {
  # Setup variables with invalid frontend subdirectory
  IS_MONOREPO=true
  PROJECT_NAME="test-invalid-subdir"
  DOMAIN_NAME="test-invalid-subdir.local"
  MONOREPO_DIR="$TEST_DIR/nix-monorepo"
  FRONTEND_SUBDIR="nonexistent"
  
  # Override handle_error to not exit during test
  function handle_error() {
    log_error "TEST: $1"
    return 1
  }
  
  # This should fail with error
  if setup_project_structure 2>/dev/null; then
    return 1  # Test should have failed
  fi
  
  # Restore original handle_error function
  source "$COMMON_MODULE"
  
  return 0  # Expected failure
}

# Test 6: npm-based monorepo structure
function test_npm_monorepo_structure() {
  # Setup variables for npm-based monorepo
  IS_MONOREPO=true
  USE_EXISTING_NIX=false
  PROJECT_NAME="test-npm-monorepo"
  DOMAIN_NAME="test-npm-monorepo.local"
  MONOREPO_DIR="$TEST_DIR/npm-monorepo"
  FRONTEND_SUBDIR="web"
  BUILD_OUTPUT_DIR="dist"
  NIX_BUILD_CMD=""
  FRONTEND_BUILD_CMD="npm run build"
  
  # Setup project structure
  setup_project_structure
  
  local project_dir="$PROJECTS_DIR/$PROJECT_NAME"
  
  # Verify monorepo.env file contains correct npm configuration
  if [[ ! -f "$project_dir/monorepo.env" ]]; then
    return 1
  fi
  
  if ! grep -q "USE_EXISTING_NIX=false" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  if ! grep -q "FRONTEND_BUILD_CMD=npm run build" "$project_dir/monorepo.env"; then
    return 1
  fi
  
  return 0
}

# Test 7: Certificate error handling
function test_certificate_error_handling() {
  # Remove mock certificates to trigger error
  rm -f "$TEST_DIR/certs/cert.pem"
  rm -f "$TEST_DIR/certs/cert-key.pem"
  
  # Also remove any domain-specific certificates that might exist
  rm -rf "$TEST_DIR/certs/test-cert-error.local"
  
  # Setup variables
  IS_MONOREPO=false
  PROJECT_NAME="test-cert-error"
  DOMAIN_NAME="test-cert-error.local"
  
  # Override handle_error to not exit during test
  function handle_error() {
    log_error "TEST: $1"
    return 1
  }
  
  # This should fail with certificate error
  if setup_project_structure 2>/dev/null; then
    return 1  # Test should have failed
  fi
  
  # Restore original handle_error function
  source "$COMMON_MODULE"
  
  # Restore certificates for other tests
  echo "mock-cert-content" > "$TEST_DIR/certs/cert.pem"
  echo "mock-key-content" > "$TEST_DIR/certs/cert-key.pem"
  
  return 0  # Expected failure
}

# Main test runner
function main() {
  log "Starting monorepo project structure tests..."
  log "Project root: $PROJECT_ROOT"
  
  # Check if Nix environment is available
  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    log_warn "Not running in Nix shell - some tests may not work as expected"
  fi
  
  # Setup
  setup_test_environment
  source_modules
  
  # Run tests
  run_test "Standard project structure setup" test_standard_project_structure
  run_test "Monorepo project structure setup" test_monorepo_project_structure
  run_test "Domain-specific certificate handling" test_domain_specific_certificates
  run_test "Monorepo path validation" test_monorepo_path_validation
  run_test "Frontend subdirectory validation" test_frontend_subdir_validation
  run_test "npm-based monorepo structure" test_npm_monorepo_structure
  run_test "Certificate error handling" test_certificate_error_handling
  
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
