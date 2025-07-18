#!/bin/bash

# Integration test for monorepo deployment functionality
# Tests end-to-end monorepo deployment with the test monorepo project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TEST_MONOREPO_DIR="${PROJECT_ROOT}/tests/test-monorepo-project"
TEST_PROJECT_NAME="test-monorepo-$(date +%s)"
TEST_DOMAIN="${TEST_PROJECT_NAME}.local"
TEST_PORT="8095"

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

function log_test() {
  echo -e "${BLUE}[TEST]${NC} $1"
}

function handle_error() {
  log_error "$1"
  cleanup_test_deployment
  exit 1
}

# Function to run a test
function run_test() {
  local test_name="$1"
  local test_function="$2"
  
  TESTS_TOTAL=$((TESTS_TOTAL + 1))
  log_test "Running test: $test_name"
  
  if $test_function; then
    log "✅ PASSED: $test_name"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    log_error "❌ FAILED: $test_name"
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
  echo ""
}

# Cleanup function
function cleanup_test_deployment() {
  log "Cleaning up test deployment..."
  
  # Stop and remove test containers
  if command -v podman &> /dev/null; then
    podman stop "$TEST_PROJECT_NAME" 2>/dev/null || true
    podman rm "$TEST_PROJECT_NAME" 2>/dev/null || true
  elif command -v docker &> /dev/null; then
    docker stop "$TEST_PROJECT_NAME" 2>/dev/null || true
    docker rm "$TEST_PROJECT_NAME" 2>/dev/null || true
  fi
  
  # Remove test project directory
  rm -rf "${PROJECT_ROOT}/projects/${TEST_PROJECT_NAME}"
  
  # Remove proxy configuration file for test domain
  rm -f "${PROJECT_ROOT}/proxy/conf.d/domains/${TEST_DOMAIN}.conf"
  
  # Reload nginx-proxy to apply configuration changes
  if command -v podman &> /dev/null; then
    podman exec nginx-proxy nginx -s reload 2>/dev/null || true
  elif command -v docker &> /dev/null; then
    docker exec nginx-proxy nginx -s reload 2>/dev/null || true
  fi
  
  log "Cleanup complete"
}

# Test 1: Validate test monorepo structure
function test_monorepo_structure() {
  log "Validating test monorepo structure..."
  
  # Check if test monorepo directory exists
  if [[ ! -d "$TEST_MONOREPO_DIR" ]]; then
    log_error "Test monorepo directory not found: $TEST_MONOREPO_DIR"
    return 1
  fi
  
  # Check for flake.nix
  if [[ ! -f "$TEST_MONOREPO_DIR/flake.nix" ]]; then
    log_error "flake.nix not found in test monorepo"
    return 1
  fi
  
  # Check for frontend directory
  if [[ ! -d "$TEST_MONOREPO_DIR/frontend" ]]; then
    log_error "Frontend directory not found in test monorepo"
    return 1
  fi
  
  # Check for package.json
  if [[ ! -f "$TEST_MONOREPO_DIR/frontend/package.json" ]]; then
    log_error "package.json not found in frontend directory"
    return 1
  fi
  
  # Check for frontend source files
  if [[ ! -f "$TEST_MONOREPO_DIR/frontend/src/index.html" ]]; then
    log_error "Frontend source files not found"
    return 1
  fi
  
  log "Test monorepo structure validation passed"
  return 0
}

# Test 2: Validate Nix environment
function test_nix_environment() {
  log "Validating Nix environment..."
  
  # Check if running in Nix shell
  if [[ -z "${IN_NIX_SHELL:-}" ]]; then
    log_error "Not running in Nix shell - required for monorepo deployment"
    return 1
  fi
  
  # Check if nix command is available
  if ! command -v nix &> /dev/null; then
    log_error "Nix command not available"
    return 1
  fi
  
  # Check if container engine is available
  if ! command -v podman &> /dev/null && ! command -v docker &> /dev/null; then
    log_error "No container engine (podman/docker) available"
    return 1
  fi
  
  log "Nix environment validation passed"
  return 0
}

