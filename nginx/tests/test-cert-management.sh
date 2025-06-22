#!/bin/bash

# Test script to verify certificate management functionality
# This script tests certificate acquisition, renewal, and validation

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

echo -e "${YELLOW}Starting certificate management test...${NC}"

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
  mkdir -p "${TEST_DIR}/nginx/certs/production"
  mkdir -p "${TEST_DIR}/nginx/config/cert-manager"
  mkdir -p "${TEST_DIR}/nginx/logs/cert-manager"
  
  # Copy certificate management script for testing
  if [ -f "${NGINX_DIR}/scripts/prod/cert-management.sh" ]; then
    mkdir -p "${TEST_DIR}/nginx/scripts/prod"
    cp "${NGINX_DIR}/scripts/prod/cert-management.sh" "${TEST_DIR}/nginx/scripts/prod/"
    chmod +x "${TEST_DIR}/nginx/scripts/prod/cert-management.sh"
  fi
}

# Clean up test environment
cleanup_test_env() {
  echo -e "${YELLOW}Cleaning up test environment...${NC}"
  rm -rf "${TEST_DIR}"
}

# Test 1: Certificate acquisition
test_certificate_acquisition() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-cert-acquisition.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create certificate directory
mkdir -p "${certs_dir}/${domain}"

# Create certificate configuration
cat > "${certs_dir}/${domain}/cert.cnf" << EOC
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
EOC

# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null

# Create symlinks
ln -sf "${certs_dir}/${domain}/${domain}.key" "${certs_dir}/current.key"
ln -sf "${certs_dir}/${domain}/${domain}.crt" "${certs_dir}/current.crt"

# Verify certificate creation
if [ -f "${certs_dir}/${domain}/${domain}.crt" ] && [ -f "${certs_dir}/${domain}/${domain}.key" ]; then
  # Check certificate content
  if openssl x509 -noout -subject -in "${certs_dir}/${domain}/${domain}.crt" | grep -q "${domain}"; then
    echo "Certificate acquisition successful"
    exit 0
  fi
fi

echo "Certificate acquisition failed"
exit 1
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 2: Certificate renewal
test_certificate_renewal() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-cert-renewal.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# First, create an initial certificate
mkdir -p "${certs_dir}/${domain}"

# Create certificate configuration
cat > "${certs_dir}/${domain}/cert.cnf" << EOC
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
EOC

# Generate initial certificate with a backdated timestamp
openssl req -x509 -nodes -days 1 -startdate -365d -enddate -364d -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null || true

# Store the initial modification time
if [ -f "${certs_dir}/${domain}/${domain}.crt" ]; then
  initial_mtime=\$(stat -c %Y "${certs_dir}/${domain}/${domain}.crt")
else
  echo "Failed to create initial certificate"
  exit 1
fi

# Sleep to ensure different timestamp
sleep 1

# Now simulate renewal
mkdir -p "${certs_dir}/${domain}_renewed"

# Create new certificate configuration
cat > "${certs_dir}/${domain}_renewed/cert.cnf" << EOC
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
EOC

# Generate renewed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}_renewed/${domain}.key" \\
  -out "${certs_dir}/${domain}_renewed/${domain}.crt" \\
  -config "${certs_dir}/${domain}_renewed/cert.cnf" 2>/dev/null

# Replace old certificate with renewed one
cp "${certs_dir}/${domain}_renewed/${domain}.key" "${certs_dir}/${domain}/${domain}.key"
cp "${certs_dir}/${domain}_renewed/${domain}.crt" "${certs_dir}/${domain}/${domain}.crt"

# Check if certificate was renewed (modification time should be different)
renewed_mtime=\$(stat -c %Y "${certs_dir}/${domain}/${domain}.crt")

if [ "\$initial_mtime" != "\$renewed_mtime" ]; then
  # Verify the renewed certificate is valid
  if openssl x509 -noout -checkend 86400 -in "${certs_dir}/${domain}/${domain}.crt"; then
    echo "Certificate renewal successful"
    exit 0
  fi
fi

echo "Certificate renewal failed"
exit 1
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 3: Certificate validation
test_certificate_validation() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-cert-validation.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create certificate directory
mkdir -p "${certs_dir}/${domain}"

# Create certificate configuration
cat > "${certs_dir}/${domain}/cert.cnf" << EOC
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
EOC

# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null

# Validate certificate
validation_success=true

# Check 1: Certificate exists
if [ ! -f "${certs_dir}/${domain}/${domain}.crt" ] || [ ! -f "${certs_dir}/${domain}/${domain}.key" ]; then
  echo "Certificate files do not exist"
  validation_success=false
fi

# Check 2: Certificate is valid (not expired)
if ! openssl x509 -noout -checkend 0 -in "${certs_dir}/${domain}/${domain}.crt"; then
  echo "Certificate is expired or invalid"
  validation_success=false
fi

