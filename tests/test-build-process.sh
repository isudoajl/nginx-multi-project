#!/bin/bash

# Test script for build process implementation
# This script tests the functionality of the build_process.sh module

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEST_LOG_FILE="${SCRIPT_DIR}/logs/test-build-process.log"
TEST_PROJECT_NAME="test-build-process"
TEST_DOMAIN="test-build.local"
TEST_PORT="8099"
TEST_MONOREPO="${PROJECT_ROOT}/tests/fixtures/monorepo"
TEST_FRONTEND_PATH="packages/frontend"
TEST_FRONTEND_BUILD_DIR="dist"
TEST_FRONTEND_BUILD_CMD="npm run build"
TEST_BACKEND_PATH="packages/backend"
TEST_BACKEND_BUILD_CMD="npm run build"
TEST_BACKEND_START_CMD="npm start"

# Source common functions and utilities
source "${PROJECT_ROOT}/scripts/create-project/modules/common.sh"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Log function for tests
test_log() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | tee -a "$TEST_LOG_FILE"
}

# Test function for assertions
assert() {
  local condition="$1"
  local message="$2"
  
  if eval "$condition"; then
    test_log "✅ PASS: $message"
  else
    test_log "❌ FAIL: $message"
    exit 1
  fi
}

# Setup test environment
setup_test() {
  test_log "Setting up test environment..."
  
  # Create test monorepo fixture if it doesn't exist
  test_log "Creating test monorepo fixture..."
  mkdir -p "${TEST_MONOREPO}"
  mkdir -p "${TEST_MONOREPO}/${TEST_FRONTEND_PATH}"
  mkdir -p "${TEST_MONOREPO}/${TEST_FRONTEND_PATH}/${TEST_FRONTEND_BUILD_DIR}"
  mkdir -p "${TEST_MONOREPO}/${TEST_BACKEND_PATH}"
  
  # Create flake.nix in monorepo root
  cat > "${TEST_MONOREPO}/flake.nix" << EOF
{
  description = "Test monorepo for build process";

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
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.npm
          ];
        };
      }
    );
}
EOF
  
  # Create flake.lock in monorepo root
  cat > "${TEST_MONOREPO}/flake.lock" << EOF
{
  "nodes": {
    "flake-utils": {
      "locked": {
        "lastModified": 1644229661,
        "narHash": "sha256-1YdnJAsNy69bpcjuoKdOYQX0YxZBiCYZo4Twxerqv7k=",
        "owner": "numtide",
        "repo": "flake-utils",
        "rev": "3cecb5b042f7f209c56ffd8371b2711a290ec797",
        "type": "github"
      },
      "original": {
        "owner": "numtide",
        "repo": "flake-utils",
        "type": "github"
      }
    },
    "nixpkgs": {
      "locked": {
        "lastModified": 1644486793,
        "narHash": "sha256-EeijR4guVHgmUoTzaITIIqgL9lWZ/BM5kZM9Z2DqMFI=",
        "owner": "NixOS",
        "repo": "nixpkgs",
        "rev": "1882c6b7368fd284ad01b0a5b5601520d83e42d9",
        "type": "github"
      },
      "original": {
        "owner": "NixOS",
        "ref": "nixos-unstable",
        "repo": "nixpkgs",
        "type": "github"
      }
    },
    "root": {
      "inputs": {
        "flake-utils": "flake-utils",
        "nixpkgs": "nixpkgs"
      }
    }
  },
  "root": "root",
  "version": 7
}
EOF
  
  # Create package.json in frontend directory
  cat > "${TEST_MONOREPO}/${TEST_FRONTEND_PATH}/package.json" << EOF
{
  "name": "test-frontend",
  "version": "1.0.0",
  "description": "Test frontend for build process",
  "scripts": {
    "build": "echo 'Building frontend...' && mkdir -p dist && echo '<!DOCTYPE html><html><body><h1>Test Frontend</h1></body></html>' > dist/index.html"
  }
}
EOF
  
  # Create package.json in backend directory
  cat > "${TEST_MONOREPO}/${TEST_BACKEND_PATH}/package.json" << EOF
{
  "name": "test-backend",
  "version": "1.0.0",
  "description": "Test backend for build process",
  "scripts": {
    "build": "echo 'Building backend...' && echo 'console.log(\"Test Backend\");' > server.js",
    "start": "node server.js"
  }
}
EOF
  
  test_log "Test monorepo fixture created successfully"
  
  # Export required environment variables for the module
  export PROJECT_NAME="$TEST_PROJECT_NAME"
  export DOMAIN_NAME="$TEST_DOMAIN"
  export PROJECT_PORT="$TEST_PORT"
  export USE_NIX_BUILD=true
  export MONO_REPO_PATH="$TEST_MONOREPO"
  export FRONTEND_PATH="$TEST_FRONTEND_PATH"
  export FRONTEND_BUILD_DIR="$TEST_FRONTEND_BUILD_DIR"
  export FRONTEND_BUILD_CMD="$TEST_FRONTEND_BUILD_CMD"
  export BACKEND_PATH="$TEST_BACKEND_PATH"
  export BACKEND_BUILD_CMD="$TEST_BACKEND_BUILD_CMD"
  export BACKEND_START_CMD="$TEST_BACKEND_START_CMD"
  export PROJECTS_DIR="${PROJECT_ROOT}/projects"
  
  # Create project directory
  mkdir -p "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  mkdir -p "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/monorepo"
  mkdir -p "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/build"
  mkdir -p "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/reports"
  
  # Copy test monorepo to project directory
  cp -r "${TEST_MONOREPO}"/* "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/monorepo/"
  
  # Verify that flake.nix was copied correctly
  if [[ ! -f "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/monorepo/flake.nix" ]]; then
    test_log "ERROR: flake.nix was not copied correctly to project monorepo directory"
    ls -la "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/monorepo/"
    exit 1
  else
    test_log "Verified flake.nix exists in project monorepo directory"
  fi
  
  # Create supervisord.conf for testing
  cat > "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/supervisord.conf" << EOF
[program:backend]
command=/bin/sh -c "cd /opt/backend && node src/server.js"
autostart=true
autorestart=true
EOF
  
  test_log "Test environment setup completed"
}

# Clean up test environment
cleanup_test() {
  test_log "Cleaning up test environment..."
  
  # Remove test project directory
  rm -rf "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  test_log "Test environment cleanup completed"
}

# Test detect_nix_environment function
test_detect_nix_environment() {
  test_log "Testing detect_nix_environment function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Call the function
  detect_nix_environment "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  # Check if the symlinks were created
  assert "[[ -L \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/flake.nix.ref\" ]]" "flake.nix.ref symlink created"
  assert "[[ -L \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/flake.lock.ref\" ]]" "flake.lock.ref symlink created"
  
  test_log "detect_nix_environment function test completed"
}

# Test prepare_build_context function
test_prepare_build_context() {
  test_log "Testing prepare_build_context function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Call the function
  prepare_build_context "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  # Check if .dockerignore file was created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/.dockerignore\" ]]" ".dockerignore file created"
  
  # Check if cache directory was created
  assert "[[ -d \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/cache\" ]]" "cache directory created"
  
  test_log "prepare_build_context function test completed"
}

# Test build_frontend function
test_build_frontend() {
  test_log "Testing build_frontend function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Call the function
  build_frontend "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  # Check if build script was created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-frontend.sh\" ]]" "build-frontend.sh script created"
  
  # Check if build script is executable
  assert "[[ -x \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-frontend.sh\" ]]" "build-frontend.sh script is executable"
  
  test_log "build_frontend function test completed"
}

# Test build_backend function
test_build_backend() {
  test_log "Testing build_backend function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Call the function
  build_backend "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  # Check if build script was created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-backend.sh\" ]]" "build-backend.sh script created"
  
  # Check if build script is executable
  assert "[[ -x \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-backend.sh\" ]]" "build-backend.sh script is executable"
  
  # Check if start script was created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/start-backend.sh\" ]]" "start-backend.sh script created"
  
  # Check if start script is executable
  assert "[[ -x \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/start-backend.sh\" ]]" "start-backend.sh script is executable"
  
  # Check if supervisord.conf was updated
  assert "grep -q \"${BACKEND_START_CMD}\" \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/supervisord.conf\"" "supervisord.conf updated with backend start command"
  
  test_log "build_backend function test completed"
}

# Test generate_build_report function
test_generate_build_report() {
  test_log "Testing generate_build_report function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Create a dummy build log
  mkdir -p "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/build"
  local build_log="${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/build/build_test.log"
  echo "Test build log" > "$build_log"
  
  # Call the function
  generate_build_report "${PROJECTS_DIR}/${TEST_PROJECT_NAME}" "$build_log"
  
  # Check if report directory was created
  assert "[[ -d \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/reports\" ]]" "reports directory created"
  
  # Check if at least one report file was created
  assert "ls \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/reports\" | grep -q \"build_report_\"" "build report file created"
  
  test_log "generate_build_report function test completed"
}

# Test optimize_build_performance function
test_optimize_build_performance() {
  test_log "Testing optimize_build_performance function..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Create a dummy Dockerfile
  cat > "${PROJECTS_DIR}/${TEST_PROJECT_NAME}/Dockerfile" << EOF
FROM nixos/nix:latest AS builder
# Rest of the Dockerfile
EOF
  
  # Call the function
  optimize_build_performance "${PROJECTS_DIR}/${TEST_PROJECT_NAME}"
  
  # Check if build-args.env file was created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-args.env\" ]]" "build-args.env file created"
  
  # Check if Dockerfile was updated
  assert "grep -q \"ARG PROJECT_NAME\" \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/Dockerfile\"" "Dockerfile updated with build arguments"
  
  test_log "optimize_build_performance function test completed"
}

# Test build_project function (integration test)
test_build_project() {
  test_log "Testing build_project function (integration test)..."
  
  # Source the build_process.sh module
  source "${PROJECT_ROOT}/scripts/create-project/modules/build_process.sh"
  
  # Call the function
  build_project
  
  # Check if all expected files and directories were created
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/.dockerignore\" ]]" ".dockerignore file created"
  assert "[[ -d \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/cache\" ]]" "cache directory created"
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-frontend.sh\" ]]" "build-frontend.sh script created"
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/build-backend.sh\" ]]" "build-backend.sh script created"
  assert "[[ -f \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/start-backend.sh\" ]]" "start-backend.sh script created"
  assert "[[ -d \"${PROJECTS_DIR}/${TEST_PROJECT_NAME}/logs/reports\" ]]" "reports directory created"
  
  test_log "build_project function integration test completed"
}

# Run the tests
run_tests() {
  test_log "Starting build process implementation tests..."
  
  # Setup test environment
  setup_test
  
  # Run individual function tests
  test_detect_nix_environment
  test_prepare_build_context
  test_build_frontend
  test_build_backend
  test_generate_build_report
  test_optimize_build_performance
  
  # Run integration test
  test_build_project
  
  # Clean up test environment
  cleanup_test
  
  test_log "All tests completed successfully! ✅"
}

# Run the tests
run_tests 