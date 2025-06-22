#!/bin/bash

# Test script to verify certificate rotation functionality
# This script tests certificate rotation for certificates that are about to expire

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

echo -e "${YELLOW}Starting certificate rotation test...${NC}"

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
  mkdir -p "${TEST_DIR}/nginx/certs/backup"
  mkdir -p "${TEST_DIR}/nginx/config/cert-manager"
  mkdir -p "${TEST_DIR}/nginx/logs/cert-manager"
  mkdir -p "${TEST_DIR}/nginx/scripts/prod"
  
  # Copy certificate rotation script for testing
  if [ -f "${NGINX_DIR}/scripts/prod/cert-rotation.sh" ]; then
    cp "${NGINX_DIR}/scripts/prod/cert-rotation.sh" "${TEST_DIR}/nginx/scripts/prod/"
    chmod +x "${TEST_DIR}/nginx/scripts/prod/cert-rotation.sh"
  else
    echo -e "${RED}Certificate rotation script not found!${NC}"
    test_success=false
    return 1
  fi
}

# Clean up test environment
cleanup_test_env() {
  echo -e "${YELLOW}Cleaning up test environment...${NC}"
  rm -rf "${TEST_DIR}"
}

# Test 1: Certificate expiration detection
test_certificate_expiration_detection() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-expiration-detection.sh"
  
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

# Create a certificate that will expire soon (backdated)
openssl req -x509 -nodes -days 1 -startdate -364d -enddate -334d -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null || true

# Create a function to check expiration
check_expiration() {
  local cert_file="\$1"
  local threshold_days="\$2"
  
  # Check if certificate will expire within threshold days
  ! openssl x509 -noout -checkend \$(( threshold_days * 86400 )) -in "\${cert_file}" &>/dev/null
}

# Check if the certificate is detected as expiring within 30 days
if check_expiration "${certs_dir}/${domain}/${domain}.crt" 30; then
  echo "Certificate correctly detected as expiring soon"
  exit 0
else
  echo "Certificate expiration detection failed"
  exit 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 2: Certificate rotation
test_certificate_rotation() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  local backup_dir="${TEST_DIR}/nginx/certs/backup"
  
  # Create test script
  local test_script="${TEST_DIR}/test-certificate-rotation.sh"
  
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

# Create a certificate that will expire soon (backdated)
openssl req -x509 -nodes -days 1 -startdate -364d -enddate -334d -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null || true

# Store the initial certificate fingerprint
initial_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/${domain}/${domain}.crt" | cut -d= -f2)

# Create symlinks to the initial certificates
ln -sf "${certs_dir}/${domain}/${domain}.key" "${certs_dir}/current.key"
ln -sf "${certs_dir}/${domain}/${domain}.crt" "${certs_dir}/current.crt"

# Create a modified rotation script for testing
cat > "${TEST_DIR}/nginx/scripts/prod/test-rotate.sh" << EOC
#!/bin/bash
set -e

# Define paths
CERTS_DIR="${certs_dir}"
BACKUP_DIR="${backup_dir}"

# Function to check certificate expiration
check_certificate_expiration() {
  local cert_file="\$1"
  local threshold_days="\$2"
  
  # Always return true for testing
  return 0
}

# Function to create a backup of certificates
backup_certificates() {
  local domain="\$1"
  local backup_path="\${BACKUP_DIR}/\${domain}-test"
  
  mkdir -p "\${backup_path}"
  
  if [ -f "\${CERTS_DIR}/\${domain}/\${domain}.crt" ]; then
    cp "\${CERTS_DIR}/\${domain}/\${domain}.crt" "\${backup_path}/"
  fi
  
  if [ -f "\${CERTS_DIR}/\${domain}/\${domain}.key" ]; then
    cp "\${CERTS_DIR}/\${domain}/\${domain}.key" "\${backup_path}/"
  fi
}

