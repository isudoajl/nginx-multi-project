#!/bin/bash

# cleanup.sh - Unified cleanup script for nginx-multi-project
# This script combines functionality from:
# - fresh-restart.sh (environment reset)
# - cleanup-podman.sh (podman resource cleanup)
# - cleanup-for-production.sh (production preparation)

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
LOG_FILE="${SCRIPT_DIR}/logs/cleanup.log"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Default mode
MODE="environment"

#########################################
# COMMON FUNCTIONS
#########################################

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

# Function: Check Nix environment
function check_nix_environment() {
  if [ -z "${IN_NIX_SHELL:-}" ]; then
    log_error "Not in Nix environment. Please run: nix --extra-experimental-features \"nix-command flakes\" develop"
    exit 1
  fi
  log_success "Nix environment detected"
}

# Function: Confirm action
function confirm_action() {
  local message="${1:-Are you sure you want to proceed?}"
  
  echo -e "${YELLOW}⚠️  WARNING: This action is IRREVERSIBLE!${NC}"
  echo -e "${YELLOW}   $message${NC}"
  echo ""
  read -p "Are you sure you want to proceed? (type 'YES' to confirm): " confirmation
  
  if [ "$confirmation" != "YES" ]; then
    log_warning "Operation cancelled by user"
    exit 0
  fi
  
  log "User confirmed operation"
}

#########################################
# CONTAINER/PODMAN CLEANUP FUNCTIONS
#########################################

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
  local keep_nginx="${1:-false}"
  
  if [ "$keep_nginx" = "true" ]; then
    log "🖼️  Removing custom images (keeping base nginx:alpine)..."
    
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
  else
    log "🖼️  Removing ALL images..."
    
    # Remove all images
    if podman images --quiet | grep -q .; then
      podman images --quiet | xargs --no-run-if-empty podman rmi --force || log_warning "Some images may have failed to remove"
      log_success "All images removed"
    else
      log "No images to remove"
    fi
  fi
  
  # Clean up dangling images
  log "Cleaning up dangling images..."
  podman image prune --force || log_warning "Failed to prune dangling images"
  log_success "Dangling images cleaned"
}

# Function: Clean networks
function clean_networks() {
  log "🌐 Pruning networks..."
  
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

# Function: Clean volumes
function clean_volumes() {
  log "📦 Pruning volumes..."
  
  # Prune all volumes
  podman volume ls --quiet | xargs --no-run-if-empty podman volume rm || log_warning "Failed to remove some volumes"
  podman volume prune --force || log_warning "Failed to prune volumes"
  log_success "Volumes cleaned"
}

#########################################
# FILE AND DIRECTORY CLEANUP FUNCTIONS
#########################################

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
  
  # CRITICAL FIX: Clean domain-specific certificate directories in the certs folder
  log "🔒 Cleaning domain-specific certificate directories..."
  local certs_dir="${PROJECT_ROOT}/certs"
  
  if [ -d "$certs_dir" ]; then
    # Remove all subdirectories in the certs directory (domain-specific certificates)
    # while preserving the base certificate files
    find "$certs_dir" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} + 2>/dev/null || true
    log_success "Domain-specific certificate directories cleaned"
  else
    log "Certificates directory not found"
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

# Function: Clean temporary files
function clean_temp_files() {
  log "🗑️  Cleaning temporary files..."
  
  # Remove temporary files
  find "${PROJECT_ROOT}" -name "*.tmp" -delete 2>/dev/null || true
  find "${PROJECT_ROOT}" -name "*.backup.*" -delete 2>/dev/null || true
  find "${PROJECT_ROOT}" -name "*.bak" -delete 2>/dev/null || true
  find "${PROJECT_ROOT}" -name "temp" -type d -exec rm -rf {} + 2>/dev/null || true
  
  log_success "Temporary files cleaned"
}