# Test 3: Test frontend build in monorepo
function test_frontend_build() {
  log "Testing frontend build in monorepo..."
  
  # Change to monorepo directory
  pushd "$TEST_MONOREPO_DIR" > /dev/null
  
  # Test npm build
  pushd frontend > /dev/null
  
  # Clean any existing dist
  rm -rf dist
  
  # Run npm build
  if ! npm run build; then
    log_error "npm build failed"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  
  # Check if dist directory was created
  if [[ ! -d "dist" ]]; then
    log_error "dist directory not created by build"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  
  # Check if index.html was copied
  if [[ ! -f "dist/index.html" ]]; then
    log_error "index.html not found in dist directory"
    popd > /dev/null
    popd > /dev/null
    return 1
  fi
  
  popd > /dev/null
  popd > /dev/null
  
  log "Frontend build test passed"
  return 0
}

# Test 4: Test monorepo deployment
function test_monorepo_deployment() {
  log "Testing monorepo deployment..."
  
  # Check if certificates exist
  if [[ ! -f "${PROJECT_ROOT}/certs/cert.pem" || ! -f "${PROJECT_ROOT}/certs/cert-key.pem" ]]; then
    log_warn "SSL certificates not found - generating self-signed certificates for testing"
    
    # Generate test certificates
    mkdir -p "${PROJECT_ROOT}/certs"
    
    # Generate self-signed certificate for testing
    openssl req -x509 -newkey rsa:4096 -keyout "${PROJECT_ROOT}/certs/cert-key.pem" \
      -out "${PROJECT_ROOT}/certs/cert.pem" -days 365 -nodes \
      -subj "/C=US/ST=Test/L=Test/O=Test/CN=$TEST_DOMAIN" 2>/dev/null || {
      log_error "Failed to generate test certificates"
      return 1
    }
  fi
  
  # Run the deployment script
  if ! "${PROJECT_ROOT}/scripts/create-project-modular.sh" \
    --name "$TEST_PROJECT_NAME" \
    --domain "$TEST_DOMAIN" \
    --port "$TEST_PORT" \
    --monorepo "$TEST_MONOREPO_DIR" \
    --frontend-dir frontend \
    --env DEV; then
    log_error "Monorepo deployment failed"
    return 1
  fi
  
  log "Monorepo deployment test passed"
  return 0
}

# Test 5: Validate deployment artifacts
function test_deployment_artifacts() {
  log "Validating deployment artifacts..."
  
  # Check if project directory was created
  local project_dir="${PROJECT_ROOT}/projects/${TEST_PROJECT_NAME}"
  if [[ ! -d "$project_dir" ]]; then
    log_error "Project directory not created: $project_dir"
    return 1
  fi
  
  # Check for Dockerfile
  if [[ ! -f "$project_dir/Dockerfile" ]]; then
    log_error "Dockerfile not found in project directory"
    return 1
  fi
  
  # Check for docker-compose.yml
  if [[ ! -f "$project_dir/docker-compose.yml" ]]; then
    log_error "docker-compose.yml not found in project directory"
    return 1
  fi
  
  # Check for nginx configuration
  if [[ ! -f "$project_dir/nginx.conf" ]]; then
    log_error "nginx.conf not found in project directory"
    return 1
  fi
  
  # Check for monorepo.env file
  if [[ ! -f "$project_dir/monorepo.env" ]]; then
    log_error "monorepo.env not found in project directory"
    return 1
  fi
  
  # Validate monorepo.env contents
  if ! grep -q "IS_MONOREPO=true" "$project_dir/monorepo.env"; then
    log_error "monorepo.env does not contain IS_MONOREPO=true"
    return 1
  fi
  
  if ! grep -q "MONOREPO_DIR=" "$project_dir/monorepo.env"; then
    log_error "monorepo.env does not contain MONOREPO_DIR"
    return 1
  fi
  
  log "Deployment artifacts validation passed"
  return 0
}