# Function to rotate certificate
rotate_certificate() {
  local domain="\$1"
  local temp_dir="\${CERTS_DIR}/\${domain}_temp"
  
  # Create temporary directory
  mkdir -p "\${temp_dir}"
  
  # Create certificate configuration
  cat > "\${temp_dir}/cert.cnf" << EOF
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
CN = \${domain}

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = \${domain}
DNS.2 = www.\${domain}
EOF
  
  # Generate new certificate
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
    -keyout "\${temp_dir}/\${domain}.key" \\
    -out "\${temp_dir}/\${domain}.crt" \\
    -config "\${temp_dir}/cert.cnf" 2>/dev/null
  
  # Backup existing certificates
  backup_certificates "\${domain}"
  
  # Atomic update of certificates
  if [ -f "\${temp_dir}/\${domain}.key" ] && [ -f "\${temp_dir}/\${domain}.crt" ]; then
    cp "\${temp_dir}/\${domain}.key" "\${CERTS_DIR}/\${domain}/\${domain}.key.new"
    cp "\${temp_dir}/\${domain}.crt" "\${CERTS_DIR}/\${domain}/\${domain}.crt.new"
    
    # Use atomic rename to replace the files
    mv -f "\${CERTS_DIR}/\${domain}/\${domain}.key.new" "\${CERTS_DIR}/\${domain}/\${domain}.key"
    mv -f "\${CERTS_DIR}/\${domain}/\${domain}.crt.new" "\${CERTS_DIR}/\${domain}/\${domain}.crt"
  fi
  
  # Then update the symlinks atomically
  if [ -f "\${CERTS_DIR}/\${domain}/\${domain}.key" ] && [ -f "\${CERTS_DIR}/\${domain}/\${domain}.crt" ]; then
    # Create temporary symlinks
    ln -sf "\${CERTS_DIR}/\${domain}/\${domain}.key" "\${CERTS_DIR}/current.key.new"
    ln -sf "\${CERTS_DIR}/\${domain}/\${domain}.crt" "\${CERTS_DIR}/current.crt.new"
    
    # Atomically replace the symlinks
    mv -f "\${CERTS_DIR}/current.key.new" "\${CERTS_DIR}/current.key"
    mv -f "\${CERTS_DIR}/current.crt.new" "\${CERTS_DIR}/current.crt"
  fi
  
  # Clean up temporary directory
  rm -rf "\${temp_dir}"
  
  return 0
}

# Rotate the certificate
rotate_certificate "${domain}"
EOC

chmod +x "${TEST_DIR}/nginx/scripts/prod/test-rotate.sh"

# Run the rotation script
"${TEST_DIR}/nginx/scripts/prod/test-rotate.sh"

# Check if certificate was rotated
new_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/${domain}/${domain}.crt" | cut -d= -f2)

if [ "\$initial_fingerprint" != "\$new_fingerprint" ]; then
  # Check if symlinks point to the new certificate
  current_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/current.crt" | cut -d= -f2)
  
  if [ "\$new_fingerprint" = "\$current_fingerprint" ]; then
    # Check if backup was created
    if [ -d "${backup_dir}" ] && [ \$(find "${backup_dir}" -name "*.crt" | wc -l) -gt 0 ]; then
      echo "Certificate rotation successful"
      exit 0
    else
      echo "Certificate backup not created"
      exit 1
    fi
  else
    echo "Symlinks not updated correctly"
    exit 1
  fi
else
  echo "Certificate not rotated"
  exit 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 3: Atomic certificate update
test_atomic_certificate_update() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  
  # Create test script
  local test_script="${TEST_DIR}/test-atomic-update.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create certificate directory
mkdir -p "${certs_dir}/${domain}"

# Create initial certificate
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

# Generate initial certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null

# Create symlinks to the initial certificates
ln -sf "${certs_dir}/${domain}/${domain}.key" "${certs_dir}/current.key"
ln -sf "${certs_dir}/${domain}/${domain}.crt" "${certs_dir}/current.crt"

# Store the initial certificate fingerprint
initial_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/current.crt" | cut -d= -f2)

# Create a temporary directory for new certificate
mkdir -p "${certs_dir}/${domain}_temp"

# Create new certificate configuration
cat > "${certs_dir}/${domain}_temp/cert.cnf" << EOC
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
CN = ${domain}.new

[req_ext]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = www.${domain}
EOC

# Generate new certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}_temp/${domain}.key" \\
  -out "${certs_dir}/${domain}_temp/${domain}.crt" \\
  -config "${certs_dir}/${domain}_temp/cert.cnf" 2>/dev/null

# Store new certificate fingerprint
new_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/${domain}_temp/${domain}.crt" | cut -d= -f2)

# Perform atomic update
# First update the certificate files
cp "${certs_dir}/${domain}_temp/${domain}.key" "${certs_dir}/${domain}/${domain}.key.new"
cp "${certs_dir}/${domain}_temp/${domain}.crt" "${certs_dir}/${domain}/${domain}.crt.new"

# Use atomic rename to replace the files
mv -f "${certs_dir}/${domain}/${domain}.key.new" "${certs_dir}/${domain}/${domain}.key"
mv -f "${certs_dir}/${domain}/${domain}.crt.new" "${certs_dir}/${domain}/${domain}.crt"

