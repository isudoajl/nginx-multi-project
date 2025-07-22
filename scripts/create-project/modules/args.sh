#!/bin/bash

# Module for argument parsing and validation

# Function: Detect backend framework in monorepo
function detect_backend_framework() {
  BACKEND_FRAMEWORK=""
  BACKEND_BUILD_CMD=""
  BACKEND_OUTPUT_DIR=""
  
  if [[ -z "$BACKEND_SUBDIR" ]] || [[ ! -d "$MONOREPO_DIR/$BACKEND_SUBDIR" ]]; then
    log "No backend directory specified or found, skipping backend detection"
    return 0
  fi
  
  local backend_path="$MONOREPO_DIR/$BACKEND_SUBDIR"
  
  # Rust detection
  if [[ -f "$backend_path/Cargo.toml" ]]; then
    BACKEND_FRAMEWORK="rust"
    BACKEND_OUTPUT_DIR="target/release"
    if [[ -z "$BACKEND_BUILD_CMD" ]]; then
      BACKEND_BUILD_CMD="cargo build --release"
    fi
    log "Detected Rust backend framework in $BACKEND_SUBDIR"
  # Node.js detection
  elif [[ -f "$backend_path/package.json" ]]; then
    BACKEND_FRAMEWORK="nodejs"
    BACKEND_OUTPUT_DIR="dist"
    if [[ -z "$BACKEND_BUILD_CMD" ]]; then
      if grep -q '"build"' "$backend_path/package.json"; then
        BACKEND_BUILD_CMD="npm run build"
      else
        BACKEND_BUILD_CMD="npm install"
      fi
    fi
    log "Detected Node.js backend framework in $BACKEND_SUBDIR"
  # Go detection
  elif [[ -f "$backend_path/go.mod" ]]; then
    BACKEND_FRAMEWORK="go"
    BACKEND_OUTPUT_DIR="bin"
    if [[ -z "$BACKEND_BUILD_CMD" ]]; then
      BACKEND_BUILD_CMD="go build -o bin/ ."
    fi
    log "Detected Go backend framework in $BACKEND_SUBDIR"
  # Python detection
  elif [[ -f "$backend_path/requirements.txt" ]] || [[ -f "$backend_path/pyproject.toml" ]] || [[ -f "$backend_path/setup.py" ]]; then
    BACKEND_FRAMEWORK="python"
    BACKEND_OUTPUT_DIR="dist"
    if [[ -z "$BACKEND_BUILD_CMD" ]]; then
      if [[ -f "$backend_path/pyproject.toml" ]]; then
        BACKEND_BUILD_CMD="pip install build && python -m build"
      else
        BACKEND_BUILD_CMD="pip install -r requirements.txt"
      fi
    fi
    log "Detected Python backend framework in $BACKEND_SUBDIR"
  else
    log "No recognized backend framework found in $BACKEND_SUBDIR"
    BACKEND_FRAMEWORK="unknown"
  fi
  
  # Export variables for use in other modules
  export BACKEND_FRAMEWORK
  export BACKEND_BUILD_CMD
  export BACKEND_OUTPUT_DIR
}

