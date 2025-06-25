#!/bin/bash

# fresh-restart.sh - Complete environment cleanup script
# This script provides a nuclear option to completely reset the nginx multi-project environment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script information
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/fresh-restart.log"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${BLUE}[$timestamp]${NC} $1" | tee -a "$LOG_FILE"
}

# Function: Log success messages
function log_success() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${GREEN}[$timestamp] ✅ $1${NC}" | tee -a "$LOG_FILE"
}

# Function: Log warning messages
function log_warning() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${YELLOW}[$timestamp] ⚠️  $1${NC}" | tee -a "$LOG_FILE"
}

# Function: Log error messages
function log_error() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo -e "${RED}[$timestamp] ❌ ERROR: $1${NC}" | tee -a "$LOG_FILE"
}

# Function: Display header
function display_header() {
  echo -e "${BLUE}"
  echo "=================================================================="
  echo "🧹 NGINX MULTI-PROJECT FRESH RESTART SCRIPT"
  echo "=================================================================="
  echo "This script will completely clean your environment:"
  echo "• Stop and remove ALL containers"
  echo "• Remove ALL custom images (keeps base nginx:alpine)"
  echo "• Prune ALL networks"
  echo "• Delete ALL project directories"
  echo "• Clean ALL configuration files"
  echo "=================================================================="
  echo -e "${NC}"
}

# Function: Confirm action
function confirm_action() {
  echo -e "${YELLOW}⚠️  WARNING: This action is IRREVERSIBLE!${NC}"
  echo -e "${YELLOW}   All your project data will be permanently deleted.${NC}"
  echo ""
  read -p "Are you sure you want to proceed? (type 'YES' to confirm): " confirmation
  
  if [ "$confirmation" != "YES" ]; then
    log_warning "Operation cancelled by user"
    exit 0
  fi
  
  log "User confirmed fresh restart operation"
}

# Function: Check Nix environment
function check_nix_environment() {
  if [ -z "${IN_NIX_SHELL:-}" ]; then
    log_error "Not in Nix environment. Please run: nix --extra-experimental-features \"nix-command flakes\" develop"
    exit 1
  fi
  log_success "Nix environment detected"
}

# Function: Clean containers
function clean_containers() {
  log "🧹 Stopping and removing ALL containers..."
  
  # Stop all containers
  if podman ps -q | grep -q .; then
    log "Stopping all running containers..."
    podman stop --all --time 10 || log_warning "Some containers may have failed to stop gracefully"
    log_success "All containers stopped"
  else
    log "No running containers found"
  fi
  
  # Remove all containers
  if podman ps -aq | grep -q .; then
    log "Removing all containers..."
    podman rm --all --force || log_warning "Some containers may have failed to remove"
    log_success "All containers removed"
  else
    log "No containers to remove"
  fi
}

# Function: Clean images
function clean_images() {
  log "🖼️  Removing ALL custom images (keeping base nginx:alpine)..."
  
  # Get all images except nginx:alpine
  local custom_images=$(podman images --format "{{.Repository}}:{{.Tag}}" | grep -v "docker.io/library/nginx:alpine" | grep -v "<none>:<none>" || true)
  
  if [ -n "$custom_images" ]; then
    log "Removing custom images:"
    echo "$custom_images" | while read -r image; do
      if [ -n "$image" ]; then
        log "  - Removing $image"
        podman rmi "$image" --force || log_warning "Failed to remove $image"
      fi
    done
    log_success "Custom images removed"
  else
    log "No custom images to remove"
  fi
  
  # Clean up dangling images
  log "Cleaning up dangling images..."
  podman image prune --force || log_warning "Failed to prune dangling images"
  log_success "Dangling images cleaned"
}

