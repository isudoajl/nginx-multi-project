#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/../proxy"
PROXY_DOMAINS_DIR="${PROXY_DIR}/conf.d/domains"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Update the central proxy configuration when a new project is added or an existing project is modified."
  echo ""
  echo "Options:"
  echo "  -a, --action ACTION    Action to perform (add, remove, or update)"
  echo "  -n, --name NAME        Name of the project to add, remove, or update"
  echo "  -d, --domain DOMAIN    Domain name for the project (required for add and update)"
  echo "  -p, --port PORT        Internal port for the project container (required for add and update)"
  echo "  -h, --help             Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --action add --name my-project --domain example.com --port 8080"
  echo "  $0 --action remove --name my-project"
  echo "  $0 --action update --name my-project --domain example.com --port 8080"
}

# Function: Parse arguments
function parse_arguments() {
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -a|--action)
        ACTION="$2"
        shift 2
        ;;
      -n|--name)
        PROJECT_NAME="$2"
        shift 2
        ;;
      -d|--domain)
        DOMAIN_NAME="$2"
        shift 2
        ;;
      -p|--port)
        PORT="$2"
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
  if [[ -z "$ACTION" ]]; then
    echo "Error: Action is required"
    display_help
    exit 1
  fi

  if [[ -z "$PROJECT_NAME" ]]; then
    echo "Error: Project name is required"
    display_help
    exit 1
  fi

  # Validate action-specific parameters
  if [[ "$ACTION" == "add" || "$ACTION" == "update" ]]; then
    if [[ -z "$DOMAIN_NAME" ]]; then
      echo "Error: Domain name is required for add and update actions"
      display_help
      exit 1
    fi
    if [[ -z "$PORT" ]]; then
      echo "Error: Port is required for add and update actions"
      display_help
      exit 1
    fi
  fi
}

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo "Error: Please enter Nix environment with 'nix develop' first"
    exit 1
  fi
}

# Function: Add project to proxy
function add_project() {
  echo "Adding project $PROJECT_NAME to proxy..."
  
  # Create domain configuration file
  cat > "${PROXY_DOMAINS_DIR}/${DOMAIN_NAME}.conf" << EOF
# Domain configuration for ${DOMAIN_NAME}
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/${DOMAIN_NAME}/cert.pem;
    ssl_certificate_key /etc/nginx/certs/${DOMAIN_NAME}/cert-key.pem;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Return 444 for bad bots and unusual methods
    if (\$bad_bot = 1) {
        return 444;
    }

    if (\$method_allowed = 0) {
        return 444;
    }
    
    # Apply rate limiting
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    # Proxy to project container
    location / {
        proxy_pass http://${PROJECT_NAME}:${PORT};
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Custom error handling
    error_page 502 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }
}

# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    return 301 https://\$server_name\$request_uri;
}
EOF

  # Add network to docker-compose.yml
  # Using sed to add the network before the closing networks section
  sed -i "/networks:/a \ \ ${PROJECT_NAME}-network:\n    external: true" "${PROXY_DIR}/docker-compose.yml"
  # Add network to the service
  sed -i "/proxy-network/a \ \ \ \ \ \ - ${PROJECT_NAME}-network" "${PROXY_DIR}/docker-compose.yml"
  
  echo "Project $PROJECT_NAME added to proxy configuration."
}

# Function: Remove project from proxy
function remove_project() {
  echo "Removing project $PROJECT_NAME from proxy..."
  
  # Find the domain configuration file
  DOMAIN_FILE=$(grep -l "proxy_pass.*${PROJECT_NAME}:" ${PROXY_DOMAINS_DIR}/*.conf)
  
  if [[ -z "$DOMAIN_FILE" ]]; then
    echo "Error: No domain configuration found for project $PROJECT_NAME"
    exit 1
  fi
  
  # Extract domain name from file path
  DOMAIN_NAME=$(basename "$DOMAIN_FILE" .conf)
  
  # Remove domain configuration file
  rm -f "$DOMAIN_FILE"
  
  # Remove network from docker-compose.yml
  sed -i "/\ \ ${PROJECT_NAME}-network:/d" "${PROXY_DIR}/docker-compose.yml"
  sed -i "/\ \ \ \ \ \ - ${PROJECT_NAME}-network/d" "${PROXY_DIR}/docker-compose.yml"
  sed -i "/\ \ \ \ external: true/d" "${PROXY_DIR}/docker-compose.yml"
  
  echo "Project $PROJECT_NAME removed from proxy configuration."
}

# Function: Update project in proxy
function update_project() {
  echo "Updating project $PROJECT_NAME in proxy..."
  
  # Find the domain configuration file
  DOMAIN_FILE=$(grep -l "proxy_pass.*${PROJECT_NAME}:" ${PROXY_DOMAINS_DIR}/*.conf)
  
  if [[ -z "$DOMAIN_FILE" ]]; then
    echo "Error: No domain configuration found for project $PROJECT_NAME"
    exit 1
  fi
  
  # Extract old domain name from file path
  OLD_DOMAIN_NAME=$(basename "$DOMAIN_FILE" .conf)
  
  # If domain name has changed, remove old file and create new one
  if [[ "$OLD_DOMAIN_NAME" != "$DOMAIN_NAME" ]]; then
    rm -f "$DOMAIN_FILE"
    add_project
  else
    # Update existing file with new port
    sed -i "s/proxy_pass http:\/\/${PROJECT_NAME}:[0-9]*/proxy_pass http:\/\/${PROJECT_NAME}:${PORT}/" "$DOMAIN_FILE"
    echo "Project $PROJECT_NAME updated in proxy configuration."
  fi
}

# Function: Reload proxy configuration
function reload_proxy() {
  echo "Reloading proxy configuration..."
  
  # Determine container engine (prefer podman, fallback to docker)
  if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
    COMPOSE_CMD="podman-compose"
  else
    CONTAINER_ENGINE="docker"
    COMPOSE_CMD="docker-compose"
  fi
  
  # Check if proxy container is running
  if $CONTAINER_ENGINE ps | grep -q "nginx-proxy"; then
    $CONTAINER_ENGINE exec nginx-proxy nginx -s reload
    echo "Proxy configuration reloaded."
  else
    echo "Proxy container is not running. Starting..."
    cd "${PROXY_DIR}" && $COMPOSE_CMD up -d
    echo "Proxy container started."
  fi
}

# Main script execution
check_environment
parse_arguments "$@"

case "$ACTION" in
  add)
    add_project
    ;;
  remove)
    remove_project
    ;;
  update)
    update_project
    ;;
  *)
    echo "Invalid action: $ACTION"
    display_help
    exit 1
    ;;
esac

reload_proxy
echo "Proxy configuration updated for project $PROJECT_NAME!" 