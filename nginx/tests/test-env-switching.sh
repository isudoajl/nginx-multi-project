#!/bin/bash

# Test script to verify environment switching between development and production
# This script tests the ability to switch between environments seamlessly

set -e

# Check if we're in Nix environment
# if [ -z "$IN_NIX_SHELL" ]; then
#   echo "Please enter Nix environment with 'nix develop' first"
#   exit 1
# fi

# Define colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Define paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
ENV_CONFIG_DIR="$PROJECT_ROOT/nginx/config/environments"
TEST_PROJECT="test-project"

echo -e "${YELLOW}Starting environment switching test...${NC}"

# Check if required directories exist
if [ ! -d "$ENV_CONFIG_DIR" ]; then
    echo -e "${YELLOW}Creating environment configuration directory...${NC}"
    mkdir -p "$ENV_CONFIG_DIR/development"
    mkdir -p "$ENV_CONFIG_DIR/production"
    
    # Create sample development environment config
    cat > "$ENV_CONFIG_DIR/development/env.conf" <<EOF
# Development Environment Configuration
server_name localhost;
ssl off;
access_log /var/log/nginx/access.log;
error_log /var/log/nginx/error.log debug;
EOF

    # Create sample production environment config
    cat > "$ENV_CONFIG_DIR/production/env.conf" <<EOF
# Production Environment Configuration
server_name example.com www.example.com;
ssl on;
ssl_certificate /etc/nginx/certs/example.com.crt;
ssl_certificate_key /etc/nginx/certs/example.com.key;
access_log /var/log/nginx/access.log combined;
error_log /var/log/nginx/error.log warn;
EOF
fi

# Create temporary test project directory
TEST_PROJECT_DIR=$(mktemp -d)
mkdir -p "$TEST_PROJECT_DIR/nginx/conf.d"

# Test 1: Create environment switching script
echo -e "${YELLOW}Creating environment switching script...${NC}"
cat > "$TEST_PROJECT_DIR/switch-env.sh" <<EOF
#!/bin/bash
# Environment switching script

ENV=\$1

if [ "\$ENV" != "development" ] && [ "\$ENV" != "production" ]; then
    echo "Error: Environment must be either 'development' or 'production'"
    exit 1
fi

# Create symlink to the appropriate environment config
ln -sf "$ENV_CONFIG_DIR/\$ENV/env.conf" "$TEST_PROJECT_DIR/nginx/conf.d/environment.conf"

echo "Switched to \$ENV environment"
exit 0
EOF

chmod +x "$TEST_PROJECT_DIR/switch-env.sh"

# Test 2: Switch to development environment
echo -e "${YELLOW}Testing switch to development environment...${NC}"
if "$TEST_PROJECT_DIR/switch-env.sh" development; then
    echo -e "${GREEN}✓ Successfully switched to development environment${NC}"
else
    echo -e "${RED}✗ Failed to switch to development environment${NC}"
    test_failed=true
fi

# Verify development environment config
if grep -q "Development Environment Configuration" "$TEST_PROJECT_DIR/nginx/conf.d/environment.conf"; then
    echo -e "${GREEN}✓ Development environment config verified${NC}"
else
    echo -e "${RED}✗ Development environment config not found or incorrect${NC}"
    test_failed=true
fi

# Test 3: Switch to production environment
echo -e "${YELLOW}Testing switch to production environment...${NC}"
if "$TEST_PROJECT_DIR/switch-env.sh" production; then
    echo -e "${GREEN}✓ Successfully switched to production environment${NC}"
else
    echo -e "${RED}✗ Failed to switch to production environment${NC}"
    test_failed=true
fi

# Verify production environment config
if grep -q "Production Environment Configuration" "$TEST_PROJECT_DIR/nginx/conf.d/environment.conf"; then
    echo -e "${GREEN}✓ Production environment config verified${NC}"
else
    echo -e "${RED}✗ Production environment config not found or incorrect${NC}"
    test_failed=true
fi

