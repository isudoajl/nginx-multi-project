#!/bin/bash

# Module for build process implementation
# This module handles the build logic for Nix-based containers

# Function: Build project
function build_project() {
  log "Building project '${PROJECT_NAME}'..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Ensure project directory exists
  if [[ ! -d "${project_dir}" ]]; then
    handle_error "Project directory '${project_dir}' does not exist"
  fi
  
  # Check if using Nix build
  if [[ "$USE_NIX_BUILD" == true ]]; then
    build_nix_project "$project_dir"
  else
    log "Standard build process - no build required for non-Nix projects"
  fi
}

# Function: Build Nix project
function build_nix_project() {
  local project_dir="$1"
  
  log "Starting Nix-based build process for project '${PROJECT_NAME}'..."
  
  # Create build log directory
  local build_log_dir="${project_dir}/logs/build"
  mkdir -p "${build_log_dir}"
  local build_log="${build_log_dir}/build_$(date +%Y%m%d_%H%M%S).log"
  
  log "Build logs will be saved to: ${build_log}"
  
  # Ensure the log file exists
  touch "${build_log}"
  
  # Step 1: Detect Nix environment in monorepo
  detect_nix_environment "${project_dir}" >> "${build_log}" 2>&1
  
  # Step 2: Prepare build context
  prepare_build_context "${project_dir}" >> "${build_log}" 2>&1
  
  # Step 3: Build frontend
  build_frontend "${project_dir}" >> "${build_log}" 2>&1
  
  # Step 4: Build backend (if specified)
  if [[ -n "${BACKEND_PATH}" ]]; then
    build_backend "${project_dir}" >> "${build_log}" 2>&1
  fi
  
  # Step 5: Generate build report
  generate_build_report "${project_dir}" "${build_log}" >> "${build_log}" 2>&1
  
  log "Nix-based build process completed successfully"
}

# Function: Detect Nix environment in monorepo
function detect_nix_environment() {
  local project_dir="$1"
  local monorepo_dir="${project_dir}/monorepo"
  
  log "Detecting Nix environment in monorepo..."
  
  # Check if monorepo directory exists
  if [[ ! -d "${monorepo_dir}" ]]; then
    handle_error "Monorepo directory '${monorepo_dir}' does not exist"
  fi
  
  # Check if flake.nix exists in monorepo root
  if [[ -f "${monorepo_dir}/flake.nix" ]]; then
    log "Found flake.nix in monorepo root"
    
    # Validate flake.nix
    if ! nix --extra-experimental-features "nix-command flakes" flake check "${monorepo_dir}" &>/dev/null; then
      log "WARNING: flake.nix validation failed, but continuing anyway"
    else
      log "flake.nix validation successful"
    fi
    
    # Create a symlink to flake.nix in project directory for reference
    ln -sf "${monorepo_dir}/flake.nix" "${project_dir}/flake.nix.ref"
    
    # Check if flake.lock exists
    if [[ -f "${monorepo_dir}/flake.lock" ]]; then
      log "Found flake.lock in monorepo root"
      ln -sf "${monorepo_dir}/flake.lock" "${project_dir}/flake.lock.ref"
    else
      log "WARNING: flake.lock not found in monorepo root"
    fi
  else
    handle_error "flake.nix not found in monorepo root '${monorepo_dir}'"
  fi
  
  log "Nix environment detection completed successfully"
}

# Function: Prepare build context
function prepare_build_context() {
  local project_dir="$1"
  local monorepo_dir="${project_dir}/monorepo"
  
  log "Preparing build context..."
  
  # Create .dockerignore file to optimize build
  cat > "${project_dir}/.dockerignore" << EOF
# Exclude common development files and directories
.git/
node_modules/
**/node_modules/
**/.cache/
**/.DS_Store
**/dist-ssr/
**/coverage/
**/.env
**/.env.*
!**/.env.example

# Exclude test files
**/*.test.*
**/*.spec.*
**/tests/
**/test/
**/cypress/
**/jest/

# Exclude documentation
**/*.md
**/docs/
**/doc/
**/README*
**/LICENSE*
**/CHANGELOG*

# Exclude editor configs
**/.vscode/
**/.idea/
**/.editorconfig
**/.eslintrc*
**/.prettierrc*
**/.stylelintrc*
EOF
  
  log "Created .dockerignore file to optimize build"
  
  # Create build cache directory
  mkdir -p "${project_dir}/cache"
  
  log "Build context preparation completed successfully"
}

# Function: Build frontend
function build_frontend() {
  local project_dir="$1"
  local monorepo_dir="${project_dir}/monorepo"
  local frontend_dir="${monorepo_dir}/${FRONTEND_PATH}"
  
  log "Building frontend..."
  
  # Check if frontend directory exists
  if [[ ! -d "${frontend_dir}" ]]; then
    handle_error "Frontend directory '${frontend_dir}' does not exist"
  fi
  
  # Create build script
  local build_script="${project_dir}/build-frontend.sh"
  cat > "${build_script}" << EOF
#!/bin/bash
set -e

echo "Starting frontend build process..."
cd "${frontend_dir}"

# Enter Nix environment and run build command
nix --extra-experimental-features "nix-command flakes" develop --command bash -c "${FRONTEND_BUILD_CMD}"

# Check build output directory exists
if [[ ! -d "${frontend_dir}/${FRONTEND_BUILD_DIR}" ]]; then
  echo "ERROR: Build output directory '${FRONTEND_BUILD_DIR}' not found after build"
  exit 1
fi

echo "Frontend build completed successfully"
EOF
  
  # Make build script executable
  chmod +x "${build_script}"
  
  log "Frontend build script created: ${build_script}"
  log "Note: The actual build will be performed inside the container during image build"
}

