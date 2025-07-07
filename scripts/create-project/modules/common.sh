#!/bin/bash

# Common functions and variables shared across modules

# Global variables
PROJECTS_DIR="${PROJECT_ROOT}/projects"
CERTS_DIR="${PROJECT_ROOT}/certs"
CONTAINER_ENGINE=""

# Create projects directory if it doesn't exist
mkdir -p "${PROJECTS_DIR}"

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  local message="[$timestamp] $1"
  
  # Print to stdout
  echo "$message"
  
  # If LOG_FILE is defined and the directory exists, append to log file
  if [[ -n "${LOG_FILE}" ]]; then
    # Ensure log directory exists
    mkdir -p "$(dirname "${LOG_FILE}")" 2>/dev/null || true
    
    # Append to log file if directory exists
    if [[ -d "$(dirname "${LOG_FILE}")" ]]; then
      echo "$message" >> "${LOG_FILE}" 2>/dev/null || true
    fi
  fi
}

# Function: Handle errors
function handle_error() {
  log "ERROR: $1"
  exit 1
}

# Helper function to check container status
function check_container_status() {
  local container_name="$1"
  if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo "RUNNING"
  elif $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${container_name}$"; then
    echo "STOPPED"
  else
    echo "NOT FOUND"
  fi
} 