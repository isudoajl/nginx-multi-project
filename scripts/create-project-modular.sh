#!/bin/bash

# Main script for project creation
# This script coordinates the execution of all modules

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${PROJECT_ROOT}/scripts/logs/create-project.log"
MODULES_DIR="${SCRIPT_DIR}/create-project/modules"

# Source common functions and utilities
source "${MODULES_DIR}/common.sh"

# Create logs directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

# Log script start
log "Starting project creation process..."

# Source and execute modules in order
source "${MODULES_DIR}/args.sh"
source "${MODULES_DIR}/environment.sh"
source "${MODULES_DIR}/certificate_validation.sh"
source "${MODULES_DIR}/proxy.sh"
source "${MODULES_DIR}/project_structure.sh"
source "${MODULES_DIR}/project_files.sh"
source "${MODULES_DIR}/project_functions.sh"
source "${MODULES_DIR}/build_process.sh"
source "${MODULES_DIR}/deployment.sh"
source "${MODULES_DIR}/verification.sh"

# Parse command line arguments
parse_arguments "$@"

# Validate environment
validate_environment

# Validate SSL certificates
validate_certificates

# Check and setup proxy
check_proxy

# Setup project structure
setup_project_structure

# Generate project files
generate_project_files

# Build project (new step)
build_project

# Configure environment based on type
if [[ "$ENV_TYPE" == "DEV" ]]; then
  configure_dev_environment
else
  configure_pro_environment
fi

# Deploy project
deploy_project

# Verify deployment
verify_deployment

log "Project creation completed successfully!"
exit 0 