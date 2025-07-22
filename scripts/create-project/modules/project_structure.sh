#!/bin/bash

# Module for project structure setup
#
# Certificate Workflow:
# 1. Generic certificates MUST exist in /opt/nginx-multi-project/certs/ (cert.pem, cert-key.pem)
# 2. For each new project, create domain-specific directory: /opt/nginx-multi-project/certs/{domain}/
# 3. Copy generic certificates to domain-specific directory (enables future domain-specific customization)
# 4. Copy domain-specific certificates to project container directory
# 5. Proxy will also use domain-specific certificates from the same source

# Function: Setup project structure
function setup_project_structure() {
  log "Setting up project structure for '${PROJECT_NAME}'..."
  
  # Create project directory
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Check if this is a monorepo project
  if [[ "$IS_MONOREPO" == true ]]; then
    if ! setup_monorepo_structure "$project_dir"; then
      return 1
    fi
  else
    if ! setup_standard_structure "$project_dir"; then
      return 1
    fi
  fi
  
  # Setup certificates (common for both types)
  if ! setup_project_certificates "$project_dir"; then
    return 1
  fi
  
  log "Project directory structure created at ${project_dir}"
}

# Function: Setup standard project structure
function setup_standard_structure() {
  local project_dir="$1"
  
  log "Setting up standard project structure..."
  mkdir -p "${project_dir}/html"
  mkdir -p "${project_dir}/conf.d"
  mkdir -p "${project_dir}/logs"
  mkdir -p "${project_dir}/certs"
  
  # Create health endpoint directory and file
  mkdir -p "${project_dir}/html/health"
  echo "OK" > "${project_dir}/html/health/index.html"
}

# Function: Setup monorepo project structure
function setup_monorepo_structure() {
  local project_dir="$1"
  
  log "Setting up monorepo project structure..."
  log "Monorepo directory: $MONOREPO_DIR"
  log "Frontend subdirectory: $FRONTEND_SUBDIR"
  log "Build output directory: $BUILD_OUTPUT_DIR"
  
  # Create necessary directories (no html since it comes from build)
  mkdir -p "${project_dir}/conf.d"
  mkdir -p "${project_dir}/logs"
  mkdir -p "${project_dir}/certs"
  
  # Verify monorepo paths
  if [[ ! -d "$MONOREPO_DIR" ]]; then
    handle_error "Monorepo directory not found: $MONOREPO_DIR"
    return 1
  fi
  
  if [[ ! -d "$MONOREPO_DIR/$FRONTEND_SUBDIR" ]]; then
    handle_error "Frontend subdirectory not found: $MONOREPO_DIR/$FRONTEND_SUBDIR"
    return 1
  fi
  
  # Validate backend subdirectory if backend is enabled
  if [[ "$HAS_BACKEND" == "true" ]] && [[ ! -d "$MONOREPO_DIR/$BACKEND_SUBDIR" ]]; then
    handle_error "Backend subdirectory not found: $MONOREPO_DIR/$BACKEND_SUBDIR"
    return 1
  fi
  
  # Generate Cargo.lock if missing for Rust backend (CRITICAL for Nix builds)
  if [[ "$HAS_BACKEND" == "true" ]] && [[ -n "$BACKEND_SUBDIR" ]]; then
    local backend_path="$MONOREPO_DIR/$BACKEND_SUBDIR"
    if [[ -f "$backend_path/Cargo.toml" ]] && [[ ! -f "$backend_path/Cargo.lock" ]]; then
      log "Generating missing Cargo.lock for Rust backend..."
      if [[ "$USE_EXISTING_NIX" == "true" ]]; then
        # Use Nix development environment to generate lockfile
        cd "$MONOREPO_DIR" && nix --extra-experimental-features "nix-command flakes" develop --command bash -c "cd $BACKEND_SUBDIR && cargo generate-lockfile"
      else
        # Use system cargo
        cd "$backend_path" && cargo generate-lockfile
      fi
      if [[ $? -eq 0 ]]; then
        log "Successfully generated Cargo.lock"
      else
        handle_error "Failed to generate Cargo.lock for backend"
        return 1
      fi
    fi
  fi
  
  # Create monorepo context file for build process
  local backend_config=""
  if [[ "$HAS_BACKEND" == "true" ]]; then
    backend_config="
# Backend Configuration
HAS_BACKEND=$HAS_BACKEND
BACKEND_SUBDIR=$BACKEND_SUBDIR
BACKEND_PORT=$BACKEND_PORT
BACKEND_FRAMEWORK=${BACKEND_FRAMEWORK:-unknown}
BACKEND_BUILD_CMD=$BACKEND_BUILD_CMD
BACKEND_OUTPUT_DIR=$BACKEND_OUTPUT_DIR"
  fi
  
  cat > "${project_dir}/monorepo.env" << EOF
# Monorepo Configuration
IS_MONOREPO=true
MONOREPO_DIR=$MONOREPO_DIR
FRONTEND_SUBDIR=$FRONTEND_SUBDIR
BUILD_OUTPUT_DIR=$BUILD_OUTPUT_DIR
USE_EXISTING_NIX=$USE_EXISTING_NIX
NIX_BUILD_CMD=$NIX_BUILD_CMD
FRONTEND_BUILD_CMD=$FRONTEND_BUILD_CMD${backend_config}
EOF
  
  log "Created monorepo configuration file: ${project_dir}/monorepo.env"
  if [[ "$HAS_BACKEND" == "true" ]]; then
    log "Backend configuration: ${BACKEND_FRAMEWORK:-unknown} in $BACKEND_SUBDIR on port $BACKEND_PORT"
  fi
}

# Function: Setup project certificates
function setup_project_certificates() {
  local project_dir="$1"
  
  # Setup domain-specific certificates from global certs directory
  log "Setting up certificates for domain ${DOMAIN_NAME}..."
  local domain_certs_dir="${CERTS_DIR}/${DOMAIN_NAME}"
  
  # Check if generic certificates exist first
  if [[ ! -f "${CERTS_DIR}/cert.pem" ]] || [[ ! -f "${CERTS_DIR}/cert-key.pem" ]]; then
    handle_error "Generic certificates not found in ${CERTS_DIR}. Please ensure cert.pem and cert-key.pem exist."
    return 1
  fi
  
  # Create domain-specific certificate directory if it doesn't exist
  if [[ ! -d "${domain_certs_dir}" ]]; then
    log "Creating domain-specific certificate directory: ${domain_certs_dir}"
    mkdir -p "${domain_certs_dir}" || handle_error "Failed to create domain certificate directory"
    
    # Copy generic certificates to domain-specific directory
    cp "${CERTS_DIR}/cert.pem" "${domain_certs_dir}/cert.pem" || handle_error "Failed to copy cert.pem to domain directory"
    cp "${CERTS_DIR}/cert-key.pem" "${domain_certs_dir}/cert-key.pem" || handle_error "Failed to copy cert-key.pem to domain directory"
    log "Created domain-specific certificates from generic certificates"
  else
    log "Domain-specific certificates already exist in ${domain_certs_dir}"
  fi
  
  # Now copy domain-specific certificates to project directory
  cp "${domain_certs_dir}/cert.pem" "${project_dir}/certs/cert.pem" || handle_error "Failed to copy domain cert.pem to project"
  cp "${domain_certs_dir}/cert-key.pem" "${project_dir}/certs/cert-key.pem" || handle_error "Failed to copy domain cert-key.pem to project"
  log "Copied domain-specific certificates to project directory"
} 