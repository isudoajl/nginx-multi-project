#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/../proxy"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please enter Nix environment with 'nix develop' first${NC}"
    exit 1
  fi
  
  # Check if docker/podman is available
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    echo -e "${RED}Error: docker/podman is not installed or not in PATH${NC}"
    exit 1
  fi
  
  # Check if openssl is available
  if ! command -v openssl &> /dev/null; then
    echo -e "${RED}Error: openssl is not installed or not in PATH${NC}"
    exit 1
  fi
}

# Function: Setup test environment
function setup_test_environment() {
  echo "Setting up test environment..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Check if docker-compose.yml exists
  if [ ! -f "docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    return 1
  fi
  
  # Check if SSL settings file exists
  if [ ! -f "conf.d/ssl-settings.conf" ]; then
    echo -e "${RED}Error: ssl-settings.conf not found${NC}"
    return 1
  fi
  
  # Create test certificates directory
  mkdir -p "${PROXY_DIR}/certs/test.local"
  
  # Generate self-signed certificate for testing
  echo "Generating self-signed certificate for testing..."
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${PROXY_DIR}/certs/test.local/cert-key.pem" \
    -out "${PROXY_DIR}/certs/test.local/cert.pem" \
    -subj "/CN=test.local" \
    -addext "subjectAltName=DNS:test.local,DNS:www.test.local"
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to generate self-signed certificate${NC}"
    return 1
  fi
  
  # Create test domain configuration
  echo "Creating test domain configuration..."
  cat > "${PROXY_DIR}/conf.d/domains/test.local.conf" << EOF
# Domain configuration for test.local
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name test.local www.test.local;
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/test.local/cert.pem;
    ssl_certificate_key /etc/nginx/certs/test.local/cert-key.pem;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Return 200 for testing
    location / {
        return 200 'SSL Test Server';
    }
}
EOF
  
  # Start proxy container
  echo "Starting proxy container..."
  docker-compose up -d --build
  
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Failed to start proxy container${NC}"
    return 1
  fi
  
  # Wait for container to start
  echo "Waiting for container to start..."
  sleep 5
  
  return 0
}

# Function: Test SSL protocols
function test_ssl_protocols() {
  echo "Testing SSL/TLS protocols..."
  
  # Test SSLv3 (should be disabled)
  echo "Testing SSLv3 (should be disabled)..."
  RESPONSE=$(echo | openssl s_client -connect localhost:443 -ssl3 2>&1)
  
  if [[ "$RESPONSE" == *"ssl handshake failure"* ]] || [[ "$RESPONSE" == *"wrong version number"* ]]; then
    echo -e "${GREEN}SSLv3 is disabled - Good!${NC}"
  else
    echo -e "${RED}Error: SSLv3 is enabled - Security risk!${NC}"
    return 1
  fi
  
  # Test TLS 1.0 (should be disabled)
  echo "Testing TLS 1.0 (should be disabled)..."
  RESPONSE=$(echo | openssl s_client -connect localhost:443 -tls1 2>&1)
  
  if [[ "$RESPONSE" == *"ssl handshake failure"* ]] || [[ "$RESPONSE" == *"wrong version number"* ]]; then
    echo -e "${GREEN}TLS 1.0 is disabled - Good!${NC}"
  else
    echo -e "${RED}Error: TLS 1.0 is enabled - Security risk!${NC}"
    return 1
  fi
  
  # Test TLS 1.1 (should be disabled)
  echo "Testing TLS 1.1 (should be disabled)..."
  RESPONSE=$(echo | openssl s_client -connect localhost:443 -tls1_1 2>&1)
  
  if [[ "$RESPONSE" == *"ssl handshake failure"* ]] || [[ "$RESPONSE" == *"wrong version number"* ]]; then
    echo -e "${GREEN}TLS 1.1 is disabled - Good!${NC}"
  else
    echo -e "${RED}Error: TLS 1.1 is enabled - Security risk!${NC}"
    return 1
  fi
  
  # Test TLS 1.2 (should be enabled)
  echo "Testing TLS 1.2 (should be enabled)..."
  RESPONSE=$(echo | openssl s_client -connect localhost:443 -tls1_2 2>&1)
  
  if [[ "$RESPONSE" == *"CONNECTED"* ]]; then
    echo -e "${GREEN}TLS 1.2 is enabled - Good!${NC}"
  else
    echo -e "${RED}Error: TLS 1.2 is disabled${NC}"
    return 1
  fi
  
  # Test TLS 1.3 (should be enabled if supported)
  echo "Testing TLS 1.3 (should be enabled if supported)..."
  RESPONSE=$(echo | openssl s_client -connect localhost:443 -tls1_3 2>&1)
  
  if [[ "$RESPONSE" == *"CONNECTED"* ]]; then
    echo -e "${GREEN}TLS 1.3 is enabled - Good!${NC}"
  else
    echo -e "${YELLOW}Warning: TLS 1.3 is not enabled (might be due to OpenSSL version)${NC}"
    # Not a critical error, just a warning
  fi
  
  return 0
}

