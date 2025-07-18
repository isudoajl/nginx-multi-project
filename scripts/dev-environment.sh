#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/dev-environment.log"
PROJECTS_DIR="${PROJECT_ROOT}/projects"
CONF_DIR="${PROJECT_ROOT}/conf"
DOCKER_COMPOSE_OVERRIDE="docker-compose.override.yml"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Manage development environment for projects."
  echo ""
  echo "Options:"
  echo "  --project, -p PROJECT     Project name to manage (required)"
  echo "  --action, -a ACTION       Action to perform: setup, start, stop, reload (required)"
  echo "  --port, -port PORT        Development port to use (default: 8080)"
  echo "  --subnet, -s ID           Subnet ID for development network (default: random 1-254)"
  echo "  --help, -h                Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --project my-project --action setup"
  echo "  $0 -p my-project -a start"
  echo "  $0 -p my-project -a stop"
  echo "  $0 -p my-project -a reload"
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
    handle_error "Please enter Nix environment with 'nix develop' first"
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
  
  # Check if the project exists
  if [ ! -d "${PROJECTS_DIR}/${PROJECT_NAME}" ]; then
    handle_error "Project directory not found: ${PROJECTS_DIR}/${PROJECT_NAME}"
  fi
}

# Function: Parse arguments
function parse_arguments() {
  PROJECT_NAME=""
  ACTION=""
  DEV_PORT="8080"
  SUBNET_ID=$((RANDOM % 254 + 1))

  while [[ $# -gt 0 ]]; do
    case $1 in
      --project|-p)
        PROJECT_NAME="$2"
        shift 2
        ;;
      --action|-a)
        ACTION="$2"
        shift 2
        ;;
      --port|-port)
        DEV_PORT="$2"
        shift 2
        ;;
      --subnet|-s)
        SUBNET_ID="$2"
        shift 2
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
  if [[ -z "$PROJECT_NAME" ]]; then
    handle_error "Project name is required. Use --project or -p to specify."
  fi

  if [[ -z "$ACTION" ]]; then
    handle_error "Action is required. Use --action or -a to specify."
  fi

  # Validate action
  if [[ "$ACTION" != "setup" && "$ACTION" != "start" && "$ACTION" != "stop" && "$ACTION" != "reload" ]]; then
    handle_error "Action must be one of: setup, start, stop, reload."
  fi
  
  # Validate port number
  if ! [[ "$DEV_PORT" =~ ^[0-9]+$ ]] || [ "$DEV_PORT" -gt 65535 ]; then
    handle_error "Invalid port number: $DEV_PORT. Must be between 1 and 65535."
  fi
  
  # Validate subnet ID
  if ! [[ "$SUBNET_ID" =~ ^[0-9]+$ ]] || [ "$SUBNET_ID" -lt 1 ] || [ "$SUBNET_ID" -gt 254 ]; then
    handle_error "Invalid subnet ID: $SUBNET_ID. Must be between 1 and 254."
  fi
}

# Function: Setup development environment
function setup_dev_environment() {
  log "Setting up development environment for project: $PROJECT_NAME"
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  local override_template="${CONF_DIR}/docker-compose.override.dev.yml"
  local override_file="${project_dir}/${DOCKER_COMPOSE_OVERRIDE}"
  
  # Create development configuration directory
  mkdir -p "${project_dir}/conf.d/dev"
  
  # Create health check endpoint
  mkdir -p "${project_dir}/html/health"
  cat > "${project_dir}/html/health/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Health Check</title>
</head>
<body>
  <h1>Service is healthy</h1>
  <p>Environment: Development</p>
  <p>Project: ${PROJECT_NAME}</p>
  <p>Time: <span id="current-time"></span></p>
  
  <script>
    document.getElementById('current-time').textContent = new Date().toISOString();
  </script>
</body>
</html>
EOF

  # Create development configuration
  cat > "${project_dir}/conf.d/dev/development.conf" << EOF
# Development-specific configuration
server_tokens on;
error_log /var/log/nginx/error.log debug;
access_log /var/log/nginx/access.log;

# Development headers
add_header X-Development-Environment "true" always;
add_header X-Project "${PROJECT_NAME}" always;

# Disable cache for development
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
expires -1;

# Enable CORS for development
add_header 'Access-Control-Allow-Origin' '*' always;
add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE' always;
add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range' always;
EOF

  # Create Docker Compose override file
  if [ -f "$override_template" ]; then
    cat "$override_template" | \
      sed "s/{project-name}/${PROJECT_NAME}/g" | \
      sed "s/{dev-port}/${DEV_PORT}/g" | \
      sed "s/{subnet-id}/${SUBNET_ID}/g" \
      > "$override_file"
    
    log "Created Docker Compose override file: $override_file"
  else
    handle_error "Override template not found: $override_template"
  fi
  
  log "Development environment setup completed for project: $PROJECT_NAME"
}

# Function: Start development environment
function start_dev_environment() {
  log "Starting development environment for project: $PROJECT_NAME"
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Check if override file exists
  if [ ! -f "${project_dir}/${DOCKER_COMPOSE_OVERRIDE}" ]; then
    log "Docker Compose override file not found. Setting up development environment first."
    setup_dev_environment
  fi
  
  # Start containers with override
  cd "$project_dir" || handle_error "Failed to change directory to $project_dir"
  
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    podman-compose up -d || handle_error "Failed to start development environment"
  else
    docker-compose -f docker-compose.yml -f ${DOCKER_COMPOSE_OVERRIDE} up -d || handle_error "Failed to start development environment"
  fi
  
  log "Development environment started for project: $PROJECT_NAME"
  log "Access the project at: http://localhost:${DEV_PORT}"
}

# Function: Stop development environment
function stop_dev_environment() {
  log "Stopping development environment for project: $PROJECT_NAME"
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Check if override file exists
  if [ ! -f "${project_dir}/${DOCKER_COMPOSE_OVERRIDE}" ]; then
    handle_error "Docker Compose override file not found. Set up development environment first."
  fi
  
  # Stop containers
  cd "$project_dir" || handle_error "Failed to change directory to $project_dir"
  
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    podman-compose down || handle_error "Failed to stop development environment"
  else
    docker-compose -f docker-compose.yml -f ${DOCKER_COMPOSE_OVERRIDE} down || handle_error "Failed to stop development environment"
  fi
  
  log "Development environment stopped for project: $PROJECT_NAME"
}

# Function: Reload development environment
function reload_dev_environment() {
  log "Reloading development environment for project: $PROJECT_NAME"
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Check if containers are running
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    if ! podman ps | grep -q "${PROJECT_NAME}"; then
      handle_error "Project containers are not running. Start them first."
    fi
    
    # Reload Nginx configuration
    podman exec -it "${PROJECT_NAME}" nginx -s reload || handle_error "Failed to reload Nginx configuration"
  else
    if ! docker ps | grep -q "${PROJECT_NAME}"; then
      handle_error "Project containers are not running. Start them first."
    fi
    
    # Reload Nginx configuration
    docker exec -it "${PROJECT_NAME}" nginx -s reload || handle_error "Failed to reload Nginx configuration"
  fi
  
  log "Development environment reloaded for project: $PROJECT_NAME"
}

# Main script execution
parse_arguments "$@"
validate_environment

case "$ACTION" in
  setup)
    setup_dev_environment
    ;;
  start)
    start_dev_environment
    ;;
  stop)
    stop_dev_environment
    ;;
  reload)
    reload_dev_environment
    ;;
esac

log "Action '$ACTION' completed successfully for project: $PROJECT_NAME"
exit 0 