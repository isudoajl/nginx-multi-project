#!/bin/bash
#
# Development workflow script for Nginx multi-project environment
# Provides hot reload functionality and development environment setup

set -e

# Establish the project root as an anchor point for all relative paths
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
NGINX_DIR="${PROJECT_ROOT}/nginx"
CONFIG_DIR="${NGINX_DIR}/config"
DEV_ENV_DIR="${CONFIG_DIR}/environments/development"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running in Nix environment
if [ -z "$IN_NIX_SHELL" ]; then
  echo -e "${RED}Error: Please run this script within the Nix environment.${NC}"
  echo -e "${YELLOW}Run 'nix develop' first and then try again.${NC}"
  exit 1
fi

# Function to display usage information
usage() {
  echo -e "${GREEN}Usage:${NC} $0 [options]"
  echo
  echo "Options:"
  echo "  --start         Start the development environment"
  echo "  --stop          Stop the development environment"
  echo "  --reload        Reload the configuration"
  echo "  --watch         Start watching for changes (hot reload)"
  echo "  --setup-dns     Setup local DNS resolution"
  echo "  --setup-certs   Setup local certificate authority and certificates"
  echo "  --help          Display this help message"
  echo
  exit 1
}

# Function to start the development environment
start_dev_env() {
  echo -e "${GREEN}Starting development environment...${NC}"
  
  # Check if nginx configuration is valid
  echo -e "${YELLOW}Checking Nginx configuration...${NC}"
  nginx -t -c "${DEV_ENV_DIR}/nginx.conf" || {
    echo -e "${RED}Nginx configuration test failed.${NC}"
    return 1
  }
  
  # Start nginx with development configuration
  echo -e "${GREEN}Starting Nginx with development configuration...${NC}"
  nginx -c "${DEV_ENV_DIR}/nginx.conf"
  
  echo -e "${GREEN}Development environment started successfully.${NC}"
}

# Function to stop the development environment
stop_dev_env() {
  echo -e "${YELLOW}Stopping development environment...${NC}"
  nginx -s stop || echo -e "${YELLOW}Nginx was not running.${NC}"
  echo -e "${GREEN}Development environment stopped.${NC}"
}

# Function to reload the configuration
reload_config() {
  echo -e "${YELLOW}Reloading Nginx configuration...${NC}"
  
  # Check if nginx configuration is valid
  nginx -t -c "${DEV_ENV_DIR}/nginx.conf" || {
    echo -e "${RED}Nginx configuration test failed. Not reloading.${NC}"
    return 1
  }
  
  # Reload nginx configuration
  nginx -s reload
  echo -e "${GREEN}Configuration reloaded successfully.${NC}"
}

# Function to watch for changes and hot reload
watch_for_changes() {
  echo -e "${GREEN}Starting hot reload watcher...${NC}"
  echo -e "${YELLOW}Watching for changes in ${CONFIG_DIR}...${NC}"
  echo -e "${YELLOW}Press Ctrl+C to stop watching.${NC}"
  
  # Check if inotifywait is available
  if ! command -v inotifywait &> /dev/null; then
    echo -e "${RED}Error: inotifywait not found. Please install inotify-tools.${NC}"
    exit 1
  }
  
  # Watch for changes in configuration files
  while true; do
    inotifywait -r -e modify,create,delete,move "${CONFIG_DIR}"
    echo -e "${YELLOW}Change detected, reloading configuration...${NC}"
    reload_config
  done
}

# Function to setup local DNS resolution
setup_local_dns() {
  echo -e "${GREEN}Setting up local DNS resolution...${NC}"
  
  # Check if dnsmasq is available
  if ! command -v dnsmasq &> /dev/null; then
    echo -e "${RED}Error: dnsmasq not found. Please install dnsmasq.${NC}"
    exit 1
  }
  
  # Create dnsmasq configuration for local development
  local DNSMASQ_CONF="${NGINX_DIR}/scripts/dev/dnsmasq.conf"
  
  echo "# Dnsmasq configuration for local development" > "${DNSMASQ_CONF}"
  echo "address=/local.dev/127.0.0.1" >> "${DNSMASQ_CONF}"
  echo "address=/api.local.dev/127.0.0.1" >> "${DNSMASQ_CONF}"
  echo "address=/admin.local.dev/127.0.0.1" >> "${DNSMASQ_CONF}"
  
  echo -e "${YELLOW}Created dnsmasq configuration at ${DNSMASQ_CONF}${NC}"
  echo -e "${YELLOW}To use this configuration, run:${NC}"
  echo -e "${GREEN}sudo dnsmasq -C ${DNSMASQ_CONF} --no-daemon${NC}"
  
  echo -e "${GREEN}Local DNS resolution setup complete.${NC}"
}

# Function to setup local certificate authority and certificates
setup_local_certs() {
  echo -e "${GREEN}Setting up local certificate authority and certificates...${NC}"
  
  local CERTS_DIR="${NGINX_DIR}/certs"
  mkdir -p "${CERTS_DIR}"
  
  # Create root CA
  echo -e "${YELLOW}Creating root CA...${NC}"
  openssl genrsa -out "${CERTS_DIR}/rootCA.key" 2048
  openssl req -x509 -new -nodes -key "${CERTS_DIR}/rootCA.key" -sha256 -days 1024 -out "${CERTS_DIR}/rootCA.pem" \
    -subj "/C=US/ST=State/L=City/O=Organization/OU=Development/CN=Local Development CA"
  
  # Create server certificate
  echo -e "${YELLOW}Creating server certificate...${NC}"
  
  # Create certificate configuration
  cat > "${CERTS_DIR}/server.cnf" << EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = req_ext

[dn]
C=US
ST=State
L=City
O=Organization
OU=Development
CN=*.local.dev

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = *.local.dev
DNS.2 = local.dev
DNS.3 = *.api.local.dev
DNS.4 = *.admin.local.dev
EOF
  
  # Generate key and certificate signing request
  openssl genrsa -out "${CERTS_DIR}/server.key" 2048
  openssl req -new -key "${CERTS_DIR}/server.key" -out "${CERTS_DIR}/server.csr" -config "${CERTS_DIR}/server.cnf"
  
  # Sign the certificate with our CA
  openssl x509 -req -in "${CERTS_DIR}/server.csr" \
    -CA "${CERTS_DIR}/rootCA.pem" -CAkey "${CERTS_DIR}/rootCA.key" \
    -CAcreateserial -out "${CERTS_DIR}/server.crt" \
    -days 365 -sha256 -extfile "${CERTS_DIR}/server.cnf" -extensions req_ext
  
  echo -e "${GREEN}Certificates created successfully at ${CERTS_DIR}${NC}"
  echo -e "${YELLOW}To trust this CA in your browser, import ${CERTS_DIR}/rootCA.pem${NC}"
}

# Parse command line arguments
if [ $# -eq 0 ]; then
  usage
fi

# Process the arguments
while [ $# -gt 0 ]; do
  case "$1" in
    --start)
      start_dev_env
      ;;
    --stop)
      stop_dev_env
      ;;
    --reload)
      reload_config
      ;;
    --watch)
      watch_for_changes
      ;;
    --setup-dns)
      setup_local_dns
      ;;
    --setup-certs)
      setup_local_certs
      ;;
    --help)
      usage
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      usage
      ;;
  esac
  shift
done

exit 0 