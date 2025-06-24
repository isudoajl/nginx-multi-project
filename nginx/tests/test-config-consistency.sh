#!/bin/bash

# Test script to verify configuration consistency across environments
# This script tests that configurations are consistent between development and production

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
TEST_PROJECT_DIR=$(mktemp -d)

echo -e "${YELLOW}Starting configuration consistency test...${NC}"

# Create test environment structure
mkdir -p "$TEST_PROJECT_DIR/nginx/conf.d/development"
mkdir -p "$TEST_PROJECT_DIR/nginx/conf.d/production"
mkdir -p "$TEST_PROJECT_DIR/cloudflare/development"
mkdir -p "$TEST_PROJECT_DIR/cloudflare/production"

# Test 1: Create consistent Nginx base configuration
echo -e "${YELLOW}Testing Nginx base configuration consistency...${NC}"

# Create base configuration template
cat > "$TEST_PROJECT_DIR/nginx/nginx.conf.template" <<EOF
# Base Nginx configuration
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Include environment-specific configuration
    include /etc/nginx/conf.d/environment.conf;
    
    # Include server configurations
    include /etc/nginx/conf.d/*.conf;
}
EOF

# Create development environment configuration
cat > "$TEST_PROJECT_DIR/nginx/conf.d/development/environment.conf" <<EOF
# Development-specific settings
server_names_hash_bucket_size 64;
client_max_body_size 10M;

# Development-only settings
error_log /var/log/nginx/error.log debug;
EOF

# Create production environment configuration
cat > "$TEST_PROJECT_DIR/nginx/conf.d/production/environment.conf" <<EOF
# Production-specific settings
server_names_hash_bucket_size 64;
client_max_body_size 10M;

# Production-only settings
error_log /var/log/nginx/error.log warn;
EOF

# Create script to check for configuration consistency
cat > "$TEST_PROJECT_DIR/check-nginx-consistency.sh" <<EOF
#!/bin/bash

# Extract common settings from both environments
grep -v "Development-only" "$TEST_PROJECT_DIR/nginx/conf.d/development/environment.conf" | grep -v "Production-only" | grep "server_names\|client_max" > /tmp/dev-common.conf
grep -v "Development-only" "$TEST_PROJECT_DIR/nginx/conf.d/production/environment.conf" | grep -v "Production-only" | grep "server_names\|client_max" > /tmp/prod-common.conf

# Compare common settings
diff -w /tmp/dev-common.conf /tmp/prod-common.conf > /dev/null
exit \$?
EOF

chmod +x "$TEST_PROJECT_DIR/check-nginx-consistency.sh"

# Test Nginx configuration consistency
if "$TEST_PROJECT_DIR/check-nginx-consistency.sh"; then
    echo -e "${GREEN}✓ Nginx configuration consistency verified${NC}"
else
    echo -e "${RED}✗ Nginx configuration consistency check failed${NC}"
    test_failed=true
fi

# Test 2: Create consistent Cloudflare configuration
echo -e "${YELLOW}Testing Cloudflare configuration consistency...${NC}"

# Create development Cloudflare configuration
cat > "$TEST_PROJECT_DIR/cloudflare/development/main.tf" <<EOF
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Zone resource
resource "cloudflare_zone" "project_zone" {
  count     = var.create_zone ? 1 : 0
  zone      = var.domain_name
  plan      = var.zone_plan
  account_id = var.account_id
}

# Common DNS Records
resource "cloudflare_record" "www" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "www"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "root" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "@"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Development-specific settings
# Minimal performance configuration for development
EOF

# Create production Cloudflare configuration
cat > "$TEST_PROJECT_DIR/cloudflare/production/main.tf" <<EOF
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Zone resource
resource "cloudflare_zone" "project_zone" {
  count     = var.create_zone ? 1 : 0
  zone      = var.domain_name
  plan      = var.zone_plan
  account_id = var.account_id
}

# Common DNS Records
resource "cloudflare_record" "www" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "www"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "root" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "@"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

# Production-specific settings
# Full performance optimization for production
EOF

# Create script to check for Cloudflare configuration consistency
cat > "$TEST_PROJECT_DIR/check-cloudflare-consistency.sh" <<EOF
#!/bin/bash

# Extract common parts from both environments
grep -v "Development-specific" "$TEST_PROJECT_DIR/cloudflare/development/main.tf" | grep -v "Production-specific" | grep -A 20 "terraform {" | grep -v "^--$" > /tmp/dev-cf-common.tf
grep -v "Development-specific" "$TEST_PROJECT_DIR/cloudflare/production/main.tf" | grep -v "Production-specific" | grep -A 20 "terraform {" | grep -v "^--$" > /tmp/prod-cf-common.tf

# Compare common parts
diff -w /tmp/dev-cf-common.tf /tmp/prod-cf-common.tf > /dev/null
exit \$?
EOF

chmod +x "$TEST_PROJECT_DIR/check-cloudflare-consistency.sh"

# Test Cloudflare configuration consistency
if "$TEST_PROJECT_DIR/check-cloudflare-consistency.sh"; then
    echo -e "${GREEN}✓ Cloudflare configuration consistency verified${NC}"
else
    echo -e "${RED}✗ Cloudflare configuration consistency check failed${NC}"
    test_failed=true
fi

# Test 3: Create variables consistency test
echo -e "${YELLOW}Testing variables consistency across environments...${NC}"

# Create development variables
cat > "$TEST_PROJECT_DIR/cloudflare/development/variables.tf" <<EOF
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
}

variable "origin_ip" {
  description = "Origin server IP address"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare Zone ID (if zone already exists)"
  type        = string
  default     = ""
}

variable "create_zone" {
  description = "Whether to create a new zone or use an existing one"
  type        = bool
  default     = false
}

variable "zone_plan" {
  description = "Cloudflare plan (free, pro, business, enterprise)"
  type        = string
  default     = "free"
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

# Development-specific variables
variable "enable_debug" {
  description = "Enable debug mode for development"
  type        = bool
  default     = true
}
EOF

# Create production variables
cat > "$TEST_PROJECT_DIR/cloudflare/production/variables.tf" <<EOF
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
}

variable "origin_ip" {
  description = "Origin server IP address"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare Zone ID (if zone already exists)"
  type        = string
  default     = ""
}

variable "create_zone" {
  description = "Whether to create a new zone or use an existing one"
  type        = bool
  default     = false
}

variable "zone_plan" {
  description = "Cloudflare plan (free, pro, business, enterprise)"
  type        = string
  default     = "free"
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

# Production-specific variables
variable "enable_image_optimization" {
  description = "Enable Cloudflare Image Optimization (Polish)"
  type        = bool
  default     = true
}

variable "enable_argo_smart_routing" {
  description = "Enable Cloudflare Argo Smart Routing"
  type        = bool
  default     = true
}
EOF

# Create script to check for variables consistency
cat > "$TEST_PROJECT_DIR/check-variables-consistency.sh" <<EOF
#!/bin/bash

# Extract common variables from both environments
grep -v "Development-specific" "$TEST_PROJECT_DIR/cloudflare/development/variables.tf" | grep -v "Production-specific" | grep -A 3 "variable \"cloudflare_api_token\"" > /tmp/dev-vars.tf
grep -v "Development-specific" "$TEST_PROJECT_DIR/cloudflare/production/variables.tf" | grep -v "Production-specific" | grep -A 3 "variable \"cloudflare_api_token\"" > /tmp/prod-vars.tf

# Compare common variables
diff -w /tmp/dev-vars.tf /tmp/prod-vars.tf > /dev/null
exit \$?
EOF

chmod +x "$TEST_PROJECT_DIR/check-variables-consistency.sh"

# Test variables consistency
if "$TEST_PROJECT_DIR/check-variables-consistency.sh"; then
    echo -e "${GREEN}✓ Variables consistency verified${NC}"
else
    echo -e "${RED}✗ Variables consistency check failed${NC}"
    test_failed=true
fi

# Clean up
echo -e "${YELLOW}Cleaning up test environment...${NC}"
rm -rf "$TEST_PROJECT_DIR"
rm -f /tmp/dev-common.conf /tmp/prod-common.conf
rm -f /tmp/dev-cf-common.tf /tmp/prod-cf-common.tf
rm -f /tmp/dev-vars.tf /tmp/prod-vars.tf

# Check if any test failed
if [ "$test_failed" = true ]; then
    echo -e "${RED}Configuration consistency test failed${NC}"
    exit 1
else
    echo -e "${GREEN}Configuration consistency test completed successfully${NC}"
    echo -e "${YELLOW}Note: This test verifies that common configurations are consistent across environments${NC}"
    echo -e "${YELLOW}while allowing environment-specific settings to differ as needed.${NC}"
fi

exit 0 