# Test 6: Validate container deployment
function test_container_deployment() {
  log "Validating container deployment..."
  
  # Determine container engine
  local container_engine=""
  if command -v podman &> /dev/null; then
    container_engine="podman"
  elif command -v docker &> /dev/null; then
    container_engine="docker"
  else
    log_error "No container engine available"
    return 1
  fi
  
  # Check if container is running
  if ! $container_engine ps --format "table {{.Names}}" | grep -q "^$TEST_PROJECT_NAME$"; then
    log_error "Container $TEST_PROJECT_NAME is not running"
    return 1
  fi
  
  # Check container health
  local container_status
  container_status=$($container_engine inspect "$TEST_PROJECT_NAME" --format "{{.State.Status}}" 2>/dev/null || echo "unknown")
  
  if [[ "$container_status" != "running" ]]; then
    log_error "Container $TEST_PROJECT_NAME is not in running state: $container_status"
    return 1
  fi
  
  log "Container deployment validation passed"
  return 0
}

# Test 7: Validate proxy integration
function test_proxy_integration() {
  log "Validating proxy integration..."
  
  # Determine container engine
  local container_engine=""
  if command -v podman &> /dev/null; then
    container_engine="podman"
  elif command -v docker &> /dev/null; then
    container_engine="docker"
  else
    log_error "No container engine available"
    return 1
  fi
  
  # Check if nginx-proxy container exists and is running
  if ! $container_engine ps --format "{{.Names}}" | grep -q "^nginx-proxy$"; then
    log_error "nginx-proxy container is not running"
    log_error "Currently running containers:"
    $container_engine ps --format "table {{.Names}}\t{{.Status}}"
    return 1
  fi
  
  # Check if proxy configuration includes our domain
  local proxy_config_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  if [[ ! -f "$proxy_config_dir/${TEST_DOMAIN}.conf" ]]; then
    log_error "Proxy configuration not found for domain $TEST_DOMAIN"
    return 1
  fi
  
  # Validate proxy configuration content
  if ! grep -q "$TEST_DOMAIN" "$proxy_config_dir/${TEST_DOMAIN}.conf"; then
    log_error "Domain $TEST_DOMAIN not found in proxy configuration"
    return 1
  fi
  
  if ! grep -q "$TEST_PROJECT_NAME" "$proxy_config_dir/${TEST_DOMAIN}.conf"; then
    log_error "Container name $TEST_PROJECT_NAME not found in proxy configuration"
    return 1
  fi
  
  log "Proxy integration validation passed"
  return 0
}

# Test 8: Test HTTP connectivity (basic)
function test_http_connectivity() {
  log "Testing HTTP connectivity..."
  
  # Give containers time to fully start
  sleep 10
  
  # Test if we can reach the nginx-proxy on port 8080
  local max_attempts=30
  local attempt=1
  
  while [[ $attempt -le $max_attempts ]]; do
    if curl -f -s -k "http://localhost:8080" -H "Host: $TEST_DOMAIN" > /dev/null 2>&1; then
      log "HTTP connectivity test passed (attempt $attempt)"
      return 0
    fi
    
    log_warn "HTTP connectivity test failed, attempt $attempt/$max_attempts"
    sleep 2
    attempt=$((attempt + 1))
  done
  
  log_error "HTTP connectivity test failed after $max_attempts attempts"
  return 1
}

# Main test runner
function main() {
  log "Starting monorepo deployment integration tests..."
  log "Project root: $PROJECT_ROOT"
  log "Test monorepo: $TEST_MONOREPO_DIR"
  log "Test project name: $TEST_PROJECT_NAME"
  log "Test domain: $TEST_DOMAIN"
  
  # Trap to ensure cleanup on exit
  trap cleanup_test_deployment EXIT
  
  # Run tests
  run_test "Test monorepo structure validation" test_monorepo_structure
  run_test "Nix environment validation" test_nix_environment
  run_test "Frontend build test" test_frontend_build
  run_test "Monorepo deployment" test_monorepo_deployment
  run_test "Deployment artifacts validation" test_deployment_artifacts
  run_test "Container deployment validation" test_container_deployment
  run_test "Proxy integration validation" test_proxy_integration
  run_test "HTTP connectivity test" test_http_connectivity
  
  # Results
  log "Test Results:"
  log "  Total tests: $TESTS_TOTAL"
  log "  Passed: $TESTS_PASSED"
  log "  Failed: $TESTS_FAILED"
  
  if [[ $TESTS_FAILED -eq 0 ]]; then
    log "🎉 All monorepo integration tests passed!"
    return 0
  else
    log_error "❌ Some monorepo integration tests failed!"
    return 1
  fi
}

# Run main function
main "$@"
