#!/bin/bash

# Certificate Management Script
# This script handles the acquisition, renewal, and validation of SSL certificates

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

# Create required directories
mkdir -p "${CERTS_DIR}" "${CONFIG_DIR}" "${LOGS_DIR}"

# Display help information
show_help() {
  echo -e "${GREEN}Certificate Management Script${NC}"
  echo -e "Usage: $0 [options]"
  echo -e "Options:"
  echo -e "  --acquire       Acquire new certificates"
  echo -e "  --renew         Renew existing certificates"
  echo -e "  --validate      Validate certificates"
  echo -e "  --status        Show certificate status"
  echo -e "  --setup-cron    Setup automatic renewal cron job"
  echo -e "  --rotate [days] Check and rotate certificates expiring within [days] days (default: 30)"
  echo -e "  --help          Display this help message"
}

# Function to acquire new certificates
acquire_certificates() {
  echo -e "${YELLOW}Acquiring new certificates...${NC}"
  
  # Check if domain is provided
  if [ -z "$1" ]; then
    echo -e "${RED}Error: Domain not specified${NC}"
    echo -e "Usage: $0 --acquire example.com"
    exit 1
  fi
  
  DOMAIN="$1"
  
  # Create certificates directory if it doesn't exist
  mkdir -p "${CERTS_DIR}/${DOMAIN}"
  
  # In a real environment, this would use Let's Encrypt or another certificate provider
  # Example with certbot:
  # certbot certonly --nginx -d ${DOMAIN} -d www.${DOMAIN} --cert-name ${DOMAIN} \
  #   --config-dir ${CONFIG_DIR} --logs-dir ${LOGS_DIR} --work-dir ${CERTS_DIR}/${DOMAIN}
  
  # For demonstration purposes, we'll create a self-signed certificate
  echo -e "${YELLOW}Creating self-signed certificate for ${DOMAIN}...${NC}"
  
  # Create certificate configuration
  cat > "${CERTS_DIR}/${DOMAIN}/cert.cnf" << EOF
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
CN = ${DOMAIN}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = www.${DOMAIN}
EOF
  
  # Generate key and certificate
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.key" \
    -out "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" \
    -config "${CERTS_DIR}/${DOMAIN}/cert.cnf"
  
  # Create symlinks to the latest certificates
  ln -sf "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.key" "${CERTS_DIR}/current.key"
  ln -sf "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" "${CERTS_DIR}/current.crt"
  
  echo -e "${GREEN}Certificate acquisition completed successfully${NC}"
  echo -e "${YELLOW}Note: This is a simulation using self-signed certificates. In a real environment, you would use Let's Encrypt or another certificate provider.${NC}"
}

# Function to renew certificates
renew_certificates() {
  echo -e "${YELLOW}Renewing certificates...${NC}"
  
  # In a real environment, this would use Let's Encrypt or another certificate provider
  # Example with certbot:
  # certbot renew --nginx --config-dir ${CONFIG_DIR} --logs-dir ${LOGS_DIR}
  
  # For demonstration purposes, we'll check for certificates that are about to expire
  EXPIRY_THRESHOLD=30  # Days
  
  # Find all certificate files
  find "${CERTS_DIR}" -name "*.crt" | while read cert_file; do
    domain=$(basename "$(dirname "${cert_file}")")
    
    # Skip if it's a symlink
    if [ -L "${cert_file}" ]; then
      continue
    fi
    
    # Check expiration date
    expiry_date=$(openssl x509 -noout -enddate -in "${cert_file}" | cut -d= -f2)
    expiry_epoch=$(date -d "${expiry_date}" +%s)
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    echo -e "${YELLOW}Certificate for ${domain}: ${days_left} days until expiration${NC}"
    
    # Renew if expiring soon
    if [ "${days_left}" -lt "${EXPIRY_THRESHOLD}" ]; then
      echo -e "${YELLOW}Certificate for ${domain} is expiring soon. Renewing...${NC}"
      acquire_certificates "${domain}"
    fi
  done
  
  echo -e "${GREEN}Certificate renewal check completed${NC}"
}

