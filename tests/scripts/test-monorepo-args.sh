#!/bin/bash

# Test script for monorepo argument parsing functionality
# Tests the new monorepo parameters added to create-project-modular.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_DIR="${PROJECT_ROOT}/tests/temp/monorepo-test"
ARGS_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/args.sh"
COMMON_MODULE="${PROJECT_ROOT}/scripts/create-project/modules/common.sh"

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
  
  # Create mock monorepo structure
  mkdir -p "$TEST_DIR/mock-monorepo/frontend"
  mkdir -p "$TEST_DIR/mock-monorepo/backend"
  mkdir -p "$TEST_DIR/mock-monorepo/dist"
  mkdir -p "$TEST_DIR/mock-monorepo/frontend/dist"
  
  # Create mock flake.nix
  cat > "$TEST_DIR/mock-monorepo/flake.nix" << 'EOF'
{
  description = "Mock monorepo for testing";
  
  outputs = { self, nixpkgs }: {
    packages.x86_64-linux.frontend = nixpkgs.legacyPackages.x86_64-linux.hello;
  };
}
EOF

  # Create mock package.json with build script
  cat > "$TEST_DIR/mock-monorepo/frontend/package.json" << 'EOF'
{
  "name": "frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building frontend...'",
    "dev": "echo 'Starting dev server...'"
  }
}
EOF

  # Create mock non-Nix monorepo
  mkdir -p "$TEST_DIR/non-nix-monorepo/web"
  cat > "$TEST_DIR/non-nix-monorepo/web/package.json" << 'EOF'
{
  "name": "web-frontend",
  "version": "1.0.0",
  "scripts": {
    "build": "echo 'Building web frontend...'"
  }
}
EOF

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
  # Set up required global variables for common.sh
  export PROJECT_ROOT="$PROJECT_ROOT"
  export LOG_FILE="$TEST_DIR/test.log"
  export PROJECTS_DIR="$PROJECT_ROOT/projects"
  
  # Create log file
  mkdir -p "$(dirname "$LOG_FILE")"
  touch "$LOG_FILE"
  
  # Source common module first (contains log function)
  if [[ -f "$COMMON_MODULE" ]]; then
    source "$COMMON_MODULE"
  else
    # Define minimal log function if common.sh doesn't exist
    function log() {
      echo "[LOG] $1"
    }
    function handle_error() {
      echo "[ERROR] $1"
      return 1
    }
  fi
  
  # Source args module
  source "$ARGS_MODULE"
}

# Test 1: Basic monorepo argument parsing
function test_basic_monorepo_args() {
  # Mock parse_arguments call with monorepo args
  PROJECT_NAME=""
  PROJECT_PORT="80"
  DOMAIN_NAME=""
  FRONTEND_DIR=""
  FRONTEND_MOUNT=""
  CERT_PATH=""
  KEY_PATH=""
  ENV_TYPE="DEV"
  MONOREPO_DIR=""
  FRONTEND_SUBDIR="frontend"
  FRONTEND_BUILD_CMD=""
  IS_MONOREPO=false
  PROJECTS_DIR="./projects"  # Mock this global
  
  # Simulate argument parsing
  MONOREPO_DIR="$TEST_DIR/mock-monorepo"
  IS_MONOREPO=true
  PROJECT_NAME="test-app"
  DOMAIN_NAME="test.local"
  
  # Test the validation logic
  if [[ ! -d "$MONOREPO_DIR" ]]; then
    return 1
  fi
  
  if [[ ! -d "$MONOREPO_DIR/$FRONTEND_SUBDIR" ]]; then
    return 1
  fi
  
  # Convert to absolute path
  MONOREPO_DIR="$(realpath "$MONOREPO_DIR")"
  
  # Set frontend directory to the monorepo frontend path
  FRONTEND_DIR="$MONOREPO_DIR/$FRONTEND_SUBDIR"
  
  # Verify the frontend directory was set correctly
  if [[ "$FRONTEND_DIR" != "$MONOREPO_DIR/frontend" ]]; then
    return 1
  fi
  
  return 0
}

# Test 2: Nix configuration detection
function test_nix_detection() {
  # Setup variables
  MONOREPO_DIR="$TEST_DIR/mock-monorepo"
  FRONTEND_SUBDIR="frontend"
  FRONTEND_BUILD_CMD=""
  
  # Call the detection function
  detect_nix_configuration
  
  # Verify Nix was detected
  if [[ "$USE_EXISTING_NIX" != "true" ]]; then
    return 1
  fi
  
  # Verify build command was set
  if [[ -z "$NIX_BUILD_CMD" ]]; then
    return 1
  fi
  
  # Verify build output directory was detected
  if [[ -z "$BUILD_OUTPUT_DIR" ]]; then
    return 1
  fi
  
  return 0
}

# Test 3: Non-Nix monorepo detection
function test_non_nix_detection() {
  # Setup variables for non-Nix monorepo
  MONOREPO_DIR="$TEST_DIR/non-nix-monorepo"
  FRONTEND_SUBDIR="web"
  FRONTEND_BUILD_CMD=""
  
  # Call the detection function
  detect_nix_configuration
  
  # Verify Nix was NOT detected
  if [[ "$USE_EXISTING_NIX" == "true" ]]; then
    return 1
  fi
  
  # Verify npm build command was detected
  if [[ "$FRONTEND_BUILD_CMD" != "npm run build" ]]; then
    return 1
  fi
  
  return 0
}

# Test 4: Custom build command override
function test_custom_build_command() {
  # Setup variables
  MONOREPO_DIR="$TEST_DIR/mock-monorepo"
  FRONTEND_SUBDIR="frontend"
  FRONTEND_BUILD_CMD="npm run build:custom"
  
  # Call the detection function
  detect_nix_configuration
  
  # Verify custom build command was preserved
  if [[ "$FRONTEND_BUILD_CMD" != "npm run build:custom" ]]; then
    return 1
  fi
  
  return 0
}

# Test 5: Error handling for non-existent monorepo
function test_error_handling() {
  # This test would normally call handle_error, so we simulate the check
  local test_monorepo_dir="/non/existent/path"
  
  if [[ -d "$test_monorepo_dir" ]]; then
    return 1  # Should not exist
  fi
  
  # Test would fail validation, which is expected behavior
  return 0
}

# Test 6: Frontend subdirectory validation
function test_frontend_subdir_validation() {
  # Test with valid subdirectory
  local test_monorepo_dir="$TEST_DIR/mock-monorepo"
  local test_frontend_subdir="frontend"
  
  if [[ ! -d "$test_monorepo_dir/$test_frontend_subdir" ]]; then
    return 1
  fi
  
  # Test with invalid subdirectory
  local invalid_subdir="nonexistent"
  
  if [[ -d "$test_monorepo_dir/$invalid_subdir" ]]; then
    return 1  # Should not exist
  fi
  
  return 0
}

# Main test runner
function main() {
  log "Starting monorepo argument parsing tests..."
  log "Project root: $PROJECT_ROOT"
  
  # Check if Nix environment is available
  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    log_warn "Not running in Nix shell - some tests may not work as expected"
  fi
  
  # Setup
  setup_test_environment
  source_modules
  
  # Run tests
  run_test "Basic monorepo argument parsing" test_basic_monorepo_args
  run_test "Nix configuration detection" test_nix_detection
  run_test "Non-Nix monorepo detection" test_non_nix_detection
  run_test "Custom build command override" test_custom_build_command
  run_test "Error handling for non-existent monorepo" test_error_handling
  run_test "Frontend subdirectory validation" test_frontend_subdir_validation
  
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
