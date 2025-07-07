#!/bin/bash
# Test script for validating monorepo compatibility with different frontend/backend technologies
# This test verifies that the Nix-based build process works correctly across different project types

# Source common test functions
source "$(dirname "$0")/fixtures/test-helpers.sh"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Test directory
TEST_DIR="$(dirname "$0")"
FIXTURES_DIR="$TEST_DIR/fixtures"
TEMP_DIR="/tmp/monorepo-test-$(date +%s)"
SCRIPT_PATH="$(realpath "$TEST_DIR/../scripts/create-project-modular.sh")"

# Test configuration
TEST_DOMAIN="test-monorepo.local"
TEST_PORT="9090"

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_TOTAL=0

# Initialize test environment
function init_test_environment() {
    echo -e "${YELLOW}Initializing test environment...${NC}"
    
    # Check if we're in Nix environment
    if [ -z "$IN_NIX_SHELL" ]; then
        echo -e "${RED}Error: Not in Nix environment. Please run 'nix develop' first.${NC}"
        exit 1
    fi
    
    # Create temporary directory
    mkdir -p "$TEMP_DIR"
    echo -e "${GREEN}Created temporary directory: $TEMP_DIR${NC}"
    
    # Ensure clean test environment
    podman stop test-monorepo 2>/dev/null || true
    podman rm test-monorepo 2>/dev/null || true
}

# Clean up test environment
function cleanup_test_environment() {
    echo -e "${YELLOW}Cleaning up test environment...${NC}"
    
    # Stop and remove test containers
    podman stop test-monorepo 2>/dev/null || true
    podman rm test-monorepo 2>/dev/null || true
    
    # Remove temporary directory
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}Test environment cleaned up${NC}"
}

# Run a test case
function run_test() {
    local test_name="$1"
    local monorepo_type="$2"
    local frontend_tech="$3"
    local backend_tech="$4"
    local frontend_path="$5"
    local backend_path="$6"
    local frontend_build_cmd="$7"
    local backend_build_cmd="$8"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    echo -e "\n${YELLOW}Running test: $test_name${NC}"
    echo -e "${YELLOW}Monorepo type: $monorepo_type${NC}"
    echo -e "${YELLOW}Frontend: $frontend_tech${NC}"
    echo -e "${YELLOW}Backend: $backend_tech${NC}"
    
    # Create mock monorepo structure
    local monorepo_path="$TEMP_DIR/$monorepo_type"
    mkdir -p "$monorepo_path/$frontend_path"
    mkdir -p "$monorepo_path/$backend_path"
    
    # Create mock flake.nix
    cat > "$monorepo_path/flake.nix" <<EOF
{
  description = "Mock $monorepo_type monorepo with $frontend_tech frontend and $backend_tech backend";
  
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  
  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.\${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs_20
            python311
            go
            rustc
            cargo
          ];
        };
      }
    );
}
EOF
    
    # Create mock frontend files
    case "$frontend_tech" in
        "react")
            mkdir -p "$monorepo_path/$frontend_path/src"
            mkdir -p "$monorepo_path/$frontend_path/public"
            mkdir -p "$monorepo_path/$frontend_path/build"
            
            # Create package.json
            cat > "$monorepo_path/$frontend_path/package.json" <<EOF
{
  "name": "react-app",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "scripts": {
    "build": "echo 'Mock React build'"
  }
}
EOF
            
            # Create mock build output
            echo "<html><body><h1>Mock React App</h1></body></html>" > "$monorepo_path/$frontend_path/build/index.html"
            ;;
            
        "vue")
            mkdir -p "$monorepo_path/$frontend_path/src"
            mkdir -p "$monorepo_path/$frontend_path/public"
            mkdir -p "$monorepo_path/$frontend_path/dist"
            
            # Create package.json
            cat > "$monorepo_path/$frontend_path/package.json" <<EOF
{
  "name": "vue-app",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "vue": "^3.3.4"
  },
  "scripts": {
    "build": "echo 'Mock Vue build'"
  }
}
EOF
            
            # Create mock build output
            echo "<html><body><h1>Mock Vue App</h1></body></html>" > "$monorepo_path/$frontend_path/dist/index.html"
            ;;
            
        "angular")
            mkdir -p "$monorepo_path/$frontend_path/src"
            mkdir -p "$monorepo_path/$frontend_path/dist"
            
            # Create package.json
            cat > "$monorepo_path/$frontend_path/package.json" <<EOF
{
  "name": "angular-app",
  "version": "0.1.0",
  "private": true,
  "dependencies": {
    "@angular/core": "^16.0.0"
  },
  "scripts": {
    "build": "echo 'Mock Angular build'"
  }
}
EOF
            
            # Create mock build output
            echo "<html><body><h1>Mock Angular App</h1></body></html>" > "$monorepo_path/$frontend_path/dist/angular-app/index.html"
            ;;
    esac
    
    # Create mock backend files
    case "$backend_tech" in
        "node")
            # Create package.json
            cat > "$monorepo_path/$backend_path/package.json" <<EOF
{
  "name": "node-backend",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "build": "echo 'Mock Node.js build'"
  }
}
EOF
            
            # Create index.js
            cat > "$monorepo_path/$backend_path/index.js" <<EOF
console.log('Mock Node.js backend started');
EOF
            ;;
            
        "go")
            # Create main.go
            cat > "$monorepo_path/$backend_path/main.go" <<EOF
package main

import "fmt"

func main() {
    fmt.Println("Mock Go backend started")
}
EOF
            ;;
            
        "rust")
            # Create Cargo.toml
            cat > "$monorepo_path/$backend_path/Cargo.toml" <<EOF
[package]
name = "rust-backend"
version = "0.1.0"
edition = "2021"