# Function: Test cipher strength
function test_cipher_strength() {
  echo "Testing cipher strength..."
  
  # Get cipher list
  CIPHERS=$(echo | openssl s_client -connect localhost:443 -cipher "ALL:eNULL" 2>/dev/null | grep "Cipher is")
  
  echo "Cipher used: $CIPHERS"
  
  # Check for weak ciphers
  WEAK_CIPHERS="DES|RC4|MD5|NULL|EXP|ADH|AECDH"
  if [[ "$CIPHERS" =~ $WEAK_CIPHERS ]]; then
    echo -e "${RED}Error: Weak cipher detected: $CIPHERS${NC}"
    return 1
  else
    echo -e "${GREEN}No weak ciphers detected - Good!${NC}"
  fi
  
  return 0
}

# Function: Test HSTS header
function test_hsts_header() {
  echo "Testing HTTP Strict Transport Security (HSTS) header..."
  
  # Get headers
  HEADERS=$(curl -s -I https://localhost 2>/dev/null)
  
  # Check for HSTS header
  if [[ "$HEADERS" == *"Strict-Transport-Security"* ]]; then
    echo -e "${GREEN}HSTS header is present - Good!${NC}"
    
    # Check HSTS max-age
    if [[ "$HEADERS" == *"max-age=15768000"* ]]; then
      echo -e "${GREEN}HSTS max-age is at least 6 months - Good!${NC}"
    else
      echo -e "${YELLOW}Warning: HSTS max-age is less than recommended 6 months${NC}"
      # Not a critical error, just a warning
    fi
    
    # Check includeSubDomains
    if [[ "$HEADERS" == *"includeSubDomains"* ]]; then
      echo -e "${GREEN}HSTS includeSubDomains is enabled - Good!${NC}"
    else
      echo -e "${YELLOW}Warning: HSTS includeSubDomains is not enabled${NC}"
      # Not a critical error, just a warning
    fi
    
    # Check preload
    if [[ "$HEADERS" == *"preload"* ]]; then
      echo -e "${GREEN}HSTS preload is enabled - Good!${NC}"
    else
      echo -e "${YELLOW}Warning: HSTS preload is not enabled${NC}"
      # Not a critical error, just a warning
    fi
  else
    echo -e "${RED}Error: HSTS header is not present${NC}"
    return 1
  fi
  
  return 0
}

# Function: Cleanup test environment
function cleanup_test_environment() {
  echo "Cleaning up test environment..."
  
  # Navigate to proxy directory
  cd "${PROXY_DIR}"
  
  # Stop proxy container
  docker-compose down
  
  # Remove test domain configuration
  rm -f "${PROXY_DIR}/conf.d/domains/test.local.conf"
  
  # Remove test certificates
  rm -rf "${PROXY_DIR}/certs/test.local"
  
  echo -e "${GREEN}Test environment cleaned up${NC}"
  return 0
}

# Function: Run all tests
function run_all_tests() {
  local FAILED=0
  
  setup_test_environment
  if [ $? -ne 0 ]; then
    FAILED=1
    echo -e "${RED}Skipping further tests due to setup failure${NC}"
    cleanup_test_environment
    return $FAILED
  fi
  
  test_ssl_protocols
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  test_cipher_strength
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  test_hsts_header
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  cleanup_test_environment
  
  if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All SSL/TLS configuration tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some SSL/TLS configuration tests failed!${NC}"
    return 1
  fi
}

# Main script execution
check_environment
run_all_tests
exit $? 