# Function to validate certificates
validate_certificates() {
  echo -e "${YELLOW}Validating certificates...${NC}"
  
  # Find all certificate files
  find "${CERTS_DIR}" -name "*.crt" | while read cert_file; do
    # Skip if it's a symlink
    if [ -L "${cert_file}" ]; then
      continue
    fi
    
    domain=$(basename "$(dirname "${cert_file}")")
    echo -e "${YELLOW}Validating certificate for ${domain}...${NC}"
    
    # Check certificate validity
    if openssl x509 -noout -checkend 0 -in "${cert_file}"; then
      echo -e "${GREEN}✓ Certificate for ${domain} is valid${NC}"
    else
      echo -e "${RED}✗ Certificate for ${domain} has expired${NC}"
    fi
    
    # Check certificate chain (in a real environment)
    # Example: openssl verify -CAfile /path/to/ca/chain.pem "${cert_file}"
  done
  
  echo -e "${GREEN}Certificate validation completed${NC}"
}

# Function to show certificate status
show_certificate_status() {
  echo -e "${YELLOW}Certificate Status:${NC}"
  
  # Find all certificate files
  find "${CERTS_DIR}" -name "*.crt" | while read cert_file; do
    # Skip if it's a symlink
    if [ -L "${cert_file}" ]; then
      continue
    fi
    
    domain=$(basename "$(dirname "${cert_file}")")
    echo -e "${GREEN}Certificate for ${domain}:${NC}"
    
    # Check expiration date
    expiry_date=$(openssl x509 -noout -enddate -in "${cert_file}" | cut -d= -f2)
    expiry_epoch=$(date -d "${expiry_date}" +%s)
    current_epoch=$(date +%s)
    days_left=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    echo -e "  Expires in: ${days_left} days (${expiry_date})"
    
    # Show certificate details
    subject=$(openssl x509 -noout -subject -in "${cert_file}" | sed 's/subject=//g')
    issuer=$(openssl x509 -noout -issuer -in "${cert_file}" | sed 's/issuer=//g')
    
    echo -e "  Subject: ${subject}"
    echo -e "  Issuer: ${issuer}"
    
    # Check if certificate is self-signed
    if [ "${subject}" = "${issuer}" ]; then
      echo -e "  ${YELLOW}⚠ Self-signed certificate${NC}"
    fi
    
    # Show SANs (Subject Alternative Names)
    echo -e "  SANs: $(openssl x509 -noout -text -in "${cert_file}" | grep -A1 "Subject Alternative Name" | tail -n1 | sed 's/DNS://g; s/, /\n       /g')"
    
    echo ""
  done
}

# Function to setup automatic renewal cron job
setup_cron() {
  echo -e "${YELLOW}Setting up automatic renewal cron job...${NC}"
  
  # Create cron script
  CRON_SCRIPT="${NGINX_DIR}/scripts/prod/cert-renewal-cron.sh"
  
  cat > "${CRON_SCRIPT}" << EOF
#!/bin/bash

# Certificate Renewal Cron Script
# This script is meant to be run by cron to automatically renew certificates

# Define paths
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CERT_SCRIPT="\${SCRIPT_DIR}/cert-management.sh"

# Run certificate rotation (which includes renewal)
\${CERT_SCRIPT} --rotate 30

# Reload Nginx if certificates were rotated
if [ \$? -eq 0 ]; then
  # In a real environment, this would reload Nginx
  # systemctl reload nginx
  echo "Certificates rotated successfully"
fi

exit 0
EOF
  
  chmod +x "${CRON_SCRIPT}"
  
  echo -e "${GREEN}Cron script created at ${CRON_SCRIPT}${NC}"
  echo -e "${YELLOW}To install the cron job, run:${NC}"
  echo -e "  crontab -e"
  echo -e "And add the following line:${NC}"
  echo -e "  0 3 * * * ${CRON_SCRIPT} > /var/log/cert-renewal.log 2>&1"
  echo -e "${YELLOW}This will run the renewal script every day at 3:00 AM${NC}"
}

# Process command line arguments
if [ $# -eq 0 ]; then
  show_help
  exit 0
fi

case "$1" in
  --acquire)
    acquire_certificates "$2"
    ;;
  --renew)
    renew_certificates
    ;;
  --validate)
    validate_certificates
    ;;
  --status)
    show_certificate_status
    ;;
  --setup-cron)
    setup_cron
    ;;
  --rotate)
    # Call the certificate rotation script if it exists
    if [ -f "${SCRIPT_DIR}/cert-rotation.sh" ]; then
      threshold_days="${2:-30}"  # Use provided value or default to 30
      "${SCRIPT_DIR}/cert-rotation.sh" --rotate "${threshold_days}"
    else
      echo -e "${RED}Error: Certificate rotation script not found${NC}"
      exit 1
    fi
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