# Test 4: Test Cloudflare configuration differences between environments
echo -e "${YELLOW}Testing Cloudflare configuration differences between environments...${NC}"

# Create sample Cloudflare configs for different environments
mkdir -p "$TEST_PROJECT_DIR/cloudflare/development"
mkdir -p "$TEST_PROJECT_DIR/cloudflare/production"

# Development Cloudflare config (minimal settings)
cat > "$TEST_PROJECT_DIR/cloudflare/development/terraform.tfvars" <<EOF
cloudflare_api_token = "dev-token"
domain_name = "dev.example.com"
origin_ip = "127.0.0.1"
create_zone = false
zone_id = "dev-zone-id"
enable_image_optimization = false
enable_argo_smart_routing = false
EOF

# Production Cloudflare config (full optimization)
cat > "$TEST_PROJECT_DIR/cloudflare/production/terraform.tfvars" <<EOF
cloudflare_api_token = "prod-token"
domain_name = "example.com"
origin_ip = "203.0.113.10"
create_zone = false
zone_id = "prod-zone-id"
enable_image_optimization = true
enable_argo_smart_routing = true
EOF

# Create environment-specific Cloudflare config symlink script
cat > "$TEST_PROJECT_DIR/switch-cloudflare-env.sh" <<EOF
#!/bin/bash
# Cloudflare environment switching script

ENV=\$1

if [ "\$ENV" != "development" ] && [ "\$ENV" != "production" ]; then
    echo "Error: Environment must be either 'development' or 'production'"
    exit 1
fi

# Create symlink to the appropriate Cloudflare environment config
ln -sf "$TEST_PROJECT_DIR/cloudflare/\$ENV/terraform.tfvars" "$TEST_PROJECT_DIR/cloudflare/terraform.tfvars"

echo "Switched Cloudflare config to \$ENV environment"
exit 0
EOF

chmod +x "$TEST_PROJECT_DIR/switch-cloudflare-env.sh"

# Test switching Cloudflare configs
echo -e "${YELLOW}Testing switch to development Cloudflare config...${NC}"
if "$TEST_PROJECT_DIR/switch-cloudflare-env.sh" development; then
    echo -e "${GREEN}✓ Successfully switched to development Cloudflare config${NC}"
else
    echo -e "${RED}✗ Failed to switch to development Cloudflare config${NC}"
    test_failed=true
fi

# Verify development Cloudflare config
if grep -q "dev.example.com" "$TEST_PROJECT_DIR/cloudflare/terraform.tfvars"; then
    echo -e "${GREEN}✓ Development Cloudflare config verified${NC}"
else
    echo -e "${RED}✗ Development Cloudflare config not found or incorrect${NC}"
    test_failed=true
fi

# Test switching to production Cloudflare config
echo -e "${YELLOW}Testing switch to production Cloudflare config...${NC}"
if "$TEST_PROJECT_DIR/switch-cloudflare-env.sh" production; then
    echo -e "${GREEN}✓ Successfully switched to production Cloudflare config${NC}"
else
    echo -e "${RED}✗ Failed to switch to production Cloudflare config${NC}"
    test_failed=true
fi

# Verify production Cloudflare config
if grep -q "example.com" "$TEST_PROJECT_DIR/cloudflare/terraform.tfvars" && \
   grep -q "enable_image_optimization = true" "$TEST_PROJECT_DIR/cloudflare/terraform.tfvars"; then
    echo -e "${GREEN}✓ Production Cloudflare config verified${NC}"
else
    echo -e "${RED}✗ Production Cloudflare config not found or incorrect${NC}"
    test_failed=true
fi

# Clean up
echo -e "${YELLOW}Cleaning up test environment...${NC}"
rm -rf "$TEST_PROJECT_DIR"

# Check if any test failed
if [ "$test_failed" = true ]; then
    echo -e "${RED}Environment switching test failed${NC}"
    exit 1
else
    echo -e "${GREEN}Environment switching test completed successfully${NC}"
fi

exit 0 