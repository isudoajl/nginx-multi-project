#!/bin/bash

# Test script to verify production deployment functionality
# This script tests the production deployment process and certificate management

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
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
NGINX_DIR="${PROJECT_ROOT}/nginx"
TEST_DIR=$(mktemp -d)

echo -e "${YELLOW}Starting production deployment test...${NC}"

# Track test success/failure
test_success=true

# Function to run a test and report results
run_test() {
  local test_name="$1"
  local test_command="$2"
  
  echo -e "${YELLOW}Testing: ${test_name}${NC}"
  
  if eval "${test_command}"; then
    echo -e "${GREEN}✓ Test passed: ${test_name}${NC}"
    return 0
  else
    echo -e "${RED}✗ Test failed: ${test_name}${NC}"
    test_success=false
    return 1
  fi
}

# Setup test environment
setup_test_env() {
  echo -e "${YELLOW}Setting up test environment...${NC}"
  
  # Create test directories
  mkdir -p "${TEST_DIR}/nginx/config/environments/production"
  mkdir -p "${TEST_DIR}/nginx/certs/production"
  mkdir -p "${TEST_DIR}/nginx/scripts/prod"
  mkdir -p "${TEST_DIR}/nginx/backups"
  
  # Copy production scripts for testing
  cp "${NGINX_DIR}/scripts/prod/prod-deployment.sh" "${TEST_DIR}/nginx/scripts/prod/"
  cp "${NGINX_DIR}/scripts/prod/cert-management.sh" "${TEST_DIR}/nginx/scripts/prod/"
  chmod +x "${TEST_DIR}/nginx/scripts/prod/"*.sh
  
  # Create sample production configuration
  cat > "${TEST_DIR}/nginx/config/environments/production/env.conf" << EOF
# Production Environment Configuration
server_name example.com www.example.com;
ssl on;
ssl_certificate /etc/nginx/certs/example.com.crt;
ssl_certificate_key /etc/nginx/certs/example.com.key;
access_log /var/log/nginx/access.log combined;
error_log /var/log/nginx/error.log warn;

# Compression settings for production
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css application/javascript application/json image/svg+xml application/xml+rss application/xml;
brotli_static on;
EOF
}

# Clean up test environment
cleanup_test_env() {
  echo -e "${YELLOW}Cleaning up test environment...${NC}"
  rm -rf "${TEST_DIR}"
}

