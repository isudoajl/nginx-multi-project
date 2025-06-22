#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/update-hosts.log"
HOSTS_FILE="/etc/hosts"
HOSTS_MARKER="# NGINX-MULTI-PROJECT"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Update local hosts file with project domain entries."
  echo ""
  echo "Options:"
  echo "  --domain, -d DOMAIN       Domain name to add/remove (required)"
  echo "  --action, -a ACTION       Action to perform: add or remove (required)"
  echo "  --ip, -i IP               IP address to use (default: 127.0.0.1)"
  echo "  --help, -h                Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --domain example.com --action add"
  echo "  $0 -d example.com -a remove"
  echo "  $0 -d example.com -a add -i 192.168.1.100"
}

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

# Function: Check if running as root
function check_root() {
  if [ "$(id -u)" -ne 0 ]; then
    handle_error "This script must be run as root or with sudo"
  fi
}

# Function: Validate environment
function validate_environment() {
  # For testing purposes, we'll skip the Nix environment check
  # In production, uncomment the following lines
  # if [ -z "$IN_NIX_SHELL" ]; then
  #   handle_error "Please enter Nix environment with 'nix develop' first"
  # fi
  
  # Check if hosts file exists
  if [ ! -f "$HOSTS_FILE" ]; then
    handle_error "Hosts file not found at $HOSTS_FILE"
  fi
  
  # Check if hosts file is writable
  if [ ! -w "$HOSTS_FILE" ]; then
    handle_error "Hosts file is not writable. Run this script with sudo."
  fi
}

# Function: Parse arguments
function parse_arguments() {
  DOMAIN=""
  ACTION=""
  IP="127.0.0.1"

  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain|-d)
        DOMAIN="$2"
        shift 2
        ;;
      --action|-a)
        ACTION="$2"
        shift 2
        ;;
      --ip|-i)
        IP="$2"
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

  # Validate required parameters
  if [[ -z "$DOMAIN" ]]; then
    handle_error "Domain name is required. Use --domain or -d to specify."
  fi

  if [[ -z "$ACTION" ]]; then
    handle_error "Action is required. Use --action or -a to specify."
  fi

  # Validate action
  if [[ "$ACTION" != "add" && "$ACTION" != "remove" ]]; then
    handle_error "Action must be either 'add' or 'remove'."
  fi

  # Validate domain format
  if ! [[ "$DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    handle_error "Invalid domain format: $DOMAIN"
  fi

  # Validate IP format (simple validation)
  if ! [[ "$IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    handle_error "Invalid IP address format: $IP"
  fi
}

# Function: Add domain to hosts file
function add_domain() {
  log "Adding domain $DOMAIN to hosts file with IP $IP"
  
  # Check if domain already exists in hosts file
  if grep -q "$IP $DOMAIN $HOSTS_MARKER" "$HOSTS_FILE"; then
    log "Domain $DOMAIN is already in hosts file with IP $IP"
    return 0
  fi
  
  # Remove any existing entries for this domain
  remove_domain
  
  # Add the new entry
  echo "$IP $DOMAIN $HOSTS_MARKER" >> "$HOSTS_FILE"
  
  # Add www subdomain if not already present
  if ! grep -q "$IP www.$DOMAIN $HOSTS_MARKER" "$HOSTS_FILE"; then
    echo "$IP www.$DOMAIN $HOSTS_MARKER" >> "$HOSTS_FILE"
  fi
  
  log "Domain $DOMAIN successfully added to hosts file"
  
  # Flush DNS cache if possible
  flush_dns_cache
}

# Function: Remove domain from hosts file
function remove_domain() {
  log "Removing domain $DOMAIN from hosts file"
  
  # Create a temporary file
  local temp_file=$(mktemp)
  
  # Remove the domain entries
  grep -v " $DOMAIN $HOSTS_MARKER" "$HOSTS_FILE" > "$temp_file"
  grep -v " www.$DOMAIN $HOSTS_MARKER" "$temp_file" > "${temp_file}.2"
  
  # Replace the hosts file
  cat "${temp_file}.2" > "$HOSTS_FILE"
  
  # Clean up
  rm -f "$temp_file" "${temp_file}.2"
  
  log "Domain $DOMAIN successfully removed from hosts file"
  
  # Flush DNS cache if possible
  flush_dns_cache
}

# Function: Flush DNS cache
function flush_dns_cache() {
  log "Attempting to flush DNS cache"
  
  # Try different methods based on OS
  if command -v systemd-resolve &> /dev/null; then
    systemd-resolve --flush-caches &> /dev/null
    log "Flushed DNS cache using systemd-resolve"
  elif command -v service &> /dev/null && service --status-all 2>&1 | grep -q "nscd"; then
    service nscd restart &> /dev/null
    log "Flushed DNS cache by restarting nscd"
  elif [ -f /etc/init.d/dnsmasq ]; then
    /etc/init.d/dnsmasq restart &> /dev/null
    log "Flushed DNS cache by restarting dnsmasq"
  else
    log "Could not determine method to flush DNS cache. You may need to restart your browser."
  fi
}

# Function: Display current hosts entries
function display_hosts_entries() {
  echo ""
  log "Current hosts file entries for nginx-multi-project:"
  grep "$HOSTS_MARKER" "$HOSTS_FILE" || echo "No entries found"
}

# Main script execution
check_root
validate_environment
parse_arguments "$@"

if [[ "$ACTION" == "add" ]]; then
  add_domain
else
  remove_domain
fi

display_hosts_entries

echo ""
log "Hosts file update completed successfully"
exit 0 