#!/bin/bash

# Module for environment validation and configuration

# Function: Validate environment
function validate_environment() {
  log "Validating environment..."
  
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
  log "Environment validation completed successfully"
}

# Function: Configure development environment
function configure_dev_environment() {
  log "Configuring development environment for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # No need to generate certificates, they are copied from the global certs directory
  
  # Update local hosts file
  log "Updating local hosts file..."
  sudo "${PROJECT_ROOT}/scripts/update-hosts.sh" --domain "$DOMAIN_NAME" --action add || handle_error "Failed to update hosts file"
  
  # Configure development environment
  log "Setting up development environment..."
  "${PROJECT_ROOT}/scripts/dev-environment.sh" --project "$PROJECT_NAME" --action setup --port "$PROJECT_PORT" || handle_error "Failed to setup development environment"
  
  log "Development environment configured successfully for $PROJECT_NAME"
}

# Function: Configure production environment
function configure_pro_environment() {
  log "Configuring production environment for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # No need to generate certificates for production, they are copied from the global certs directory
  
  log "Production environment configured successfully for $PROJECT_NAME"
} 