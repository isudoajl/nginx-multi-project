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
  echo "  --env-vars VARS          Environment variables as comma-separated list: VAR1=value1,VAR2=value2"
  echo "  --help, -h               Display this help message"
  echo ""
  echo "Nix-based Build Options:"
  echo "  --use-nix-build          Enable Nix-based containerized builds"
  echo "  --mono-repo DIR          Source monorepo location on host"
  echo "  --frontend-path DIR      Relative path to frontend within monorepo"
  echo "  --frontend-build-dir DIR Frontend build output directory"
  echo "  --frontend-build-cmd CMD Command to build frontend"
  echo "  --backend-path DIR       Relative path to backend within monorepo"
  echo "  --backend-build-cmd CMD  Command to build backend"
  echo "  --backend-start-cmd CMD  Command to start backend (defaults to backend-build-cmd if not specified)"
  echo ""
  echo "Examples:"
  echo "  $0 --name my-project --port 8080 --domain example.com"
  echo "  $0 -n my-project -p 8080 -d example.com -e DEV"
  echo "  $0 -n my-project -p 8080 -d example.com -e PRO"
  echo "  $0 -n my-project -p 8080 -d example.com -m /path/to/frontend"
  echo ""
  echo "Nix-based Build Example:"
  echo "  $0 --name my-project --port 8080 --domain example.com --use-nix-build \\"
  echo "     --mono-repo /path/to/repo --frontend-path packages/frontend \\"
  echo "     --frontend-build-dir dist --frontend-build-cmd \"npm run build\" \\"
  echo "     --backend-path packages/backend --backend-build-cmd \"npm run build\" \\"
  echo "     --backend-start-cmd \"npm start\" \\"
  echo "     --env-vars \"NODE_ENV=production,API_URL=https://api.example.com\""
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
  PROJECT_ENV_VARS=""
  
  # New Nix-based build parameters
  USE_NIX_BUILD=false
  MONO_REPO_PATH=""
  FRONTEND_PATH=""
  FRONTEND_BUILD_DIR=""
  FRONTEND_BUILD_CMD=""
  BACKEND_PATH=""
  BACKEND_BUILD_CMD=""
  BACKEND_START_CMD=""

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
      --env-vars)
        PROJECT_ENV_VARS="$2"
        shift 2
        ;;
      --use-nix-build)
        USE_NIX_BUILD=true
        shift
        ;;
      --mono-repo)
        MONO_REPO_PATH="$2"
        shift 2
        ;;
      --frontend-path)
        FRONTEND_PATH="$2"
        shift 2
        ;;
      --frontend-build-dir)
        FRONTEND_BUILD_DIR="$2"
        shift 2
        ;;
      --frontend-build-cmd)
        FRONTEND_BUILD_CMD="$2"
        shift 2
        ;;
      --backend-path)
        BACKEND_PATH="$2"
        shift 2
        ;;
      --backend-build-cmd)
        BACKEND_BUILD_CMD="$2"
        shift 2
        ;;
      --backend-start-cmd)
        BACKEND_START_CMD="$2"
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
  
  # Validate environment variables format if specified
  if [[ -n "$PROJECT_ENV_VARS" ]]; then
    # Check if format is correct (VAR1=value1,VAR2=value2)
    if ! [[ "$PROJECT_ENV_VARS" =~ ^([A-Za-z0-9_]+=.+)(,[A-Za-z0-9_]+=.+)*$ ]]; then
      handle_error "Invalid environment variables format: $PROJECT_ENV_VARS. Use format: VAR1=value1,VAR2=value2"
    fi
    
    log "Environment variables specified: $PROJECT_ENV_VARS"
  fi
  
  # Validate Nix build parameters if enabled
  if [[ "$USE_NIX_BUILD" == true ]]; then
    if [[ -z "$MONO_REPO_PATH" ]]; then
      log "ERROR: Monorepo path is required when using Nix build. Use --mono-repo to specify."
      exit 1
    fi
    
    if [[ ! -d "$MONO_REPO_PATH" ]]; then
      log "ERROR: Monorepo path does not exist: $MONO_REPO_PATH"
      exit 1
    fi
    
    if [[ -z "$FRONTEND_PATH" ]]; then
      log "ERROR: Frontend path is required when using Nix build. Use --frontend-path to specify."
      exit 1
    fi
    
    if [[ -z "$FRONTEND_BUILD_DIR" ]]; then
      log "ERROR: Frontend build directory is required when using Nix build. Use --frontend-build-dir to specify."
      exit 1
    fi
    
    if [[ -z "$FRONTEND_BUILD_CMD" ]]; then
      log "ERROR: Frontend build command is required when using Nix build. Use --frontend-build-cmd to specify."
      exit 1
    fi
    
    # Backend is optional, but if path is specified, command is required
    if [[ -n "$BACKEND_PATH" && -z "$BACKEND_BUILD_CMD" ]]; then
      log "ERROR: Backend build command is required when backend path is specified. Use --backend-build-cmd to specify."
      exit 1
    fi
    
    # If backend start command is not specified, use build command
    if [[ -n "$BACKEND_PATH" && -z "$BACKEND_START_CMD" ]]; then
      log "Backend start command not specified, using build command as default."
      BACKEND_START_CMD="$BACKEND_BUILD_CMD"
    fi
    
    # Normalize paths
    MONO_REPO_PATH=$(realpath "$MONO_REPO_PATH" 2>/dev/null || echo "")
    if [[ -z "$MONO_REPO_PATH" ]]; then
      log "ERROR: Failed to resolve monorepo path. Please provide a valid path."
      exit 1
    fi
    
    # Check for flake.nix in monorepo
    if [[ ! -f "$MONO_REPO_PATH/flake.nix" ]]; then
      log "Warning: flake.nix not found in monorepo root. Nix environment detection may fail."
    fi
  fi
  
  log "Arguments parsed successfully: PROJECT_NAME=$PROJECT_NAME, DOMAIN_NAME=$DOMAIN_NAME, ENV_TYPE=$ENV_TYPE"
  if [[ "$USE_NIX_BUILD" == true ]]; then
    log "Nix build enabled: MONO_REPO_PATH=$MONO_REPO_PATH, FRONTEND_PATH=$FRONTEND_PATH, BACKEND_PATH=$BACKEND_PATH"
    if [[ -n "$BACKEND_PATH" ]]; then
      log "Backend configuration: BUILD_CMD=$BACKEND_BUILD_CMD, START_CMD=$BACKEND_START_CMD"
    fi
  fi
  log "Frontend mount point: $FRONTEND_MOUNT"
} 