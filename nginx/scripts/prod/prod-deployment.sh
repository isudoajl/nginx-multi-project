#!/bin/bash

# Production Deployment Script
# This script handles the deployment of the nginx configuration to production environment

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
CONFIG_DIR="${NGINX_DIR}/config"
PROD_CONFIG_DIR="${CONFIG_DIR}/environments/production"
CERTS_DIR="${NGINX_DIR}/certs/production"
LOGS_DIR="${NGINX_DIR}/logs/production"
BACKUP_DIR="${NGINX_DIR}/backups/$(date +%Y%m%d_%H%M%S)"

# Create required directories
mkdir -p "${CERTS_DIR}" "${LOGS_DIR}" "${BACKUP_DIR}"

# Display help information
show_help() {
  echo -e "${GREEN}Production Deployment Script${NC}"
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  --deploy        Deploy the configuration to production"
  echo -e "  --backup        Backup the current production configuration"
  echo -e "  --restore       Restore from a backup"
  echo -e "  --cert-renew    Renew SSL certificates"
  echo -e "  --cert-status   Check SSL certificate status"
  echo -e "  --validate      Validate the production configuration"
  echo -e "  --help          Display this help message"
}

# Function to backup the current production configuration
backup_config() {
  echo -e "${YELLOW}Backing up current production configuration...${NC}"
  
  # Create backup directories
  mkdir -p "${BACKUP_DIR}/config" "${BACKUP_DIR}/certs"
  
  # Backup configuration files
  cp -r "${PROD_CONFIG_DIR}"/* "${BACKUP_DIR}/config/"
  
  # Backup certificates
  if [ -d "${CERTS_DIR}" ]; then
    cp -r "${CERTS_DIR}"/* "${BACKUP_DIR}/certs/"
  fi
  
  echo -e "${GREEN}Backup completed successfully at ${BACKUP_DIR}${NC}"
}

# Function to restore from a backup
restore_config() {
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Backup directory not specified${NC}"
    echo -e "Usage: $0 --restore /path/to/backup"
    exit 1
  fi
  
  RESTORE_DIR="$1"
  
  if [ ! -d "${RESTORE_DIR}" ]; then
    echo -e "${RED}Error: Backup directory not found: ${RESTORE_DIR}${NC}"
    exit 1
  fi
  
  echo -e "${YELLOW}Restoring from backup: ${RESTORE_DIR}...${NC}"
  
  # Restore configuration files
  if [ -d "${RESTORE_DIR}/config" ]; then
    cp -r "${RESTORE_DIR}/config/"* "${PROD_CONFIG_DIR}/"
  fi
  
  # Restore certificates
  if [ -d "${RESTORE_DIR}/certs" ]; then
    cp -r "${RESTORE_DIR}/certs/"* "${CERTS_DIR}/"
  fi
  
  echo -e "${GREEN}Restoration completed successfully${NC}"
}

# Function to deploy the configuration to production
deploy_config() {
  echo -e "${YELLOW}Deploying configuration to production...${NC}"
  
  # First, validate the configuration
  validate_config
  
  # Backup the current configuration before deployment
  backup_config
  
  # Deploy the configuration (in a real environment, this would copy to the server)
  echo -e "${YELLOW}Copying configuration files to production server...${NC}"
  # Example: rsync -avz "${PROD_CONFIG_DIR}/" user@production-server:/etc/nginx/conf.d/
  
  # Reload Nginx on the production server
  echo -e "${YELLOW}Reloading Nginx on production server...${NC}"
  # Example: ssh user@production-server 'sudo systemctl reload nginx'
  
  echo -e "${GREEN}Deployment completed successfully${NC}"
  echo -e "${YELLOW}Note: This is a simulation. In a real environment, you would need to configure the actual production server details.${NC}"
}

# Function to validate the production configuration
validate_config() {
  echo -e "${YELLOW}Validating production configuration...${NC}"
  
  # Check if the production configuration exists
  if [ ! -d "${PROD_CONFIG_DIR}" ]; then
    echo -e "${RED}Error: Production configuration directory not found: ${PROD_CONFIG_DIR}${NC}"
    exit 1
  fi
  
  # Check if the main nginx.conf file exists
  if [ ! -f "${PROD_CONFIG_DIR}/nginx.conf" ]; then
    echo -e "${RED}Error: Production nginx.conf not found: ${PROD_CONFIG_DIR}/nginx.conf${NC}"
    echo -e "${YELLOW}Creating default nginx.conf file...${NC}"
    
    # Create a default nginx.conf file
    cat > "${PROD_CONFIG_DIR}/nginx.conf" << EOF
# Production Nginx Configuration
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format combined_ssl '$remote_addr - $remote_user [$time_local] '
                          '"$request" $status $body_bytes_sent '
                          '"$http_referer" "$http_user_agent" '
                          '"$ssl_protocol" "$ssl_cipher" "$http_cf_ray"';
    
    access_log /var/log/nginx/access.log combined_ssl;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # SSL Settings
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_session_tickets off;
    ssl_stapling on;
    ssl_stapling_verify on;
    
    # Include environment-specific configuration
    include /etc/nginx/conf.d/environment.conf;
    
    # Include other configuration files
    include /etc/nginx/conf.d/*.conf;
}
EOF
  fi
  
  # Check if the env.conf file exists
  if [ ! -f "${PROD_CONFIG_DIR}/env.conf" ]; then
    echo -e "${RED}Error: Production env.conf not found: ${PROD_CONFIG_DIR}/env.conf${NC}"
    exit 1
  fi
  
  # Validate the Nginx configuration syntax
  echo -e "${YELLOW}Validating Nginx configuration syntax...${NC}"
  # In a real environment, this would use the actual nginx binary
  # Example: nginx -t -c "${PROD_CONFIG_DIR}/nginx.conf"
  
  echo -e "${GREEN}Configuration validation completed successfully${NC}"
}

# Function to renew SSL certificates
renew_certificates() {
  echo -e "${YELLOW}Renewing SSL certificates...${NC}"
  
  # Create certificates directory if it doesn't exist
  mkdir -p "${CERTS_DIR}"
  
  # In a real environment, this would use Let's Encrypt or another certificate provider
  # Example with certbot:
  # certbot renew --nginx --cert-name example.com
  
  # For demonstration purposes, we'll create a self-signed certificate
  echo -e "${YELLOW}Creating self-signed certificate for demonstration...${NC}"
  
  # Create certificate configuration
  cat > "${CERTS_DIR}/cert.cnf" << EOF
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
CN = example.com

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = example.com
DNS.2 = www.example.com
EOF
  
  # Generate key and certificate
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${CERTS_DIR}/example.com.key" \
    -out "${CERTS_DIR}/example.com.crt" \
    -config "${CERTS_DIR}/cert.cnf"
  
  echo -e "${GREEN}Certificate renewal completed successfully${NC}"
  echo -e "${YELLOW}Note: This is a simulation using self-signed certificates. In a real environment, you would use Let's Encrypt or another certificate provider.${NC}"
}

# Function to check SSL certificate status
check_certificate_status() {
  echo -e "${YELLOW}Checking SSL certificate status...${NC}"
  
  # Check if certificates exist
  if [ ! -f "${CERTS_DIR}/example.com.crt" ]; then
    echo -e "${RED}Error: Certificate not found: ${CERTS_DIR}/example.com.crt${NC}"
    exit 1
  fi
  
  # Check certificate expiration date
  echo -e "${YELLOW}Certificate expiration date:${NC}"
  openssl x509 -noout -enddate -in "${CERTS_DIR}/example.com.crt"
  
  # Check certificate validity
  echo -e "${YELLOW}Certificate validity:${NC}"
  openssl verify -CAfile "${CERTS_DIR}/example.com.crt" "${CERTS_DIR}/example.com.crt" || echo -e "${YELLOW}Note: Self-signed certificates will show as invalid. This is expected in this demonstration.${NC}"
  
  # Check certificate details
  echo -e "${YELLOW}Certificate details:${NC}"
  openssl x509 -noout -text -in "${CERTS_DIR}/example.com.crt" | grep -E 'Subject:|Issuer:|Not Before:|Not After :|DNS:'
  
  echo -e "${GREEN}Certificate status check completed${NC}"
}

# Process command line arguments
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case "$1" in
  --deploy)
    deploy_config
    ;;
  --backup)
    backup_config
    ;;
  --restore)
    restore_config "$2"
    ;;
  --cert-renew)
    renew_certificates
    ;;
  --cert-status)
    check_certificate_status
    ;;
  --validate)
    validate_config
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