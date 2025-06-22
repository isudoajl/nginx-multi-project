#!/bin/bash

# Certificate Rotation Script
# This script handles the automatic rotation of certificates that are about to expire

set -e

# Check if we're in Nix environment
if [ -z "$IN_NIX_SHELL" ]; then
  echo "Please enter Nix environment with 'nix develop' first"
  exit 1
fi

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
NGINX_DIR="${PROJECT_ROOT}/nginx"
CERTS_DIR="${NGINX_DIR}/certs/production"
CONFIG_DIR="${NGINX_DIR}/config/cert-manager"
LOGS_DIR="${NGINX_DIR}/logs/cert-manager"
BACKUP_DIR="${NGINX_DIR}/certs/backup"

# Create required directories
mkdir -p "${CERTS_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}" "${BACKUP_DIR}"

# Define log file
LOG_FILE="${LOGS_DIR}/cert-rotation-$(date +%Y%m%d-%H%M%S).log"

# Function to log messages
log_message() {
  local level="$1"
  local message="$2"
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  
  echo -e "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Function to log an error and exit
log_error_and_exit() {
  local message="$1"
  log_message "ERROR" "${RED}${message}${NC}"
  exit 1
}

# Function to check certificate expiration
check_certificate_expiration() {
  local cert_file="$1"
  local threshold_days="$2"
  
  if [ ! -f "${cert_file}" ]; then
    log_error_and_exit "Certificate file does not exist: ${cert_file}"
  fi
  
  # Check if certificate is valid
  if ! openssl x509 -noout -checkend 0 -in "${cert_file}" &>/dev/null; then
    log_message "ERROR" "${RED}Certificate has already expired: ${cert_file}${NC}"
    return 0  # Return true (0) to indicate rotation is needed
  fi
  
  # Check if certificate will expire within threshold days
  if ! openssl x509 -noout -checkend $(( threshold_days * 86400 )) -in "${cert_file}" &>/dev/null; then
    log_message "WARNING" "${YELLOW}Certificate will expire within ${threshold_days} days: ${cert_file}${NC}"
    return 0  # Return true (0) to indicate rotation is needed
  fi
  
  # Certificate is valid and not expiring soon
  return 1  # Return false (1) to indicate rotation is not needed
}

# Function to create a backup of certificates
backup_certificates() {
  local domain="$1"
  local timestamp=$(date +"%Y%m%d-%H%M%S")
  local backup_path="${BACKUP_DIR}/${domain}-${timestamp}"
  
  log_message "INFO" "Creating backup of certificates for ${domain}"
  
  mkdir -p "${backup_path}"
  
  if [ -f "${CERTS_DIR}/${domain}/${domain}.crt" ]; then
    cp "${CERTS_DIR}/${domain}/${domain}.crt" "${backup_path}/"
  fi
  
  if [ -f "${CERTS_DIR}/${domain}/${domain}.key" ]; then
    cp "${CERTS_DIR}/${domain}/${domain}.key" "${backup_path}/"
  fi
  
  log_message "INFO" "Backup created at ${backup_path}"
}

# Function to rotate certificate
rotate_certificate() {
  local domain="$1"
  local cert_file="${CERTS_DIR}/${domain}/${domain}.crt"
  local key_file="${CERTS_DIR}/${domain}/${domain}.key"
  local temp_dir="${CERTS_DIR}/${domain}_temp"
  
  log_message "INFO" "Starting certificate rotation for ${domain}"
  
  # Create temporary directory
  mkdir -p "${temp_dir}"
  
  # Create certificate configuration
  cat > "${temp_dir}/cert.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C = US
ST = State
L = City
O = Organization
OU = OrganizationUnit
CN = ${domain}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = www.${domain}
EOF
  
  # Generate new certificate
  log_message "INFO" "Generating new certificate for ${domain}"
  if ! openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${temp_dir}/${domain}.key" \
    -out "${temp_dir}/${domain}.crt" \
    -config "${temp_dir}/cert.cnf" &>/dev/null; then
    log_error_and_exit "Failed to generate new certificate for ${domain}"
  fi
  
  # Validate new certificate
  log_message "INFO" "Validating new certificate for ${domain}"
  if ! openssl x509 -noout -checkend 0 -in "${temp_dir}/${domain}.crt" &>/dev/null; then
    log_error_and_exit "New certificate validation failed for ${domain}"
  fi
  
  # Backup existing certificates
  backup_certificates "${domain}"
  
  # Atomic update of certificates
  log_message "INFO" "Performing atomic update of certificates for ${domain}"
  
  # First update the key and certificate files
  if [ -f "${temp_dir}/${domain}.key" ] && [ -f "${temp_dir}/${domain}.crt" ]; then
    cp "${temp_dir}/${domain}.key" "${CERTS_DIR}/${domain}/${domain}.key.new"
    cp "${temp_dir}/${domain}.crt" "${CERTS_DIR}/${domain}/${domain}.crt.new"
    
    # Use atomic rename to replace the files
    mv -f "${CERTS_DIR}/${domain}/${domain}.key.new" "${CERTS_DIR}/${domain}/${domain}.key"
    mv -f "${CERTS_DIR}/${domain}/${domain}.crt.new" "${CERTS_DIR}/${domain}/${domain}.crt"
  else
    log_error_and_exit "New certificate files not found for ${domain}"
  fi
  
  # Then update the symlinks atomically
  if [ -f "${CERTS_DIR}/${domain}/${domain}.key" ] && [ -f "${CERTS_DIR}/${domain}/${domain}.crt" ]; then
    # Create temporary symlinks
    ln -sf "${CERTS_DIR}/${domain}/${domain}.key" "${CERTS_DIR}/current.key.new"
    ln -sf "${CERTS_DIR}/${domain}/${domain}.crt" "${CERTS_DIR}/current.crt.new"
    
    # Atomically replace the symlinks
    mv -f "${CERTS_DIR}/current.key.new" "${CERTS_DIR}/current.key"
    mv -f "${CERTS_DIR}/current.crt.new" "${CERTS_DIR}/current.crt"
  else
    log_error_and_exit "Certificate files not found after rotation for ${domain}"
  fi
  
  # Clean up temporary directory
  rm -rf "${temp_dir}"
  
  log_message "SUCCESS" "${GREEN}Certificate rotation completed successfully for ${domain}${NC}"
  return 0
}

# Function to reload Nginx
reload_nginx() {
  log_message "INFO" "Reloading Nginx configuration"
  
  # In a real environment, this would reload Nginx
  # systemctl reload nginx
  
  # For demonstration purposes, we'll just print a message
  log_message "INFO" "Nginx configuration reloaded"
}

# Main function to rotate certificates
rotate_certificates() {
  local threshold_days="${1:-30}"  # Default to 30 days if not specified
  local rotation_needed=false
  
  log_message "INFO" "Checking certificates with expiry threshold of ${threshold_days} days"
  
  # Find all certificate files
  find "${CERTS_DIR}" -name "*.crt" | while read cert_file; do
    # Skip if it's a symlink
    if [ -L "${cert_file}" ]; then
      continue
    fi
    
    domain=$(basename "$(dirname "${cert_file}")")
    
    # Check if certificate needs rotation
    if check_certificate_expiration "${cert_file}" "${threshold_days}"; then
      log_message "INFO" "Certificate for ${domain} needs rotation"
      
      # Rotate certificate
      if rotate_certificate "${domain}"; then
        rotation_needed=true
      fi
    else
      log_message "INFO" "${GREEN}Certificate for ${domain} is still valid${NC}"
    fi
  done
  
  # Reload Nginx if any certificates were rotated
  if [ "${rotation_needed}" = true ]; then
    reload_nginx
  fi
  
  log_message "INFO" "Certificate rotation check completed"
}

# Display help information
show_help() {
  echo -e "${GREEN}Certificate Rotation Script${NC}"
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  --rotate [days]  Check and rotate certificates expiring within [days] days (default: 30)"
  echo -e "  --help           Display this help message"
}

# Process command line arguments
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case "$1" in
  --rotate)
    threshold_days="${2:-30}"  # Use provided value or default to 30
    rotate_certificates "${threshold_days}"
    ;;
  --help)
    show_help
    ;;
  *)
    echo -e "${RED}Error: Unknown option: $1${NC}"
    show_help
    exit 1
    ;;
esac

exit 0 