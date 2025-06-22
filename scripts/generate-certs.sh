#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/generate-certs.log"
CERTS_DIR="${SCRIPT_DIR}/../certs"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"
mkdir -p "${CERTS_DIR}"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Generate SSL certificates for development or production environments."
  echo ""
  echo "Options:"
  echo "  --domain, -d DOMAIN       Domain name for the certificate (required)"
  echo "  --output, -o DIR          Output directory for certificates (required)"
  echo "  --env, -e ENV             Environment type: DEV or PRO (default: DEV)"
  echo "  --days, -days DAYS        Validity period in days (default: 365)"
  echo "  --help, -h                Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --domain example.com --output ./certs --env DEV"
  echo "  $0 -d example.com -o ./certs -e PRO"
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

# Function: Validate environment
function validate_environment() {
  # Check if openssl is installed
  if ! command -v openssl &> /dev/null; then
    handle_error "OpenSSL is not installed. Please install it and try again."
  fi
  
  # For testing purposes, we'll skip the Nix environment check
  # In production, uncomment the following lines
  # if [ -z "$IN_NIX_SHELL" ]; then
  #   handle_error "Please enter Nix environment with 'nix develop' first"
  # fi
}

# Function: Parse arguments
function parse_arguments() {
  DOMAIN=""
  OUTPUT_DIR=""
  ENV_TYPE="DEV"
  DAYS=365

  while [[ $# -gt 0 ]]; do
    case $1 in
      --domain|-d)
        DOMAIN="$2"
        shift 2
        ;;
      --output|-o)
        OUTPUT_DIR="$2"
        shift 2
        ;;
      --env|-e)
        ENV_TYPE="$2"
        shift 2
        ;;
      --days)
        DAYS="$2"
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

  if [[ -z "$OUTPUT_DIR" ]]; then
    handle_error "Output directory is required. Use --output or -o to specify."
  fi

  # Validate environment type
  if [[ "$ENV_TYPE" != "DEV" && "$ENV_TYPE" != "PRO" ]]; then
    handle_error "Environment type must be either DEV or PRO."
  fi

  # Validate domain format
  if ! [[ "$DOMAIN" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    handle_error "Invalid domain format: $DOMAIN"
  fi

  # Create output directory if it doesn't exist
  mkdir -p "$OUTPUT_DIR" || handle_error "Failed to create output directory: $OUTPUT_DIR"
}

# Function: Generate self-signed certificate
function generate_self_signed() {
  log "Generating self-signed certificate for $DOMAIN (valid for $DAYS days)"
  
  # Create config file for OpenSSL
  local config_file="${OUTPUT_DIR}/openssl.cnf"
  cat > "$config_file" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
x509_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = Organization
OU = Development
CN = ${DOMAIN}

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
DNS.3 = localhost
EOF

  # Set appropriate permissions for config file
  chmod 644 "$config_file" || handle_error "Failed to set permissions on config file"

  # Generate private key and certificate
  local key_file="${OUTPUT_DIR}/cert-key.pem"
  local cert_file="${OUTPUT_DIR}/cert.pem"
  
  openssl req -x509 -nodes -days "$DAYS" -newkey rsa:2048 \
    -keyout "$key_file" -out "$cert_file" \
    -config "$config_file" \
    || handle_error "Failed to generate self-signed certificate"
  
  # Set appropriate permissions
  chmod 600 "$key_file" || handle_error "Failed to set permissions on key file"
  chmod 644 "$cert_file" || handle_error "Failed to set permissions on certificate file"
  
  log "Self-signed certificate generated successfully:"
  log "  - Private key: $key_file"
  log "  - Certificate: $cert_file"
  
  # Display certificate information
  log "Certificate details:"
  openssl x509 -in "$cert_file" -noout -text | grep -E "Subject:|Issuer:|Not Before:|Not After :|DNS:" | sed 's/^/    /'
  
  # Instructions for browser trust
  echo ""
  log "To trust this certificate in your browser:"
  log "  - Import $cert_file into your browser's certificate store"
  log "  - For development, you may need to add an exception in your browser"
}

# Function: Prepare for production certificate
function prepare_production() {
  log "Preparing for production certificate for $DOMAIN"
  
  # Create config file for OpenSSL
  local config_file="${OUTPUT_DIR}/openssl.cnf"
  cat > "$config_file" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C = US
ST = State
L = City
O = Organization
OU = Production
CN = ${DOMAIN}

[v3_req]
subjectAltName = @alt_names
keyUsage = digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

  # Set appropriate permissions for config file
  chmod 644 "$config_file" || handle_error "Failed to set permissions on config file"

  # Generate private key and CSR
  local key_file="${OUTPUT_DIR}/cert-key.pem"
  local csr_file="${OUTPUT_DIR}/cert.csr"
  
  openssl genrsa -out "$key_file" 2048 \
    || handle_error "Failed to generate private key"
  
  openssl req -new -key "$key_file" -out "$csr_file" \
    -config "$config_file" \
    || handle_error "Failed to generate CSR"
  
  # Set appropriate permissions
  chmod 600 "$key_file" || handle_error "Failed to set permissions on key file"
  chmod 644 "$csr_file" || handle_error "Failed to set permissions on CSR file"
  
  log "Certificate Signing Request (CSR) generated successfully:"
  log "  - Private key: $key_file"
  log "  - CSR file: $csr_file"
  
  # Display CSR information
  log "CSR details:"
  openssl req -in "$csr_file" -noout -text | grep -E "Subject:|Subject Alternative Name:" | sed 's/^/    /'
  
  # Instructions for obtaining a real certificate
  echo ""
  log "To obtain a production certificate:"
  log "  1. Submit the CSR ($csr_file) to your certificate authority"
  log "  2. Once you receive the certificate, save it as ${OUTPUT_DIR}/cert.pem"
  log "  3. Keep the private key ($key_file) secure"
  log "  4. Configure your web server to use both files"
}

# Main script execution
validate_environment
parse_arguments "$@"

if [[ "$ENV_TYPE" == "DEV" ]]; then
  generate_self_signed
else
  prepare_production
fi

log "Certificate generation process complete!"
exit 0 