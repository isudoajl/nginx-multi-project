#!/bin/bash

# Script to safely restart a project while maintaining proxy connectivity
# This script handles the reconnection to the proxy network and updates the proxy configuration

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/scripts/logs/restart-project.log"
PROXY_DOMAINS_DIR="${PROJECT_ROOT}/proxy/conf.d/domains"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Function: Log messages
function log() {
  local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  echo "[${timestamp}] $1" | tee -a "$LOG_FILE"
}

# Function: Handle errors
function handle_error() {
  log "ERROR: $1"
  exit 1
}

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Safely restart a project while maintaining proxy connectivity."
  echo ""
  echo "Options:"
  echo "  -n, --name NAME        Name of the project to restart"
  echo "  -h, --help             Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --name my-project"
}

# Function: Parse arguments
function parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -n|--name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      -h|--help)
        display_help
        exit 0
        ;;
      *)
        echo "Unknown parameter: $1"
        display_help
        exit 1
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: Project name is required"
    display_help
    exit 1
  fi
}

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo "Error: Please enter Nix environment with 'nix --extra-experimental-features \"nix-command flakes\" develop' first"
    exit 1
  fi

  # Determine container engine (podman or docker)
  if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
    if command -v podman-compose &> /dev/null; then
      COMPOSE_CMD="podman-compose"
    else
      handle_error "podman-compose not found. Please install it."
    fi
  elif command -v docker &> /dev/null; then
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker-compose"
  else
    handle_error "Neither podman nor docker found. Please install one of them."
  fi
}

# Function: Find domain name from project name
function find_domain_name() {
  local domain_file=""
  
  # Look for domain configuration files that reference this project
  domain_file=$(grep -l "container_name: ${PROJECT_NAME}" ${PROJECT_ROOT}/projects/${PROJECT_NAME}/docker-compose.yml)
  
  if [[ -z "$domain_file" ]]; then
    handle_error "Could not find project directory for ${PROJECT_NAME}"
  fi
  
  # Extract domain name from docker-compose.yml
  DOMAIN_NAME=$(grep "DOMAIN_NAME=" ${PROJECT_ROOT}/projects/${PROJECT_NAME}/docker-compose.yml | sed 's/.*DOMAIN_NAME=//' | tr -d '[:space:]')
  
  if [[ -z "$DOMAIN_NAME" ]]; then
    handle_error "Could not determine domain name for project ${PROJECT_NAME}"
  fi
  
  log "Found domain name: ${DOMAIN_NAME} for project ${PROJECT_NAME}"
}

# Function: Restart project
function restart_project() {
  log "Restarting project ${PROJECT_NAME}..."
  
  # Check if project directory exists
  local project_dir="${PROJECT_ROOT}/projects/${PROJECT_NAME}"
  if [[ ! -d "$project_dir" ]]; then
    handle_error "Project directory not found: ${project_dir}"
  fi
  
  # Stop and remove the container
  log "Stopping project container..."
  cd "$project_dir" || handle_error "Failed to change to project directory"
  $COMPOSE_CMD down || log "Warning: Failed to stop project container, continuing anyway..."
  
  # Start the container
  log "Starting project container..."
  $COMPOSE_CMD up -d || handle_error "Failed to start project container"
  
  # Wait for container to start
  log "Waiting for container to start..."
  sleep 5
  
  # Check if container is running
  if ! $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${PROJECT_NAME}$"; then
    handle_error "Project container failed to start"
  fi
  
  # Connect to proxy network
  log "Connecting project container to proxy network..."
  $CONTAINER_ENGINE network connect nginx-proxy-network "${PROJECT_NAME}" || handle_error "Failed to connect to proxy network"
  
  # Verify network connectivity
  log "Verifying network connectivity..."
  local connectivity_verified=false
  local max_connectivity_attempts=5
  local connectivity_attempt=0
  
  while [[ "$connectivity_verified" == "false" && $connectivity_attempt -lt $max_connectivity_attempts ]]; do
    if $CONTAINER_ENGINE exec nginx-proxy curl -s --max-time 5 -f "http://${PROJECT_NAME}:80/health" > /dev/null 2>&1; then
      connectivity_verified=true
      log "Network connectivity verified successfully"
    else
      log "Connectivity attempt $((connectivity_attempt + 1)): Waiting for container to be reachable..."
      sleep 3
      ((connectivity_attempt++))
    fi
  done
  
  if [[ "$connectivity_verified" == "false" ]]; then
    # Try alternative verification method - just check if container is reachable
    if $CONTAINER_ENGINE exec nginx-proxy ping -c 1 "${PROJECT_NAME}" > /dev/null 2>&1; then
      log "Network connectivity verified via ping (HTTP service may not be ready yet)"
      connectivity_verified=true
    else
      handle_error "Failed to verify network connectivity between proxy and project container"
    fi
  fi
  
  # Test and reload proxy configuration
  log "Testing proxy configuration..."
  if ! $CONTAINER_ENGINE exec nginx-proxy nginx -t; then
    handle_error "Proxy configuration test failed"
  fi
  
  log "Reloading proxy configuration..."
  if ! $CONTAINER_ENGINE exec nginx-proxy nginx -s reload; then
    handle_error "Failed to reload proxy configuration"
  fi
  
  log "Project ${PROJECT_NAME} restarted successfully!"
  log "Domain ${DOMAIN_NAME} is now configured to use container name ${PROJECT_NAME}"
}

# Main execution
parse_arguments "$@"
check_environment
find_domain_name
restart_project

exit 0 