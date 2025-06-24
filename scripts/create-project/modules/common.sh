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
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
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