# Function: Build backend
function build_backend() {
  local project_dir="$1"
  local monorepo_dir="${project_dir}/monorepo"
  local backend_dir="${monorepo_dir}/${BACKEND_PATH}"
  
  log "Building backend..."
  
  # Check if backend directory exists
  if [[ ! -d "${backend_dir}" ]]; then
    handle_error "Backend directory '${backend_dir}' does not exist"
  fi
  
  # Create build script
  local build_script="${project_dir}/build-backend.sh"
  cat > "${build_script}" << EOF
#!/bin/bash
set -e

echo "Starting backend build process..."
cd "${backend_dir}"

# Enter Nix environment and run build command
nix --extra-experimental-features "nix-command flakes" develop --command bash -c "${BACKEND_BUILD_CMD}"

echo "Backend build completed successfully"
EOF
  
  # Make build script executable
  chmod +x "${build_script}"
  
  log "Backend build script created: ${build_script}"
  log "Note: The actual build will be performed inside the container during image build"
  
  # Create start script for supervisord
  local start_script="${project_dir}/start-backend.sh"
  cat > "${start_script}" << EOF
#!/bin/bash
set -e

echo "Starting backend service..."
cd /opt/backend

# Start backend using the specified command
${BACKEND_START_CMD}
EOF
  
  # Make start script executable
  chmod +x "${start_script}"
  
  log "Backend start script created: ${start_script}"
  
  # Update supervisord.conf to use the start script
  sed -i "s|command=/bin/sh -c \"cd /opt/backend.*|command=/bin/sh -c \"${BACKEND_START_CMD}\"|" "${project_dir}/supervisord.conf"
  
  log "Updated supervisord.conf with backend start command"
}

# Function: Generate build report
function generate_build_report() {
  local project_dir="$1"
  local build_log="$2"
  
  log "Generating build report..."
  
  # Create build report directory
  local report_dir="${project_dir}/logs/reports"
  mkdir -p "${report_dir}"
  local report_file="${report_dir}/build_report_$(date +%Y%m%d_%H%M%S).md"
  
  # Generate build report
  cat > "${report_file}" << EOF
# Build Report for ${PROJECT_NAME}

## Build Information
- **Project Name:** ${PROJECT_NAME}
- **Domain:** ${DOMAIN_NAME}
- **Build Date:** $(date)
- **Build Type:** Nix-based build

## Build Configuration
- **Monorepo Path:** ${MONO_REPO_PATH}
- **Frontend Path:** ${FRONTEND_PATH}
- **Frontend Build Directory:** ${FRONTEND_BUILD_DIR}
- **Frontend Build Command:** \`${FRONTEND_BUILD_CMD}\`
$([ -n "${BACKEND_PATH}" ] && echo "- **Backend Path:** ${BACKEND_PATH}" || echo "")
$([ -n "${BACKEND_BUILD_CMD}" ] && echo "- **Backend Build Command:** \`${BACKEND_BUILD_CMD}\`" || echo "")
$([ -n "${BACKEND_START_CMD}" ] && echo "- **Backend Start Command:** \`${BACKEND_START_CMD}\`" || echo "")

## Build Status
- **Status:** Prepared for container build
- **Build Scripts:**
  - Frontend Build Script: \`${project_dir}/build-frontend.sh\`
$([ -n "${BACKEND_PATH}" ] && echo "  - Backend Build Script: \`${project_dir}/build-backend.sh\`" || echo "")
$([ -n "${BACKEND_START_CMD}" ] && echo "  - Backend Start Script: \`${project_dir}/start-backend.sh\`" || echo "")

## Next Steps
The actual build will be performed inside the container during image build.
See container logs after deployment for build output.

EOF
  
  log "Build report generated: ${report_file}"
}

# Function: Optimize build performance
function optimize_build_performance() {
  local project_dir="$1"
  
  log "Optimizing build performance..."
  
  # Create build arguments file for reproducible builds
  local build_args_file="${project_dir}/build-args.env"
  cat > "${build_args_file}" << EOF
# Build arguments for reproducible builds
PROJECT_NAME=${PROJECT_NAME}
DOMAIN_NAME=${DOMAIN_NAME}
BUILD_TIMESTAMP=$(date +%Y%m%d%H%M%S)
EOF
  
  log "Build arguments file created: ${build_args_file}"
  
  # Update Dockerfile to use build arguments
  sed -i "s|FROM nixos/nix:latest AS builder|FROM nixos/nix:latest AS builder\\nARG PROJECT_NAME\\nARG DOMAIN_NAME\\nARG BUILD_TIMESTAMP|" "${project_dir}/Dockerfile"
  
  log "Updated Dockerfile to use build arguments for reproducible builds"
  
  # Add build cache configuration
  cat >> "${project_dir}/.dockerignore" << EOF
# Cache directories for faster builds
!cache/
EOF
  
  log "Build performance optimization completed successfully"
} 