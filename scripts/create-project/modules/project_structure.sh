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
  mkdir -p "${project_dir}/html"
  mkdir -p "${project_dir}/conf.d"
  mkdir -p "${project_dir}/logs"
  mkdir -p "${project_dir}/certs"
  
  # Create health endpoint directory and file
  mkdir -p "${project_dir}/html/health"
  echo "OK" > "${project_dir}/html/health/index.html"
  
  # Setup domain-specific certificates from global certs directory
  log "Setting up certificates for domain ${DOMAIN_NAME}..."
  local domain_certs_dir="${CERTS_DIR}/${DOMAIN_NAME}"
  
  # Check if generic certificates exist first
  if [[ ! -f "${CERTS_DIR}/cert.pem" ]] || [[ ! -f "${CERTS_DIR}/cert-key.pem" ]]; then
    handle_error "Generic certificates not found in ${CERTS_DIR}. Please ensure cert.pem and cert-key.pem exist."
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
  
  log "Project directory structure created at ${project_dir}"
} 