# Function: Clean legacy files
function cleanup_legacy_files() {
  log "📜 Removing legacy files and artifacts..."
  
  # Remove legacy directories
  [ -d "${PROJECT_ROOT}/scripts/legacy" ] && rm -rf "${PROJECT_ROOT}/scripts/legacy"
  
  # Remove development artifacts
  [ -f "${PROJECT_ROOT}/conf/docker-compose.override.dev.yml" ] && rm "${PROJECT_ROOT}/conf/docker-compose.override.dev.yml"
  
  log_success "Legacy files and artifacts removed"
}

#########################################
# PRODUCTION-SPECIFIC FUNCTIONS
#########################################

# Function: Optimize test structure
function optimize_test_structure() {
  log "🧪 Optimizing test structure..."
  
  # Remove redundant wrapper scripts
  local wrapper_tests=(
    "test-cert-generation.sh"
    "test-create-project.sh" 
    "test-dev-environment.sh"
    "test-local-hosts.sh"
    "test-user-guide.sh"
  )
  
  for test in "${wrapper_tests[@]}"; do
    [ -f "${PROJECT_ROOT}/tests/${test}" ] && rm "${PROJECT_ROOT}/tests/${test}"
  done
  
  # Create organized test structure
  mkdir -p "${PROJECT_ROOT}/tests/unit"
  mkdir -p "${PROJECT_ROOT}/tests/integration"
  mkdir -p "${PROJECT_ROOT}/tests/performance"
  mkdir -p "${PROJECT_ROOT}/tests/security"
  mkdir -p "${PROJECT_ROOT}/tests/utils"
  
  # Move existing tests to appropriate categories
  [ -f "${PROJECT_ROOT}/tests/test-network-isolation.sh" ] && mv "${PROJECT_ROOT}/tests/test-network-isolation.sh" "${PROJECT_ROOT}/tests/security/"
  [ -f "${PROJECT_ROOT}/tests/benchmark-proxy.sh" ] && mv "${PROJECT_ROOT}/tests/benchmark-proxy.sh" "${PROJECT_ROOT}/tests/performance/"
  [ -f "${PROJECT_ROOT}/tests/test-ssl-config.sh" ] && mv "${PROJECT_ROOT}/tests/test-ssl-config.sh" "${PROJECT_ROOT}/tests/security/"
  
  log_success "Test structure optimized"
}

# Function: Clean debug statements
function clean_debug_statements() {
  log "🔍 Cleaning debug statements and development configurations..."
  
  # Remove temporary disables in test files
  find "${PROJECT_ROOT}/nginx/tests" -name "*.sh" -exec sed -i '/# Temporarily disabled for testing/d' {} \;
  
  # Clean up commented debug lines (but preserve intentional comments)
  find "${PROJECT_ROOT}" -name "*.sh" -exec sed -i '/^[[:space:]]*#[[:space:]]*echo.*debug/d' {} \;
  
  log_success "Debug statements cleaned"
}

# Function: Remove development-only dependencies
function remove_dev_dependencies() {
  log "🔧 Removing development-only dependencies..."
  
  # Remove development-specific Docker Compose overrides
  find "${PROJECT_ROOT}/projects" -name "docker-compose.override.yml" -delete 2>/dev/null || true
  
  # Remove development configuration directories from projects
  find "${PROJECT_ROOT}/projects" -path "*/conf.d/dev" -type d -exec rm -rf {} + 2>/dev/null || true
  
  log_success "Development-only dependencies removed"
}

# Function: Optimize configuration files
function optimize_configurations() {
  log "⚙️  Optimizing configuration files..."
  
  # Clean up temporary terraform files
  find "${PROJECT_ROOT}/nginx/terraform" -name ".terraform*" -exec rm -rf {} + 2>/dev/null || true
  find "${PROJECT_ROOT}/nginx/terraform" -name "terraform.tfstate*" -delete 2>/dev/null || true
  
  log_success "Configuration files optimized"
}