# Function: Detect existing Nix configuration in monorepo
function detect_nix_configuration() {
  USE_EXISTING_NIX=false
  NIX_BUILD_CMD=""
  BUILD_OUTPUT_DIR=""
  
  # Check for existing flake.nix
  if [[ -f "${MONOREPO_DIR}/flake.nix" ]]; then
    log "Detected existing Nix flake configuration in monorepo"
    USE_EXISTING_NIX=true
    
    # Set default Nix build command if not specified
    if [[ -z "$FRONTEND_BUILD_CMD" ]]; then
      NIX_BUILD_CMD="nix build .#frontend"
      log "Using default Nix build command: $NIX_BUILD_CMD"
    else
      NIX_BUILD_CMD="$FRONTEND_BUILD_CMD"
      log "Using custom build command: $NIX_BUILD_CMD"
    fi
    
    # Check for common output directories
    if [[ -d "$MONOREPO_DIR/dist" ]]; then
      BUILD_OUTPUT_DIR="dist"
    elif [[ -d "$MONOREPO_DIR/build" ]]; then
      BUILD_OUTPUT_DIR="build"
    elif [[ -d "$MONOREPO_DIR/$FRONTEND_SUBDIR/dist" ]]; then
      BUILD_OUTPUT_DIR="dist"  # Relative to FRONTEND_SUBDIR
    elif [[ -d "$MONOREPO_DIR/$FRONTEND_SUBDIR/build" ]]; then
      BUILD_OUTPUT_DIR="build"  # Relative to FRONTEND_SUBDIR
    else
      BUILD_OUTPUT_DIR="dist"  # Default fallback
    fi
    
    log "Detected build output directory: $BUILD_OUTPUT_DIR"
    
    # Check for package.json to detect npm commands
    if [[ -f "$MONOREPO_DIR/$FRONTEND_SUBDIR/package.json" ]]; then
      log "Detected package.json in frontend directory"
      # If no custom build command specified, check for npm scripts
      if [[ -z "$FRONTEND_BUILD_CMD" ]]; then
        if grep -q '"build"' "$MONOREPO_DIR/$FRONTEND_SUBDIR/package.json"; then
          FRONTEND_BUILD_CMD="npm run build"
          log "Detected npm build script, using: $FRONTEND_BUILD_CMD"
        fi
      fi
    fi
  else
    log "No flake.nix found in monorepo, using standard build process"
    USE_EXISTING_NIX=false
    
    # For non-Nix monorepo projects, still try to detect build commands
    if [[ -f "$MONOREPO_DIR/$FRONTEND_SUBDIR/package.json" ]] && [[ -z "$FRONTEND_BUILD_CMD" ]]; then
      if grep -q '"build"' "$MONOREPO_DIR/$FRONTEND_SUBDIR/package.json"; then
        FRONTEND_BUILD_CMD="npm run build"
        log "Detected npm build script, using: $FRONTEND_BUILD_CMD"
      fi
    fi
    
    # Set default output directory for non-Nix projects
    BUILD_OUTPUT_DIR="dist"
  fi
  
  # Detect backend framework if backend is enabled
  if [[ "$HAS_BACKEND" == "true" ]]; then
    detect_backend_framework
  fi
  
  # Export variables for use in other modules
  export USE_EXISTING_NIX
  export NIX_BUILD_CMD
  export BUILD_OUTPUT_DIR
  export FRONTEND_BUILD_CMD
}

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Create a new project container with all necessary configuration files."
  echo ""
  echo "Options:"
  echo "  --name, -n NAME          Project name (required, alphanumeric with hyphens)"
  echo "  --domain, -d DOMAIN      Domain name (required, valid FQDN format)"
  echo "  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)"
  echo "  --frontend-mount, -m DIR Path to mount as frontend in container (optional, default: ./html)"
  echo "  --cert, -c FILE          Path to SSL certificate (optional)"
  echo "  --key, -k FILE           Path to SSL private key (optional)"
  echo "  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)"
  echo "  --monorepo, -r DIR       Path to monorepo root directory (optional)"
  echo "  --frontend-dir, -i DIR   Relative path to frontend directory within monorepo (optional, default: frontend)"
  echo "  --frontend-build, -F CMD Custom frontend build command (optional, overrides detected command)"
  echo "  --backend-dir, -b DIR    Relative path to backend directory within monorepo (optional)"
  echo "  --backend-build, -B CMD  Custom backend build command (optional, overrides detected command)"
  echo "  --backend-port, -P PORT  Internal port for backend service (optional, default: 8080)"
  echo "  --help, -h               Display this help message"
  echo ""
  echo "Examples:"
  echo "  Standard project:"
  echo "    $0 --name my-project --domain example.com"
  echo "    $0 -n my-project -d example.com -e DEV"
  echo "    $0 -n my-project -d example.com -e PRO"
  echo "    $0 -n my-project -d example.com -m /path/to/frontend"
  echo ""
  echo "  Monorepo project (frontend only):"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --env DEV"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --frontend-dir web --env DEV"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --frontend-build 'npm run build:custom' --env DEV"
  echo ""
  echo "  Monorepo project (full-stack):"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --backend-dir backend --env DEV"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --frontend-dir web --backend-dir api --backend-port 3000 --env DEV"
  echo "    $0 --name my-app --domain my-app.local --monorepo /path/to/monorepo --backend-dir backend --backend-build 'cargo build --release' --env DEV"
}

