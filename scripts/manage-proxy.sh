#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/manage-proxy.log"
PROXY_DIR="${PROJECT_ROOT}/proxy"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Manage the Nginx proxy container with proper permissions."
  echo ""
  echo "Options:"
  echo "  --action, -a ACTION       Action to perform: start, stop, restart, status (required)"
  echo "  --port, -p PORT           Host port for HTTP (default: 80)"
  echo "  --ssl-port, -s PORT       Host port for HTTPS (default: 443)"
  echo "  --non-root                Run without root privileges (uses ports > 1024)"
  echo "  --help, -h                Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --action start"
  echo "  $0 -a stop"
  echo "  $0 -a restart --non-root"
  echo "  $0 -a status"
}

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function: Handle errors
function handle_error() {
  log "ERROR: $1"
  exit 1
}

# Function: Validate environment
function validate_environment() {
  # Check if we're in Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    handle_error "Please enter Nix environment with 'nix --extra-experimental-features \"nix-command flakes\" develop' first"
  fi
  
  # Check if Docker/Podman is installed
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    handle_error "Neither Docker nor Podman is installed. Please install one of them and try again."
  fi
  
  # Determine which container engine to use
  if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
  else
    CONTAINER_ENGINE="docker"
  fi
  log "Using container engine: $CONTAINER_ENGINE"
  
  # Check if the proxy directory exists
  if [ ! -d "${PROXY_DIR}" ]; then
    handle_error "Proxy directory not found: ${PROXY_DIR}"
  fi
}

# Function: Parse arguments
function parse_arguments() {
  ACTION=""
  HTTP_PORT="80"
  HTTPS_PORT="443"
  NON_ROOT=false

  while [[ $# -gt 0 ]]; do
    case $1 in
      --action|-a)
        ACTION="$2"
        shift 2
        ;;
      --port|-p)
        HTTP_PORT="$2"
        shift 2
        ;;
      --ssl-port|-s)
        HTTPS_PORT="$2"
        shift 2
        ;;
      --non-root)
        NON_ROOT=true
        shift
        ;;
      --help|-h)
        display_help
        exit 0
        ;;
      *)
        handle_error "Unknown parameter: $1"
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$ACTION" ]]; then
    handle_error "Action is required. Use --action or -a to specify."
  fi

  # Validate action
  if [[ "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "restart" && "$ACTION" != "status" ]]; then
    handle_error "Action must be one of: start, stop, restart, status."
  fi
  
  # If non-root is specified, use non-privileged ports
  if [[ "$NON_ROOT" = true ]]; then
    HTTP_PORT="8080"
    HTTPS_PORT="8443"
    log "Using non-privileged ports: HTTP=${HTTP_PORT}, HTTPS=${HTTPS_PORT}"
  else
         # Check if we have permission to bind to privileged ports
     if [[ "$HTTP_PORT" -lt 1024 || "$HTTPS_PORT" -lt 1024 ]]; then
       # Check if running as root
       if [[ $(id -u) -ne 0 ]]; then
         log "Warning: Using privileged ports (${HTTP_PORT}, ${HTTPS_PORT}) requires root privileges."
         log "Consider using --non-root option or running with sudo."
       fi
     fi
   fi
}

# Function: Update docker-compose.yml with ports
function update_docker_compose() {
  local temp_file=$(mktemp)
  local docker_compose_file="${PROXY_DIR}/docker-compose.yml"
  
  # Create a backup
  cp "$docker_compose_file" "${docker_compose_file}.bak"
  
  # Update ports in docker-compose.yml
  sed -E "s/- \"[0-9]+:80\"/- \"${HTTP_PORT}:80\"/g" "$docker_compose_file" | \
  sed -E "s/- \"[0-9]+:443\"/- \"${HTTPS_PORT}:443\"/g" > "$temp_file"
  
  mv "$temp_file" "$docker_compose_file"
  log "Updated ports in docker-compose.yml: HTTP=${HTTP_PORT}, HTTPS=${HTTPS_PORT}"
}

# Function: Start proxy
function start_proxy() {
  log "Starting Nginx proxy container"
  
  # Update docker-compose.yml with ports
  update_docker_compose
  
  # Start containers
  cd "$PROXY_DIR" || handle_error "Failed to change directory to $PROXY_DIR"
  
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    podman-compose up -d || handle_error "Failed to start proxy container"
  else
    docker-compose up -d || handle_error "Failed to start proxy container"
  fi
  
  log "Nginx proxy container started"
  if [[ "$NON_ROOT" = true ]]; then
    log "Access the proxy at: http://localhost:${HTTP_PORT} or https://localhost:${HTTPS_PORT}"
  else
    log "Access the proxy at: http://localhost or https://localhost"
  fi
}

# Function: Stop proxy
function stop_proxy() {
  log "Stopping Nginx proxy container"
  
  cd "$PROXY_DIR" || handle_error "Failed to change directory to $PROXY_DIR"
  
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    podman-compose down || handle_error "Failed to stop proxy container"
  else
    docker-compose down || handle_error "Failed to stop proxy container"
  fi
  
  log "Nginx proxy container stopped"
}

# Function: Restart proxy
function restart_proxy() {
  stop_proxy
  start_proxy
}

# Function: Check proxy status
function check_status() {
  log "Checking Nginx proxy container status"
  
  cd "$PROXY_DIR" || handle_error "Failed to change directory to $PROXY_DIR"
  
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    podman-compose ps || handle_error "Failed to check proxy container status"
  else
    docker-compose ps || handle_error "Failed to check proxy container status"
  fi
}

# Main execution
parse_arguments "$@"
validate_environment

case "$ACTION" in
  start)
    start_proxy
    ;;
  stop)
    stop_proxy
    ;;
  restart)
    restart_proxy
    ;;
  status)
    check_status
    ;;
esac

exit 0 