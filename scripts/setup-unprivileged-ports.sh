#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/setup-unprivileged-ports.log"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

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

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Configure the system to allow binding to privileged ports by setting the unprivileged port start value."
  echo ""
  echo "Options:"
  echo "  --port, -p PORT          First unprivileged port (default: 80)"
  echo "  --help, -h               Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --port 80"
  echo "  $0 -p 80"
}

# Function: Parse arguments
function parse_arguments() {
  PORT_START=80
  
  while [[ $# -gt 0 ]]; do
    case $1 in
      --port|-p)
        PORT_START="$2"
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
  
  # Validate port number
  if ! [[ "$PORT_START" =~ ^[0-9]+$ ]] || [ "$PORT_START" -lt 1 ] || [ "$PORT_START" -gt 1023 ]; then
    handle_error "Invalid port number: $PORT_START. Must be between 1 and 1023."
  fi
}

# Function: Check if running as root
function check_root() {
  if [ "$EUID" -ne 0 ]; then
    handle_error "This script must be run as root or with sudo privileges"
  fi
}

# Function: Set unprivileged port start
function set_unprivileged_port_start() {
  log "Setting unprivileged port start to $PORT_START..."
  
  # Set the value for the current session
  echo "$PORT_START" > /proc/sys/net/ipv4/ip_unprivileged_port_start || handle_error "Failed to set unprivileged port start for current session"
  
  # Make the change persistent
  echo "net.ipv4.ip_unprivileged_port_start = $PORT_START" > /etc/sysctl.d/90-unprivileged_port_start.conf || handle_error "Failed to create sysctl configuration file"
  
  # Apply the sysctl settings
  sysctl -p /etc/sysctl.d/90-unprivileged_port_start.conf || handle_error "Failed to apply sysctl settings"
  
  log "Unprivileged port start successfully set to $PORT_START"
  log "Containers can now bind to ports $PORT_START and above without requiring root privileges"
}

# Function: Verify configuration
function verify_configuration() {
  log "Verifying unprivileged port start configuration..."
  
  # Check current value
  local current_value=$(cat /proc/sys/net/ipv4/ip_unprivileged_port_start)
  
  if [ "$current_value" == "$PORT_START" ]; then
    log "✅ Verification successful: unprivileged port start is set to $current_value"
  else
    log "❌ Verification failed: unprivileged port start is set to $current_value, expected $PORT_START"
    handle_error "Configuration verification failed"
  fi
}

# Main script execution
parse_arguments "$@"
check_root
set_unprivileged_port_start
verify_configuration

log "✅ Setup completed successfully"
echo "Unprivileged port start has been set to $PORT_START"
echo "You can now run containers that bind to ports $PORT_START and above without requiring root privileges"
exit 0 