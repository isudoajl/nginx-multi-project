#!/bin/bash
# Common test helper functions for nginx-multi-project tests

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Log function
function log() {
    local message="$1"
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] ${message}${NC}"
}

# Success log function
function log_success() {
    local message="$1"
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')] ✓ ${message}${NC}"
}

# Error log function
function log_error() {
    local message="$1"
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ✗ ${message}${NC}"
}

# Check if we're in Nix environment
function check_nix_environment() {
    if [ -z "$IN_NIX_SHELL" ]; then
        log_error "Not in Nix environment. Please run 'nix develop' first."
        exit 1
    else
        log_success "Running in Nix environment"
    fi
}

# Check if a command exists
function command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if a container exists
function container_exists() {
    local container_name="$1"
    podman ps -a --format "{{.Names}}" | grep -q "^${container_name}$"
}

# Check if a container is running
function container_is_running() {
    local container_name="$1"
    podman ps --format "{{.Names}}" | grep -q "^${container_name}$"
}

# Stop and remove a container if it exists
function remove_container_if_exists() {
    local container_name="$1"
    
    if container_exists "$container_name"; then
        log "Stopping container: $container_name"
        podman stop "$container_name" >/dev/null 2>&1
        
        log "Removing container: $container_name"
        podman rm "$container_name" >/dev/null 2>&1
    fi
}

# Create a temporary directory
function create_temp_dir() {
    local prefix="$1"
    local temp_dir
    
    temp_dir=$(mktemp -d "/tmp/${prefix}-XXXXXX")
    echo "$temp_dir"
}

# Remove a directory if it exists
function remove_dir_if_exists() {
    local dir="$1"
    
    if [ -d "$dir" ]; then
        log "Removing directory: $dir"
        rm -rf "$dir"
    fi
}

# Wait for a condition with timeout
function wait_for() {
    local timeout="$1"
    local condition_function="$2"
    local description="$3"
    shift 3
    
    local start_time
    start_time=$(date +%s)
    local end_time=$((start_time + timeout))
    
    log "Waiting for $description (timeout: ${timeout}s)..."
    
    while [ "$(date +%s)" -lt "$end_time" ]; do
        if "$condition_function" "$@"; then
            log_success "$description is ready"
            return 0
        fi
        sleep 1
    done
    
    log_error "Timed out waiting for $description"
    return 1
}

# Check if a URL is accessible
function url_is_accessible() {
    local url="$1"
    curl -s -o /dev/null -w "%{http_code}" "$url" | grep -q "^[23]"
}

# Check if a port is open
function port_is_open() {
    local host="$1"
    local port="$2"
    
    nc -z "$host" "$port" >/dev/null 2>&1
}

# Run a test and report result
function run_test_case() {
    local test_name="$1"
    local test_command="$2"
    local expected_exit_code="${3:-0}"
    
    log "Running test: $test_name"
    
    eval "$test_command"
    local actual_exit_code=$?
    
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        log_success "Test passed: $test_name"
        return 0
    else
        log_error "Test failed: $test_name (Exit code: $actual_exit_code, Expected: $expected_exit_code)"
        return 1
    fi
}

# Create a mock file with content
function create_mock_file() {
    local file_path="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$file_path")"
    echo "$content" > "$file_path"
}

# Create a mock directory structure
function create_mock_directory_structure() {
    local base_dir="$1"
    shift
    
    for dir in "$@"; do
        mkdir -p "${base_dir}/${dir}"
    done
}

# Export all functions
export -f log
export -f log_success
export -f log_error
export -f check_nix_environment
export -f command_exists
export -f container_exists
export -f container_is_running
export -f remove_container_if_exists
export -f create_temp_dir
export -f remove_dir_if_exists
export -f wait_for
export -f url_is_accessible
export -f port_is_open
export -f run_test_case
export -f create_mock_file
export -f create_mock_directory_structure 