# Function: Clean networks
function clean_networks() {
  log "🌐 Pruning ALL networks..."
  
  # Remove specific custom networks first
  local custom_networks=(
    "nginx-proxy-network"
    "proxy_nginx-proxy-network"
    "xmoses-network"
    "xmoses_xmoses-network"
    "mapa-kms-network"
    "mapa-kms_mapa-kms-network"
    "powerpain-network"
    "powerpain_powerpain-network"
  )
  
  for network in "${custom_networks[@]}"; do
    if podman network exists "$network" 2>/dev/null; then
      log "Removing network: $network"
      podman network rm "$network" || log_warning "Failed to remove network $network"
    fi
  done
  
  # Prune all unused networks
  log "Pruning all unused networks..."
  podman network prune --force || log_warning "Failed to prune networks"
  log_success "Network cleanup completed"
}

# Function: Clean project directories
function clean_project_directories() {
  log "🗂️  Cleaning project directories..."
  
  local projects_dir="${PROJECT_ROOT}/projects"
  
  if [ -d "$projects_dir" ]; then
    # Remove all project subdirectories except essential files
    find "$projects_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Project directories cleaned"
  else
    log "Projects directory not found"
  fi
}

# Function: Clean configuration files
function clean_configuration_files() {
  log "📋 Cleaning configuration files..."
  
  # Clean proxy domain configurations
  local domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  if [ -d "$domains_dir" ]; then
    find "$domains_dir" -name "*.conf" -delete 2>/dev/null || true
    log_success "Proxy domain configurations cleaned"
  fi
  
  # Clean domain-specific certificates
  local proxy_certs_dir="${PROJECT_ROOT}/proxy/certs"
  if [ -d "$proxy_certs_dir" ]; then
    find "$proxy_certs_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Domain-specific certificates cleaned"
  fi
  
  # Clean any temporary or runtime files
  find "$PROJECT_ROOT" -name "docker-compose.override.yml" -delete 2>/dev/null || true
  find "$PROJECT_ROOT" -name "*.backup.*" -delete 2>/dev/null || true
  
  log_success "Configuration files cleaned"
}

# Function: Display final status
function display_final_status() {
  log "📊 Final environment status:"
  
  echo ""
  echo -e "${GREEN}Containers:${NC}"
  podman ps -a || echo "No containers"
  
  echo ""
  echo -e "${GREEN}Networks:${NC}"
  podman network ls || echo "No networks"
  
  echo ""
  echo -e "${GREEN}Images:${NC}"
  podman images || echo "No images"
  
  echo ""
  echo -e "${GREEN}Projects Directory:${NC}"
  ls -la "${PROJECT_ROOT}/projects/" 2>/dev/null | head -5 || echo "Directory empty or not found"
  
  echo ""
  echo -e "${GREEN}Proxy Domains:${NC}"
  ls -la "${PROJECT_ROOT}/proxy/conf.d/domains/" 2>/dev/null | head -5 || echo "Directory empty or not found"
}

# Function: Display completion message
function display_completion() {
  echo ""
  echo -e "${GREEN}"
  echo "=================================================================="
  echo "🎉 FRESH RESTART COMPLETED SUCCESSFULLY!"
  echo "=================================================================="
  echo "Your nginx multi-project environment has been reset to:"
  echo "• ✅ No containers running"
  echo "• ✅ No custom images (only base nginx:alpine)"
  echo "• ✅ Clean networks (only default podman bridge)"
  echo "• ✅ Empty project directories"
  echo "• ✅ Clean configuration files"
  echo "• ✅ Master SSL certificates preserved"
  echo ""
  echo "🚀 Your environment is now ready for fresh deployments!"
  echo "=================================================================="
  echo -e "${NC}"
}

# Main execution
main() {
  display_header
  
  # Confirm before proceeding
  confirm_action
  
  # Check environment
  check_nix_environment
  
  log "Starting fresh restart process..."
  
  # Execute cleanup steps
  clean_containers
  clean_images
  clean_networks
  clean_project_directories
  clean_configuration_files
  
  # Display results
  display_final_status
  display_completion
  
  log_success "Fresh restart process completed successfully"
}

# Execute main function
main "$@" 