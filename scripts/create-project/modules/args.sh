#!/bin/bash

# Module for argument parsing and validation

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Create a new project container with all necessary configuration files."
  echo ""
  echo "Options:"
  echo "  --name, -n NAME          Project name (required, alphanumeric with hyphens)"
  echo "  --port, -p PORT          Internal container port (required, 1024-65535)"
  echo "  --domain, -d DOMAIN      Domain name (required, valid FQDN format)"
  echo "  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)"
  echo "  --frontend-mount, -m DIR Path to mount as frontend in container (optional, default: ./html)"
  echo "  --cert, -c FILE          Path to SSL certificate (optional)"
  echo "  --key, -k FILE           Path to SSL private key (optional)"
  echo "  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)"
  echo "  --help, -h               Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --name my-project --port 8080 --domain example.com"
  echo "  $0 -n my-project -p 8080 -d example.com -e DEV"
  echo "  $0 -n my-project -p 8080 -d example.com -e PRO"
  echo "  $0 -n my-project -p 8080 -d example.com -m /path/to/frontend"
}

# Function: Parse arguments
function parse_arguments() {
  PROJECT_NAME=""
  PROJECT_PORT=""
  DOMAIN_NAME=""
  FRONTEND_DIR=""
  FRONTEND_MOUNT=""
  CERT_PATH=""
  KEY_PATH=""
  ENV_TYPE="DEV"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name|-n)
        PROJECT_NAME="$2"
        shift 2
        ;;
      --port|-p)
        PROJECT_PORT="$2"
        shift 2
        ;;
      --domain|-d)
        DOMAIN_NAME="$2"
        shift 2
        ;;
      --frontend|-f)
        FRONTEND_DIR="$2"
        shift 2
        ;;
      --frontend-mount|-m)
        FRONTEND_MOUNT="$2"
        shift 2
        ;;
      --cert|-c)
        CERT_PATH="$2"
        shift 2
        ;;
      --key|-k)
        KEY_PATH="$2"
        shift 2
        ;;
      --env|-e)
        ENV_TYPE="$2"
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
    handle_error "Project name is required. Use --name or -n to specify."
  fi

  if [[ -z "$PROJECT_PORT" ]]; then
    handle_error "Port is required. Use --port or -p to specify."
  fi

  if [[ -z "$DOMAIN_NAME" ]]; then
    handle_error "Domain name is required. Use --domain or -d to specify."
  fi

  # Validate project name format
  if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    handle_error "Invalid project name format: $PROJECT_NAME. Use only alphanumeric characters and hyphens."
  fi

  # Validate port number
  if ! [[ "$PROJECT_PORT" =~ ^[0-9]+$ ]] || [ "$PROJECT_PORT" -lt 1024 ] || [ "$PROJECT_PORT" -gt 65535 ]; then
    handle_error "Invalid port number: $PROJECT_PORT. Must be between 1024 and 65535."
  fi

  # Validate domain format
  if ! [[ "$DOMAIN_NAME" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    handle_error "Invalid domain format: $DOMAIN_NAME"
  fi

  # Validate environment type
  if [[ "$ENV_TYPE" != "DEV" && "$ENV_TYPE" != "PRO" ]]; then
    handle_error "Environment type must be either DEV or PRO."
  fi

  # Set default frontend directory if not specified
  if [[ -z "$FRONTEND_DIR" ]]; then
    FRONTEND_DIR="${PROJECTS_DIR}/${PROJECT_NAME}/html"
  fi

  # Set default frontend mount if not specified
  if [[ -z "$FRONTEND_MOUNT" ]]; then
    FRONTEND_MOUNT="./html"
  fi

  # Set default certificate paths if not specified
  if [[ -z "$CERT_PATH" ]]; then
    CERT_PATH="/etc/ssl/certs/cert.pem"
  fi

  if [[ -z "$KEY_PATH" ]]; then
    KEY_PATH="/etc/ssl/certs/private/cert-key.pem"
  fi
  
  log "Arguments parsed successfully: PROJECT_NAME=$PROJECT_NAME, DOMAIN_NAME=$DOMAIN_NAME, ENV_TYPE=$ENV_TYPE"
  log "Frontend mount point: $FRONTEND_MOUNT"
} 