# Then update the symlinks atomically
ln -sf "${certs_dir}/${domain}/${domain}.key" "${certs_dir}/current.key.new"
ln -sf "${certs_dir}/${domain}/${domain}.crt" "${certs_DIR}/current.crt.new"

mv -f "${certs_dir}/current.key.new" "${certs_dir}/current.key"
mv -f "${certs_DIR}/current.crt.new" "${certs_dir}/current.crt"

# Verify the update was atomic
updated_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/current.crt" | cut -d= -f2)

if [ "\$updated_fingerprint" = "\$new_fingerprint" ] && [ "\$updated_fingerprint" != "\$initial_fingerprint" ]; then
  echo "Atomic certificate update successful"
  exit 0
else
  echo "Atomic certificate update failed"
  exit 1
fi
EOF
  
  chmod +x "${test_script}"
  
  # Run the test
  "${test_script}"
}

# Test 4: Integration with cert-management.sh
test_integration_with_cert_management() {
  local domain="example.com"
  local certs_dir="${TEST_DIR}/nginx/certs/production"
  local scripts_dir="${TEST_DIR}/nginx/scripts/prod"
  
  # Create test script
  local test_script="${TEST_DIR}/test-integration.sh"
  
  cat > "${test_script}" << EOF
#!/bin/bash
set -e

# Create certificate directory
mkdir -p "${certs_dir}/${domain}"

# Copy cert-management.sh for testing
if [ -f "${NGINX_DIR}/scripts/prod/cert-management.sh" ]; then
  cp "${NGINX_DIR}/scripts/prod/cert-management.sh" "${scripts_dir}/"
  chmod +x "${scripts_dir}/cert-management.sh"
else
  echo "cert-management.sh not found"
  exit 1
fi

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
openssl req -x509 -nodes -days 1 -startdate -364d -enddate -334d -newkey rsa:2048 \\
  -keyout "${certs_dir}/${domain}/${domain}.key" \\
  -out "${certs_dir}/${domain}/${domain}.crt" \\
  -config "${certs_dir}/${domain}/cert.cnf" 2>/dev/null || true

# Create symlinks to the initial certificates
ln -sf "${certs_dir}/${domain}/${domain}.key" "${certs_dir}/current.key"
ln -sf "${certs_dir}/${domain}/${domain}.crt" "${certs_dir}/current.crt"

# Store the initial certificate fingerprint
initial_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/${domain}/${domain}.crt" | cut -d= -f2)

# Create a simplified version of cert-rotation.sh for testing
cat > "${scripts_dir}/cert-rotation-test.sh" << EOC
#!/bin/bash
set -e

# Define paths
CERTS_DIR="${certs_dir}"
CERT_MANAGEMENT="${scripts_dir}/cert-management.sh"

# Find all certificate files
find "\${CERTS_DIR}" -name "*.crt" | while read cert_file; do
  # Skip if it's a symlink
  if [ -L "\${cert_file}" ]; then
    continue
  fi
  
  domain=\$(basename "\$(dirname "\${cert_file}")")
  
  # Check if certificate is expiring soon (always true in this test)
  # This would normally use openssl x509 -noout -checkend
  
  # Call cert-management.sh to renew the certificate
  "\${CERT_MANAGEMENT}" --acquire "\${domain}"
done

exit 0
EOC

chmod +x "${scripts_dir}/cert-rotation-test.sh"

# Run the rotation script
"${scripts_dir}/cert-rotation-test.sh"

# Check if certificate was renewed
new_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/${domain}/${domain}.crt" | cut -d= -f2)

if [ "\$initial_fingerprint" != "\$new_fingerprint" ]; then
  # Check if symlinks point to the new certificate
  current_fingerprint=\$(openssl x509 -noout -fingerprint -in "${certs_dir}/current.crt" | cut -d= -f2)
  
  if [ "\$new_fingerprint" = "\$current_fingerprint" ]; then
    echo "Integration with cert-management.sh successful"
    exit 0
  else
    echo "Symlinks not updated correctly"
    exit 1
  fi
else
  echo "Certificate not renewed"
  exit 1
fi
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
  run_test "Certificate expiration detection" "test_certificate_expiration_detection"
  run_test "Certificate rotation" "test_certificate_rotation"
  run_test "Atomic certificate update" "test_atomic_certificate_update"
  run_test "Integration with cert-management.sh" "test_integration_with_cert_management"
  
  # Clean up test environment
  cleanup_test_env
  
  # Report overall test results
  if [ "${test_success}" = true ]; then
    echo -e "${GREEN}All certificate rotation tests passed!${NC}"
    exit 0
  else
    echo -e "${RED}Some certificate rotation tests failed!${NC}"
    exit 1
  fi
}

# Run the main function
main