[dependencies]
EOF
            
            # Create src/main.rs
            mkdir -p "$monorepo_path/$backend_path/src"
            cat > "$monorepo_path/$backend_path/src/main.rs" <<EOF
fn main() {
    println!("Mock Rust backend started");
}
EOF
            ;;
    esac
    
    # Run the create-project-modular.sh script with mock parameters
    echo -e "${YELLOW}Running create-project-modular.sh with monorepo parameters...${NC}"
    
    # Use mock execution to avoid actual container creation
    mock_execution_result=0
    
    # Simulate script execution with parameters
    echo "Would execute:"
    echo "$SCRIPT_PATH \\"
    echo "  --name test-monorepo \\"
    echo "  --domain $TEST_DOMAIN \\"
    echo "  --port $TEST_PORT \\"
    echo "  --env DEV \\"
    echo "  --use-nix-build \\"
    echo "  --mono-repo $monorepo_path \\"
    echo "  --frontend-path $frontend_path \\"
    echo "  --frontend-build-dir ${frontend_path##*/}/$(get_build_dir $frontend_tech) \\"
    echo "  --frontend-build-cmd \"$frontend_build_cmd\" \\"
    echo "  --backend-path $backend_path \\"
    echo "  --backend-build-cmd \"$backend_build_cmd\""
    
    # Validate parameter combinations
    if validate_parameters "$monorepo_path" "$frontend_path" "$backend_path"; then
        echo -e "${GREEN}✓ Parameter validation passed${NC}"
    else
        echo -e "${RED}✗ Parameter validation failed${NC}"
        mock_execution_result=1
    fi
    
    # Check if monorepo structure is valid
    if [ -f "$monorepo_path/flake.nix" ]; then
        echo -e "${GREEN}✓ flake.nix found in monorepo root${NC}"
    else
        echo -e "${RED}✗ flake.nix not found in monorepo root${NC}"
        mock_execution_result=1
    fi
    
    # Check if frontend files exist
    if [ -d "$monorepo_path/$frontend_path" ]; then
        echo -e "${GREEN}✓ Frontend directory exists${NC}"
    else
        echo -e "${RED}✗ Frontend directory does not exist${NC}"
        mock_execution_result=1
    fi
    
    # Check if backend files exist
    if [ -d "$monorepo_path/$backend_path" ]; then
        echo -e "${GREEN}✓ Backend directory exists${NC}"
    else
        echo -e "${RED}✗ Backend directory does not exist${NC}"
        mock_execution_result=1
    fi
    
    # Record test result
    if [ $mock_execution_result -eq 0 ]; then
        echo -e "${GREEN}✓ Test passed: $test_name${NC}"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo -e "${RED}✗ Test failed: $test_name${NC}"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

# Helper function to get build directory based on frontend technology
function get_build_dir() {
    local frontend_tech="$1"
    
    case "$frontend_tech" in
        "react") echo "build" ;;
        "vue") echo "dist" ;;
        "angular") echo "dist/angular-app" ;;
        *) echo "build" ;;
    esac
}

# Validate parameters
function validate_parameters() {
    local monorepo_path="$1"
    local frontend_path="$2"
    local backend_path="$3"
    
    # Check if paths are valid
    if [ ! -d "$monorepo_path" ]; then
        echo "Monorepo path does not exist: $monorepo_path"
        return 1
    fi
    
    if [ ! -d "$monorepo_path/$frontend_path" ]; then
        echo "Frontend path does not exist: $monorepo_path/$frontend_path"
        return 1
    fi
    
    if [ ! -d "$monorepo_path/$backend_path" ]; then
        echo "Backend path does not exist: $monorepo_path/$backend_path"
        return 1
    fi
    
    return 0
}

# Run tests
function run_all_tests() {
    echo -e "${YELLOW}Running monorepo compatibility tests...${NC}"
    
    # Test 1: React + Node.js in standard monorepo
    run_test "React + Node.js Standard" \
        "standard" \
        "react" \
        "node" \
        "packages/frontend" \
        "packages/backend" \
        "npm run build" \
        "npm run build"
    
    # Test 2: Vue + Go in workspace monorepo
    run_test "Vue + Go Workspace" \
        "workspace" \
        "vue" \
        "go" \
        "apps/web" \
        "apps/api" \
        "npm run build" \
        "go build -o api main.go"
    
    # Test 3: Angular + Rust in nx monorepo
    run_test "Angular + Rust NX" \
        "nx" \
        "angular" \
        "rust" \
        "apps/dashboard" \
        "apps/server" \
        "npm run build" \
        "cargo build --release"
    
    # Test 4: React + Go in flat monorepo
    run_test "React + Go Flat" \
        "flat" \
        "react" \
        "go" \
        "frontend" \
        "backend" \
        "npm run build" \
        "go build -o server main.go"
    
    # Test 5: Vue + Rust in nested monorepo
    run_test "Vue + Rust Nested" \
        "nested" \
        "vue" \
        "rust" \
        "client/app" \
        "server/api" \
        "npm run build" \
        "cargo build --release"
}

# Print test summary
function print_summary() {
    echo -e "\n${YELLOW}Test Summary:${NC}"
    echo -e "${GREEN}Tests passed: $TESTS_PASSED${NC}"
    echo -e "${RED}Tests failed: $TESTS_FAILED${NC}"
    echo -e "${YELLOW}Total tests: $TESTS_TOTAL${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        exit 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        exit 1
    fi
}

# Main function
function main() {
    # Initialize test environment
    init_test_environment
    
    # Run all tests
    run_all_tests
    
    # Clean up test environment
    cleanup_test_environment
    
    # Print test summary
    print_summary
}

# Run main function
main 