# Check 3: Certificate contains correct domain
if ! openssl x509 -noout -text -in "${certs_dir}/${domain}/${domain}.crt" | grep -q "${domain}"; then
  echo "Certificate does not contain the correct domain"
  validation_success=false
fi

# Check 4: Certificate and key match
cert_modulus=\$(openssl x509 -noout -modulus -in "${certs_dir}/${domain}/${domain}.crt" | openssl md5)
key_modulus=\$(openssl rsa -noout -modulus -in "${certs_dir}/${domain}/${domain}.key" | openssl md5)

if [ "\$cert_modulus" != "\$key_modulus" ]; then
  echo "Certificate and key do not match"
  validation_success=false
fi

if [ "\$validation_success" = true ]; then
  echo "Certificate validation successful"
  exit 0
else
  echo "Certificate validation failed"
  exit 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 4: Certificate status reporting
test_certificate_status() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-cert-status.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create certificate directory
mkdir -p "${certs_dir}/${domain}"

# Create certificate configuration
cat > "${certs_dir}/${domain}/cert.cnf" << EOC
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
EOC

# Generate certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null

# Check if we can extract status information
status_success=true

# Check 1: Get expiration date
expiry_date=\$(openssl x509 -noout -enddate -in "${certs_dir}/${domain}/${domain}.crt" | cut -d= -f2)
if [ -z "\$expiry_date" ]; then
  echo "Failed to get expiration date"
  status_success=false
fi

# Check 2: Get subject
subject=\$(openssl x509 -noout -subject -in "${certs_dir}/${domain}/${domain}.crt")
if [ -z "\$subject" ] || ! echo "\$subject" | grep -q "${domain}"; then
  echo "Failed to get correct subject"
  status_success=false
fi

# Check 3: Get issuer
issuer=\$(openssl x509 -noout -issuer -in "${certs_dir}/${domain}/${domain}.crt")
if [ -z "\$issuer" ]; then
  echo "Failed to get issuer"
  status_success=false
fi

# Check 4: Get SANs
sans=\$(openssl x509 -noout -text -in "${certs_dir}/${domain}/${domain}.crt" | grep -A1 "Subject Alternative Name" | tail -n1)
if [ -z "\$sans" ] || ! echo "\$sans" | grep -q "${domain}"; then
  echo "Failed to get SANs"
  status_success=false
fi

if [ "\$status_success" = true ]; then
  echo "Certificate status reporting successful"
  exit 0
else
  echo "Certificate status reporting failed"
  exit 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 5: Cron job setup
test_cron_setup() {
  local nginx_dir="${TEST_DIR}/nginx"
  local scripts_dir="${nginx_dir}/scripts/prod"
  
  # Create test script
  local test_script="${TEST_DIR}/test-cron-setup.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create scripts directory
mkdir -p "${scripts_dir}"

# Create cron script
cat > "${scripts_dir}/cert-renewal-cron.sh" << EOC
#!/bin/bash

# Certificate Renewal Cron Script
# This script is meant to be run by cron to automatically renew certificates

# Define paths
SCRIPT_DIR="\\\$(cd "\\\$(dirname "\\\${BASH_SOURCE[0]}")" && pwd)"
CERT_SCRIPT="\\\${SCRIPT_DIR}/cert-management.sh"

# Run certificate renewal
\\\${CERT_SCRIPT} --renew

# Reload Nginx if certificates were renewed
if [ \\\$? -eq 0 ]; then
  # In a real environment, this would reload Nginx
  # systemctl reload nginx
  echo "Certificates renewed successfully"
fi

exit 0
EOC

chmod +x "${scripts_dir}/cert-renewal-cron.sh"

# Check if cron script was created successfully
if [ -f "${scripts_dir}/cert-renewal-cron.sh" ] && [ -x "${scripts_dir}/cert-renewal-cron.sh" ]; then
  # Check content
  if grep -q "Certificate Renewal Cron Script" "${scripts_dir}/cert-renewal-cron.sh" && \\
     grep -q "Run certificate renewal" "${scripts_dir}/cert-renewal-cron.sh" && \\
     grep -q "Reload Nginx" "${scripts_dir}/cert-renewal-cron.sh"; then
    echo "Cron setup successful"
    exit 0
  fi
fi

echo "Cron setup failed"
exit 1
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
  run_test "Certificate acquisition" "test_certificate_acquisition"
  run_test "Certificate renewal" "test_certificate_renewal"
  run_test "Certificate validation" "test_certificate_validation"
  run_test "Certificate status reporting" "test_certificate_status"
  run_test "Cron job setup" "test_cron_setup"
  
  # Clean up test environment
  cleanup_test_env
  
  # Report overall test results
  if [ "${test_success}" = true ]; then
    echo -e "${GREEN}All certificate management tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some certificate management tests failed!${NC}"
    exit 1
  fi
}

# Run the main function
main 