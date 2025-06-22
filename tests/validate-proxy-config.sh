#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/../proxy"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function: Check environment
function check_environment() {
  # Check if we're in a Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    echo -e "${RED}Error: Please enter Nix environment with 'nix develop' first${NC}"
    exit 1
  fi
  
  # Check if nginx is available
  if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Error: nginx is not installed or not in PATH${NC}"
    exit 1
  fi
}

# Function: Validate nginx.conf
function validate_main_config() {
  echo "Validating main nginx configuration..."
  
  if [ ! -f "${PROXY_DIR}/nginx.conf" ]; then
    echo -e "${RED}Error: nginx.conf not found${NC}"
    return 1
  fi
  
  # Use nginx -t with the specific config file
  nginx -c "${PROXY_DIR}/nginx.conf" -t 2>/dev/null
  
  if [ $? -eq 0 ]; then
    echo -e "${GREEN}Main configuration is valid${NC}"
    return 0
  else
    echo -e "${RED}Main configuration is invalid${NC}"
    # Show detailed error
    nginx -c "${PROXY_DIR}/nginx.conf" -t
    return 1
  fi
}

# Function: Validate SSL settings
function validate_ssl_settings() {
  echo "Validating SSL settings..."
  
  if [ ! -f "${PROXY_DIR}/conf.d/ssl-settings.conf" ]; then
    echo -e "${RED}Error: ssl-settings.conf not found${NC}"
    return 1
  fi
  
  # Check for required SSL directives
  grep -q "ssl_protocols" "${PROXY_DIR}/conf.d/ssl-settings.conf"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: ssl_protocols directive not found in SSL settings${NC}"
    return 1
  fi
  
  grep -q "ssl_ciphers" "${PROXY_DIR}/conf.d/ssl-settings.conf"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: ssl_ciphers directive not found in SSL settings${NC}"
    return 1
  fi
  
  echo -e "${GREEN}SSL settings are valid${NC}"
  return 0
}

# Function: Validate security headers
function validate_security_headers() {
  echo "Validating security headers..."
  
  if [ ! -f "${PROXY_DIR}/conf.d/security-headers.conf" ]; then
    echo -e "${RED}Error: security-headers.conf not found${NC}"
    return 1
  fi
  
  # Check for required security headers
  grep -q "X-Frame-Options" "${PROXY_DIR}/conf.d/security-headers.conf"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: X-Frame-Options header not found in security headers${NC}"
    return 1
  fi
  
  grep -q "X-Content-Type-Options" "${PROXY_DIR}/conf.d/security-headers.conf"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: X-Content-Type-Options header not found in security headers${NC}"
    return 1
  fi
  
  grep -q "Content-Security-Policy" "${PROXY_DIR}/conf.d/security-headers.conf"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: Content-Security-Policy header not found in security headers${NC}"
    return 1
  fi
  
  echo -e "${GREEN}Security headers are valid${NC}"
  return 0
}

# Function: Validate domain configurations
function validate_domain_configs() {
  echo "Validating domain configurations..."
  
  # Check if domains directory exists
  if [ ! -d "${PROXY_DIR}/conf.d/domains" ]; then
    echo -e "${RED}Error: domains directory not found${NC}"
    return 1
  fi
  
  # Check if there are any domain configurations
  DOMAIN_COUNT=$(ls -1 "${PROXY_DIR}/conf.d/domains"/*.conf 2>/dev/null | wc -l)
  
  if [ "$DOMAIN_COUNT" -eq 0 ]; then
    echo -e "${RED}Warning: No domain configurations found${NC}"
    # Not a critical error, just a warning
  else
    echo -e "${GREEN}Found $DOMAIN_COUNT domain configuration(s)${NC}"
    
    # Validate each domain configuration
    for DOMAIN_FILE in "${PROXY_DIR}/conf.d/domains"/*.conf; do
      echo "Validating $(basename "$DOMAIN_FILE")..."
      
      # Check for required directives
      grep -q "server_name" "$DOMAIN_FILE"
      if [ $? -ne 0 ]; then
        echo -e "${RED}Error: server_name directive not found in $(basename "$DOMAIN_FILE")${NC}"
        return 1
      fi
      
      grep -q "proxy_pass" "$DOMAIN_FILE"
      if [ $? -ne 0 ]; then
        echo -e "${RED}Error: proxy_pass directive not found in $(basename "$DOMAIN_FILE")${NC}"
        return 1
      fi
      
      echo -e "${GREEN}$(basename "$DOMAIN_FILE") is valid${NC}"
    done
  fi
  
  return 0
}

# Function: Validate docker-compose.yml
function validate_docker_compose() {
  echo "Validating docker-compose.yml..."
  
  if [ ! -f "${PROXY_DIR}/docker-compose.yml" ]; then
    echo -e "${RED}Error: docker-compose.yml not found${NC}"
    return 1
  fi
  
  # Check for required services and networks
  grep -q "nginx-proxy:" "${PROXY_DIR}/docker-compose.yml"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: nginx-proxy service not found in docker-compose.yml${NC}"
    return 1
  fi
  
  grep -q "proxy-network:" "${PROXY_DIR}/docker-compose.yml"
  if [ $? -ne 0 ]; then
    echo -e "${RED}Error: proxy-network not found in docker-compose.yml${NC}"
    return 1
  fi
  
  echo -e "${GREEN}docker-compose.yml is valid${NC}"
  return 0
}

# Function: Run all validation tests
function run_all_tests() {
  local FAILED=0
  
  validate_main_config
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  validate_ssl_settings
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  validate_security_headers
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  validate_domain_configs
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  validate_docker_compose
  if [ $? -ne 0 ]; then
    FAILED=1
  fi
  
  if [ $FAILED -eq 0 ]; then
    echo -e "\n${GREEN}All tests passed!${NC}"
    return 0
  else
    echo -e "\n${RED}Some tests failed!${NC}"
    return 1
  fi
}

# Main script execution
check_environment
run_all_tests
exit $? 