# Function: Parse arguments
function parse_arguments() {
  PROJECT_NAME=""
  PROJECT_PORT="80"  # Default internal port is 80
  DOMAIN_NAME=""
  FRONTEND_DIR=""
  FRONTEND_MOUNT=""
  CERT_PATH=""
  KEY_PATH=""
  ENV_TYPE="DEV"
  # Monorepo-specific variables
  MONOREPO_DIR=""
  FRONTEND_SUBDIR="frontend"
  FRONTEND_BUILD_CMD=""
  IS_MONOREPO=false
  # Backend-specific variables
  BACKEND_SUBDIR=""
  BACKEND_BUILD_CMD=""
  BACKEND_PORT="8080"
  HAS_BACKEND=false

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
      --monorepo|-r)
        MONOREPO_DIR="$2"
        IS_MONOREPO=true
        shift 2
        ;;
      --frontend-dir|-i)
        FRONTEND_SUBDIR="$2"
        shift 2
        ;;
      --frontend-build|-F)
        FRONTEND_BUILD_CMD="$2"
        shift 2
        ;;
      --backend-dir|-b)
        BACKEND_SUBDIR="$2"
        HAS_BACKEND=true
        shift 2
        ;;
      --backend-build|-B)
        BACKEND_BUILD_CMD="$2"
        shift 2
        ;;
      --backend-port|-P)
        BACKEND_PORT="$2"
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

  if [[ -z "$DOMAIN_NAME" ]]; then
    handle_error "Domain name is required. Use --domain or -d to specify."
  fi

  # Validate project name format
  if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    handle_error "Invalid project name format: $PROJECT_NAME. Use only alphanumeric characters and hyphens."
  fi

  # Validate domain format
  if ! [[ "$DOMAIN_NAME" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    handle_error "Invalid domain format: $DOMAIN_NAME"
  fi

  # Validate environment type
  if [[ "$ENV_TYPE" != "DEV" && "$ENV_TYPE" != "PRO" ]]; then
    handle_error "Environment type must be either DEV or PRO."
  fi
  
  # Validate backend port if backend is enabled
  if [[ "$HAS_BACKEND" == "true" ]]; then
    if ! [[ "$BACKEND_PORT" =~ ^[0-9]+$ ]] || [[ "$BACKEND_PORT" -lt 1 ]] || [[ "$BACKEND_PORT" -gt 65535 ]]; then
      handle_error "Invalid backend port: $BACKEND_PORT. Must be a number between 1 and 65535."
    fi
  fi

  # Validate monorepo parameters
  if [[ "$IS_MONOREPO" == true ]]; then
    # Validate monorepo directory exists
    if [[ ! -d "$MONOREPO_DIR" ]]; then
      handle_error "Monorepo directory does not exist: $MONOREPO_DIR"
    fi
    
    # Validate frontend subdirectory exists within monorepo
    if [[ ! -d "$MONOREPO_DIR/$FRONTEND_SUBDIR" ]]; then
      handle_error "Frontend directory does not exist in monorepo: $MONOREPO_DIR/$FRONTEND_SUBDIR"
    fi
    
    # Validate backend subdirectory if backend is enabled
    if [[ "$HAS_BACKEND" == "true" ]] && [[ ! -d "$MONOREPO_DIR/$BACKEND_SUBDIR" ]]; then
      handle_error "Backend directory does not exist in monorepo: $MONOREPO_DIR/$BACKEND_SUBDIR"
    fi
    
    # Convert to absolute path
    MONOREPO_DIR="$(realpath "$MONOREPO_DIR")"
    
    # Set frontend directory to the monorepo frontend path
    FRONTEND_DIR="$MONOREPO_DIR/$FRONTEND_SUBDIR"
    
    log "Monorepo mode enabled: $MONOREPO_DIR"
    log "Frontend directory: $FRONTEND_DIR"
    if [[ "$HAS_BACKEND" == "true" ]]; then
      log "Backend directory: $MONOREPO_DIR/$BACKEND_SUBDIR"
      log "Backend port: $BACKEND_PORT"
    fi
  fi

  # Set default frontend directory if not specified and not monorepo
  if [[ -z "$FRONTEND_DIR" && "$IS_MONOREPO" == false ]]; then
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
  
  # Detect existing Nix configuration for monorepo projects
  if [[ "$IS_MONOREPO" == true ]]; then
    detect_nix_configuration
  fi
  
  log "Arguments parsed successfully: PROJECT_NAME=$PROJECT_NAME, DOMAIN_NAME=$DOMAIN_NAME, ENV_TYPE=$ENV_TYPE"
  log "Frontend mount point: $FRONTEND_MOUNT"
  if [[ "$IS_MONOREPO" == true ]]; then
    log "Monorepo configuration: DIR=$MONOREPO_DIR, FRONTEND_SUBDIR=$FRONTEND_SUBDIR"
    if [[ "$HAS_BACKEND" == "true" ]]; then
      log "Backend configuration: BACKEND_SUBDIR=$BACKEND_SUBDIR, BACKEND_PORT=$BACKEND_PORT"
      log "Backend framework detected: ${BACKEND_FRAMEWORK:-unknown}"
    fi
    log "Nix configuration detected: USE_EXISTING_NIX=${USE_EXISTING_NIX:-false}"
  fi
} 