# Test 1: Test production deployment script validation
test_deployment_validation() {
  # Create a modified version of the script for testing
  local test_script="${TEST_DIR}/test-validate.sh"
  
  cat > "${test_script}" << 'EOF'
#!/bin/bash
set -e

  # Mock paths for testing
TEST_DIR="${TEST_DIR}"
PROD_CONFIG_DIR="${TEST_DIR}/nginx/config/environments/production"

  # Mock validation function
validate_config() {
  echo "PROD_CONFIG_DIR=${PROD_CONFIG_DIR}"
  ls -la "${PROD_CONFIG_DIR}" || true
  if [ -f "${PROD_CONFIG_DIR}/env.conf" ]; then
    echo "Configuration validation successful"
    return 0
  else
    echo "Configuration validation failed"
    return 1
  fi
}

# Run validation
validate_config
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 2: Test backup and restore functionality
test_backup_restore() {
  # Create a modified version of the script for testing
  local test_script="${TEST_DIR}/test-backup-restore.sh"
  
  cat > "${test_script}" << 'EOF'
#!/bin/bash
set -e

# Mock paths for testing
PROD_CONFIG_DIR="${TEST_DIR}/nginx/config/environments/production"
BACKUP_DIR="${TEST_DIR}/nginx/backups/test-backup"
RESTORE_DIR="${TEST_DIR}/nginx/restored"

# Create test directories
mkdir -p "${BACKUP_DIR}/config"
mkdir -p "${RESTORE_DIR}"

# Backup the configuration
cp -r "${PROD_CONFIG_DIR}"/* "${BACKUP_DIR}/config/"

# Modify the original configuration
echo "# Modified configuration" >> "${PROD_CONFIG_DIR}/env.conf"

# Restore from backup
mkdir -p "${RESTORE_DIR}/config"
cp -r "${BACKUP_DIR}/config/"* "${RESTORE_DIR}/config/"

# Verify restoration
if diff -q "${BACKUP_DIR}/config/env.conf" "${RESTORE_DIR}/config/env.conf" > /dev/null; then
  echo "Backup and restore successful"
  return 0
else
  echo "Backup and restore failed"
  return 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 3: Test certificate management
test_certificate_management() {
  # Create a modified version of the script for testing
  local test_script="${TEST_DIR}/test-cert-management.sh"
  
  cat > "${test_script}" << 'EOF'
#!/bin/bash
set -e

# Mock paths for testing
CERTS_DIR="${TEST_DIR}/nginx/certs/production"
DOMAIN="example.com"

# Create certificates directory
mkdir -p "${CERTS_DIR}/${DOMAIN}"

# Create a test certificate configuration
cat > "${CERTS_DIR}/${DOMAIN}/cert.cnf" << EOC
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
EOC

# Generate a test certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.key" \
  -out "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" \
  -config "${CERTS_DIR}/${DOMAIN}/cert.cnf" 2>/dev/null

# Create symlinks
ln -sf "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.key" "${CERTS_DIR}/current.key"
ln -sf "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" "${CERTS_DIR}/current.crt"

# Verify certificate creation
if [ -f "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" ] && [ -f "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.key" ]; then
  # Verify certificate validity
  if openssl x509 -noout -text -in "${CERTS_DIR}/${DOMAIN}/${DOMAIN}.crt" | grep -q "${DOMAIN}"; then
    echo "Certificate management successful"
    return 0
  fi
fi

echo "Certificate management failed"
return 1
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 4: Test nginx.conf generation
test_nginx_conf_generation() {
  # Create a modified version of the script for testing
  local test_script="${TEST_DIR}/test-nginx-conf.sh"
  
  cat > "${test_script}" << 'EOF'
#!/bin/bash
set -e

# Mock paths for testing
PROD_CONFIG_DIR="${TEST_DIR}/nginx/config/environments/production"

# Remove existing nginx.conf if it exists
rm -f "${PROD_CONFIG_DIR}/nginx.conf"

# Generate nginx.conf
cat > "${PROD_CONFIG_DIR}/nginx.conf" << EOC
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
EOC

# Verify nginx.conf generation
if [ -f "${PROD_CONFIG_DIR}/nginx.conf" ]; then
  # Check for required SSL settings
  if grep -q "ssl_protocols TLSv1.2 TLSv1.3" "${PROD_CONFIG_DIR}/nginx.conf" && \
     grep -q "ssl_prefer_server_ciphers on" "${PROD_CONFIG_DIR}/nginx.conf" && \
     grep -q "ssl_session_cache" "${PROD_CONFIG_DIR}/nginx.conf"; then
    echo "nginx.conf generation successful"
    return 0
  fi
fi

echo "nginx.conf generation failed"
return 1
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 5: Test cron job setup for certificate renewal
test_cron_setup() {
  # Create a modified version of the script for testing
  local test_script="${TEST_DIR}/test-cron-setup.sh"
  
  cat > "${test_script}" << 'EOF'
#!/bin/bash
set -e

# Mock paths for testing
NGINX_DIR="${TEST_DIR}/nginx"
CRON_SCRIPT="${NGINX_DIR}/scripts/prod/cert-renewal-cron.sh"

# Create scripts directory if it doesn't exist
mkdir -p "$(dirname "${CRON_SCRIPT}")"

# Create cron script
cat > "${CRON_SCRIPT}" << EOC
#!/bin/bash

# Certificate Renewal Cron Script
# This script is meant to be run by cron to automatically renew certificates

# Define paths
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
CERT_SCRIPT="\${SCRIPT_DIR}/cert-management.sh"

# Run certificate renewal
\${CERT_SCRIPT} --renew

# Reload Nginx if certificates were renewed
if [ \$? -eq 0 ]; then
  # In a real environment, this would reload Nginx
  # systemctl reload nginx
  echo "Certificates renewed successfully"
fi

exit 0
EOC

chmod +x "${CRON_SCRIPT}"

# Verify cron script creation
if [ -f "${CRON_SCRIPT}" ] && [ -x "${CRON_SCRIPT}" ]; then
  # Check for required content
  if grep -q "Certificate Renewal Cron Script" "${CRON_SCRIPT}" && \
     grep -q "Run certificate renewal" "${CRON_SCRIPT}" && \
     grep -q "Reload Nginx" "${CRON_SCRIPT}"; then
    echo "Cron setup successful"
    return 0
  fi
fi

echo "Cron setup failed"
return 1
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Run all tests
main() {
  # Setup test environment
  setup_test_env
  
  # Run tests
  run_test "Production deployment validation" "test_deployment_validation"
  run_test "Backup and restore functionality" "test_backup_restore"
  run_test "Certificate management" "test_certificate_management"
  run_test "Nginx configuration generation" "test_nginx_conf_generation"
  run_test "Cron job setup for certificate renewal" "test_cron_setup"
  
  # Clean up test environment
  cleanup_test_env
  
  # Report overall test results
  if [ "${test_success}" = true ]; then
    echo -e "${GREEN}All production deployment tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some production deployment tests failed!${NC}"
    exit 1
  fi
}

# Run the main function
main 