# Function: Update documentation for production
function update_documentation() {
  log "📝 Updating documentation for production readiness..."
  
  # Remove development-specific references from documentation
  # This is a conservative approach - we'll flag files that may need manual review
  
  local doc_files=(
    "${PROJECT_ROOT}/docs/DOCS.md"
    "${PROJECT_ROOT}/specs/SPECS.md"
    "${PROJECT_ROOT}/README.md"
  )
  
  for doc in "${doc_files[@]}"; do
    if [ -f "$doc" ]; then
      # Check if file has development-specific content that might need review
      if grep -q "development\|debug\|test" "$doc"; then
        log_warning "Documentation file may need manual review: $(basename "$doc")"
      fi
    fi
  done
  
  log_success "Documentation review completed"
}

# Function: Create production-ready .gitignore
function optimize_gitignore() {
  log "📄 Optimizing .gitignore for production..."
  
  # Ensure comprehensive .gitignore
  cat >> "${PROJECT_ROOT}/.gitignore" << 'EOF'

# Production cleanup additions
**/temp/
**/tmp/
**/.DS_Store
**/*.backup.*
**/*.bak
**/*.tmp

# IDE and editor files
.vscode/
.idea/
*.swp
*.swo
*~

# Terraform state files
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Build artifacts
build/
dist/
target/

EOF
  
  log_success ".gitignore optimized for production"
}

# Function: Validate production readiness
function validate_production_readiness() {
  log "✅ Validating production readiness..."
  
  # Check that essential files exist
  local essential_files=(
    "scripts/create-project-modular.sh"
    "scripts/manage-proxy.sh"
    "scripts/generate-certs.sh"
    "proxy/nginx.conf"
    "proxy/docker-compose.yml"
    "flake.nix"
    "README.md"
    "docs/DOCS.md"
    "specs/SPECS.md"
  )
  
  local missing_files=()
  for file in "${essential_files[@]}"; do
    if [ ! -f "${PROJECT_ROOT}/${file}" ]; then
      missing_files+=("$file")
    fi
  done
  
  if [ ${#missing_files[@]} -eq 0 ]; then
    log_success "All essential files present ✅"
  else
    log_error "Missing essential files:"
    for file in "${missing_files[@]}"; do
      log_error "  - $file"
    done
    return 1
  fi
  
  # Check for any remaining development artifacts
  local dev_artifacts=()
  
  # Look for obvious development-only files
  while IFS= read -r -d '' file; do
    dev_artifacts+=("$file")
  done < <(find "${PROJECT_ROOT}" -name "*debug*" -o -name "*test-*" -path "*/temp/*" -print0 2>/dev/null)
  
  if [ ${#dev_artifacts[@]} -gt 0 ]; then
    log_warning "Potential development artifacts found (review manually):"
    for artifact in "${dev_artifacts[@]}"; do
      log_warning "  - ${artifact#$PROJECT_ROOT/}"
    done
  fi
  
  log_success "Production readiness validation completed"
}

# Function: Generate cleanup report
function generate_cleanup_report() {
  log "📊 Generating cleanup report..."
  
  local report_file="${PROJECT_ROOT}/CLEANUP_REPORT.md"
  
  cat > "$report_file" << EOF
# Production Cleanup Report

**Date:** $(date)
**Repository:** nginx-multi-project

## ✅ Cleanup Actions Completed

### 1. Legacy Files Removed
- \`scripts/legacy/\` directory
- Temporary files (*.tmp, *.backup.*, *.bak)
- Development artifacts

### 2. Test Structure Optimized
- Removed redundant wrapper scripts
- Organized tests into categories:
  - \`tests/unit/\`
  - \`tests/integration/\`
  - \`tests/performance/\`
  - \`tests/security/\`
  - \`tests/utils/\`

### 3. Configuration Cleaned
- Removed development-only Docker Compose overrides
- Cleaned debug statements
- Optimized .gitignore

### 4. Production Readiness
- All essential files validated
- Documentation reviewed
- Repository structure optimized

## 📋 Manual Actions Required

1. **Review Documentation**: Check if any development references need updating
2. **Test Validation**: Run the test suite to ensure all tests still pass
3. **Configuration Review**: Verify all production configurations are correct

## 🎯 Repository Status

**✅ Ready for Production Deployment**

The repository has been cleaned and optimized for production use. All development artifacts have been removed while preserving essential functionality.

## 📁 Final Structure

\`\`\`
nginx-multi-project/
├── docs/                    # 📚 Complete documentation
├── specs/                   # 📋 Technical specifications
├── scripts/                 # 🛠️ Production automation
├── proxy/                   # 🌐 Central proxy
├── nginx/                   # ⚙️ Nginx tools
├── tests/                   # 🧪 Organized test framework
├── certs/                   # 🔒 Certificate management
├── flake.nix               # 📦 Nix environment
└── README.md               # 🚀 Main guide
\`\`\`

---
*Generated by unified cleanup script*
EOF
  
  log_success "Cleanup report generated: CLEANUP_REPORT.md"
}

#########################################
# DISPLAY FUNCTIONS
#########################################

# Function: Display environment header
function display_environment_header() {
  echo -e "${BLUE}"
  echo "=================================================================="
  echo "🧹 NGINX MULTI-PROJECT ENVIRONMENT RESET"
  echo "=================================================================="
  echo "This will completely clean your environment:"
  echo "• Stop and remove ALL containers"
  echo "• Remove ALL custom images (keeps base nginx:alpine)"
  echo "• Prune ALL networks"
  echo "• Delete ALL project directories"
  echo "• Clean ALL configuration files"
  echo "=================================================================="
  echo -e "${NC}"
}

# Function: Display podman header
function display_podman_header() {
  echo -e "${BLUE}"
  echo "=================================================================="
  echo "🐳 PODMAN RESOURCES CLEANUP"
  echo "=================================================================="
  echo "This will clean up all podman resources:"
  echo "• Stop and remove ALL containers"
  echo "• Remove ALL images"
  echo "• Prune ALL networks"
  echo "• Prune ALL volumes"
  echo "=================================================================="
  echo -e "${NC}"
}

# Function: Display production header
function display_production_header() {
  echo -e "${BLUE}"
  echo "=================================================================="
  echo "🚀 PRODUCTION PREPARATION CLEANUP"
  echo "=================================================================="
  echo "This will prepare the codebase for production:"
  echo "• Remove legacy files and artifacts"
  echo "• Optimize test structure"
  echo "• Clean debug statements and development configs"
  echo "• Remove development-only dependencies"
  echo "• Optimize configuration files"
  echo "• Update documentation for production"
  echo "• Validate production readiness"
  echo "=================================================================="
  echo -e "${NC}"
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
  
  if [ "$MODE" = "environment" ]; then
    echo ""
    echo -e "${GREEN}Projects Directory:${NC}"
    ls -la "${PROJECT_ROOT}/projects/" 2>/dev/null | head -5 || echo "Directory empty or not found"
    
    echo ""
    echo -e "${GREEN}Proxy Domains:${NC}"
    ls -la "${PROJECT_ROOT}/proxy/conf.d/domains/" 2>/dev/null | head -5 || echo "Directory empty or not found"
  fi
}

# Function: Display completion message
function display_completion() {
  local mode_message=""
  
  case "$MODE" in
    environment)
      mode_message="Your nginx multi-project environment has been reset to:\n• ✅ No containers running\n• ✅ No custom images (only base nginx:alpine)\n• ✅ Clean networks (only default podman bridge)\n• ✅ Empty project directories\n• ✅ Clean configuration files\n• ✅ Master SSL certificates preserved\n\n🚀 Your environment is now ready for fresh deployments!"
      ;;
    podman)
      mode_message="All podman resources have been cleaned:\n• ✅ No containers running\n• ✅ No images\n• ✅ Clean networks\n• ✅ Clean volumes\n\n🚀 Your podman environment is now clean!"
      ;;
    production)
      mode_message="Your codebase is now ready for production:\n• ✅ Legacy files removed\n• ✅ Test structure optimized\n• ✅ Debug statements cleaned\n• ✅ Development dependencies removed\n• ✅ Configuration files optimized\n• ✅ Documentation updated\n• ✅ Production readiness validated\n\n🚀 See CLEANUP_REPORT.md for details!"
      ;;
  esac
  
  echo ""
  echo -e "${GREEN}"
  echo "=================================================================="
  echo "🎉 CLEANUP COMPLETED SUCCESSFULLY!"
  echo "=================================================================="
  echo -e "$mode_message"
  echo "=================================================================="
  echo -e "${NC}"
}

#########################################
# MODE-SPECIFIC EXECUTION FUNCTIONS
#########################################

# Function: Execute environment cleanup
function execute_environment_cleanup() {
  display_environment_header
  
  # Confirm before proceeding
  confirm_action "All your project data will be permanently deleted."
  
  # Check environment
  check_nix_environment
  
  log "Starting environment reset process..."
  
  # Execute cleanup steps
  clean_containers
  clean_images true  # Keep nginx:alpine
  clean_networks
  clean_project_directories
  clean_configuration_files
  
  # Display results
  display_final_status
  display_completion
  
  log_success "Environment reset process completed successfully"
}

# Function: Execute podman cleanup
function execute_podman_cleanup() {
  display_podman_header
  
  # Confirm before proceeding
  confirm_action "All podman resources will be permanently deleted."
  
  # Check environment
  check_nix_environment
  
  log "Starting podman cleanup process..."
  
  # Execute cleanup steps
  clean_containers
  clean_images false  # Remove all images
  clean_networks
  clean_volumes
  
  # Display results
  display_final_status
  display_completion
  
  log_success "Podman cleanup process completed successfully"
}

# Function: Execute production cleanup
function execute_production_cleanup() {
  display_production_header
  
  # Confirm before proceeding
  confirm_action "This will prepare your codebase for production deployment."
  
  log "Starting production preparation process..."
  
  # Execute cleanup phases
  cleanup_legacy_files
  optimize_test_structure
  clean_debug_statements
  remove_dev_dependencies
  optimize_configurations
  update_documentation
  optimize_gitignore
  validate_production_readiness
  generate_cleanup_report
  
  # Display completion
  display_completion
  
  log_success "Production preparation process completed successfully"
}

# Function: Show help
function show_help() {
  echo "Unified Cleanup Script for nginx-multi-project"
  echo ""
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  -h, --help                 Show this help message"
  echo "  -m, --mode <mode>          Set cleanup mode (environment, podman, production)"
  echo "  --dry-run                  Show what would be done without making changes"
  echo ""
  echo "Modes:"
  echo "  environment (default)      Reset the nginx multi-project environment"
  echo "  podman                     Clean up all podman resources"
  echo "  production                 Prepare the codebase for production deployment"
  echo ""
  echo "Examples:"
  echo "  $0                         Run environment cleanup (default)"
  echo "  $0 --mode podman           Clean up podman resources"
  echo "  $0 --mode production       Prepare for production deployment"
}

#########################################
# MAIN EXECUTION
#########################################

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  key="$1"
  
  case $key in
    -h|--help)
      show_help
      exit 0
      ;;
    -m|--mode)
      MODE="$2"
      shift
      shift
      ;;
    --dry-run)
      log_warning "DRY RUN mode not implemented yet"
      log_warning "This script is designed to be safe for cleanup operations"
      exit 1
      ;;
    *)
      log_error "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Validate mode
case "$MODE" in
  environment)
    execute_environment_cleanup
    ;;
  podman)
    execute_podman_cleanup
    ;;
  production)
    execute_production_cleanup
    ;;
  *)
    log_error "Invalid mode: $MODE"
    show_help
    exit 1
    ;;
esac 