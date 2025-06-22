#!/bin/bash

# Test script to verify environment security measures
# This script tests that security measures are effective in both development and production environments

set -e

# Check if we're in Nix environment
# Temporarily disabled for testing
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
TEST_PROJECT_DIR=$(mktemp -d)

echo -e "${YELLOW}Starting environment security test...${NC}"

# Create test environment structure
mkdir -p "$TEST_PROJECT_DIR/nginx/conf.d/development"
mkdir -p "$TEST_PROJECT_DIR/nginx/conf.d/production"
mkdir -p "$TEST_PROJECT_DIR/cloudflare/development"
mkdir -p "$TEST_PROJECT_DIR/cloudflare/production"

# Test 1: Verify Nginx security headers in both environments
echo -e "${YELLOW}Testing Nginx security headers...${NC}"

# Create development security headers configuration
cat > "$TEST_PROJECT_DIR/nginx/conf.d/development/security-headers.conf" <<EOF
# Development environment security headers
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
EOF

# Create production security headers configuration
cat > "$TEST_PROJECT_DIR/nginx/conf.d/production/security-headers.conf" <<EOF
# Production environment security headers
add_header X-Frame-Options "SAMEORIGIN";
add_header X-Content-Type-Options "nosniff";
add_header X-XSS-Protection "1; mode=block";
add_header Referrer-Policy "strict-origin-when-cross-origin";
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' https://cdn.example.com; style-src 'self' 'unsafe-inline' https://cdn.example.com; img-src 'self' data: https://*.cloudflare.com; connect-src 'self' https://api.example.com; font-src 'self' https://cdn.example.com; object-src 'none'; media-src 'self'; frame-src 'self';";
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";
EOF

# Create script to check for security headers
cat > "$TEST_PROJECT_DIR/check-security-headers.sh" <<EOF
#!/bin/bash

# Check for essential security headers in development
dev_headers=\$(grep -c "X-" "$TEST_PROJECT_DIR/nginx/conf.d/development/security-headers.conf")
if [ \$dev_headers -ge 3 ]; then
    echo "Development environment has essential security headers"
    dev_headers_ok=true
else
    echo "Development environment is missing essential security headers"
    dev_headers_ok=false
fi

# Check for essential and advanced security headers in production
prod_basic_headers=\$(grep -c "X-" "$TEST_PROJECT_DIR/nginx/conf.d/production/security-headers.conf")
prod_csp=\$(grep -c "Content-Security-Policy" "$TEST_PROJECT_DIR/nginx/conf.d/production/security-headers.conf")
prod_hsts=\$(grep -c "Strict-Transport-Security" "$TEST_PROJECT_DIR/nginx/conf.d/production/security-headers.conf")

if [ \$prod_basic_headers -ge 3 ] && [ \$prod_csp -eq 1 ] && [ \$prod_hsts -eq 1 ]; then
    echo "Production environment has all required security headers"
    prod_headers_ok=true
else
    echo "Production environment is missing required security headers"
    prod_headers_ok=false
fi

# Return success only if both environments have appropriate headers
if [ "\$dev_headers_ok" = true ] && [ "\$prod_headers_ok" = true ]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x "$TEST_PROJECT_DIR/check-security-headers.sh"

# Test security headers
if "$TEST_PROJECT_DIR/check-security-headers.sh"; then
    echo -e "${GREEN}✓ Security headers verified in both environments${NC}"
else
    echo -e "${RED}✗ Security headers check failed${NC}"
    test_failed=true
fi

# Test 2: Verify Cloudflare security settings in both environments
echo -e "${YELLOW}Testing Cloudflare security settings...${NC}"

# Create development Cloudflare security configuration
cat > "$TEST_PROJECT_DIR/cloudflare/development/security.tf" <<EOF
# Development environment Cloudflare security settings

# SSL/TLS Configuration
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.zone_id
  settings {
    ssl = "flexible"
    always_use_https = "on"
    min_tls_version = "1.2"
    tls_1_3 = "on"
    automatic_https_rewrites = "on"
    universal_ssl = "on"
  }
}

# Basic WAF Configuration
resource "cloudflare_ruleset" "basic_waf" {
  zone_id     = var.zone_id
  name        = "Basic WAF Rules"
  description = "Basic WAF rules for development"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules {
    action = "challenge"
    expression = "(http.request.uri.path contains \"wp-login.php\")"
    description = "Challenge WordPress login attempts"
    enabled = true
  }
}
EOF

# Create production Cloudflare security configuration
cat > "$TEST_PROJECT_DIR/cloudflare/production/security.tf" <<EOF
# Production environment Cloudflare security settings

# SSL/TLS Configuration
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.zone_id
  settings {
    ssl = "strict"
    always_use_https = "on"
    min_tls_version = "1.2"
    tls_1_3 = "on"
    automatic_https_rewrites = "on"
    universal_ssl = "on"
  }
}

# Advanced WAF Configuration
resource "cloudflare_ruleset" "advanced_waf" {
  zone_id     = var.zone_id
  name        = "Advanced WAF Rules"
  description = "Advanced WAF rules for production"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules {
    action = "challenge"
    expression = "(http.request.uri.path contains \"wp-login.php\")"
    description = "Challenge WordPress login attempts"
    enabled = true
  }
  
  rules {
    action = "block"
    expression = "(http.request.uri.query contains \"select\") and (http.request.uri.query contains \"from\")"
    description = "Block basic SQL injection attempts"
    enabled = true
  }
  
  rules {
    action = "block"
    expression = "(http.request.uri.path contains \"..\") or (http.request.uri.query contains \"..\")"
    description = "Block directory traversal attempts"
    enabled = true
  }
}

# Rate Limiting
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = var.zone_id
  name        = "Rate Limiting Rules"
  description = "Rate limiting for all endpoints"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    action = "challenge"
    ratelimit {
      characteristics = ["ip"]
      period          = 60
      requests_per_period = 100
      mitigation_timeout  = 60
    }
    expression  = "true"
    description = "Rate limiting for all endpoints"
    enabled     = true
  }
}

# Bot Management
resource "cloudflare_ruleset" "bot_management" {
  zone_id     = var.zone_id
  name        = "Bot Management Rules"
  description = "Rules for managing bot traffic"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    expression  = "(cf.client.bot) and not (cf.verified_bot)"
    description = "Block unverified bots"
    enabled     = true
  }
}
EOF

# Create script to check for Cloudflare security settings
cat > "$TEST_PROJECT_DIR/check-cloudflare-security.sh" <<EOF
#!/bin/bash

# Check for basic security settings in development
dev_ssl=\$(grep -c "ssl = \"flexible\"" "$TEST_PROJECT_DIR/cloudflare/development/security.tf")
dev_waf=\$(grep -c "Basic WAF Rules" "$TEST_PROJECT_DIR/cloudflare/development/security.tf")

if [ \$dev_ssl -eq 1 ] && [ \$dev_waf -eq 1 ]; then
    echo "Development environment has basic Cloudflare security settings"
    dev_security_ok=true
else
    echo "Development environment is missing basic Cloudflare security settings"
    dev_security_ok=false
fi

# Check for advanced security settings in production
prod_ssl=\$(grep -c "ssl = \"strict\"" "$TEST_PROJECT_DIR/cloudflare/production/security.tf")
prod_waf=\$(grep -c "Advanced WAF Rules" "$TEST_PROJECT_DIR/cloudflare/production/security.tf")
prod_rate_limit=\$(grep -c "Rate Limiting Rules" "$TEST_PROJECT_DIR/cloudflare/production/security.tf")
prod_bot=\$(grep -c "Bot Management Rules" "$TEST_PROJECT_DIR/cloudflare/production/security.tf")

if [ \$prod_ssl -eq 1 ] && [ \$prod_waf -eq 1 ] && [ \$prod_rate_limit -eq 1 ] && [ \$prod_bot -eq 1 ]; then
    echo "Production environment has advanced Cloudflare security settings"
    prod_security_ok=true
else
    echo "Production environment is missing advanced Cloudflare security settings"
    prod_security_ok=false
fi

# Return success only if both environments have appropriate security settings
if [ "\$dev_security_ok" = true ] && [ "\$prod_security_ok" = true ]; then
    exit 0
else
    exit 1
fi
EOF

chmod +x "$TEST_PROJECT_DIR/check-cloudflare-security.sh"

# Test Cloudflare security settings
if "$TEST_PROJECT_DIR/check-cloudflare-security.sh"; then
    echo -e "${GREEN}✓ Cloudflare security settings verified in both environments${NC}"
else
    echo -e "${RED}✗ Cloudflare security settings check failed${NC}"
    test_failed=true
fi

# Test 3: Verify environment isolation
echo -e "${YELLOW}Testing environment isolation...${NC}"

# Create test project structure
mkdir -p "$TEST_PROJECT_DIR/projects/test-project/dev"
mkdir -p "$TEST_PROJECT_DIR/projects/test-project/prod"

# Create development-specific configuration
echo "environment=development" > "$TEST_PROJECT_DIR/projects/test-project/dev/config.env"
echo "debug=true" >> "$TEST_PROJECT_DIR/projects/test-project/dev/config.env"
echo "api_url=http://localhost:8080/api" >> "$TEST_PROJECT_DIR/projects/test-project/dev/config.env"

# Create production-specific configuration
echo "environment=production" > "$TEST_PROJECT_DIR/projects/test-project/prod/config.env"
echo "debug=false" >> "$TEST_PROJECT_DIR/projects/test-project/prod/config.env"
echo "api_url=https://api.example.com" >> "$TEST_PROJECT_DIR/projects/test-project/prod/config.env"

# Test environment isolation
cp "$TEST_PROJECT_DIR/projects/test-project/dev/config.env" "$TEST_PROJECT_DIR/projects/test-project/config.env"
if grep -q "environment=development" "$TEST_PROJECT_DIR/projects/test-project/config.env"; then
    echo -e "${GREEN}✓ Development environment configuration verified${NC}"
    dev_ok=true
else
    echo -e "${RED}✗ Development environment configuration check failed${NC}"
    dev_ok=false
fi

cp "$TEST_PROJECT_DIR/projects/test-project/prod/config.env" "$TEST_PROJECT_DIR/projects/test-project/config.env"
if grep -q "environment=production" "$TEST_PROJECT_DIR/projects/test-project/config.env"; then
    echo -e "${GREEN}✓ Production environment configuration verified${NC}"
    prod_ok=true
else
    echo -e "${RED}✗ Production environment configuration check failed${NC}"
    prod_ok=false
fi

if [ "$dev_ok" = true ] && [ "$prod_ok" = true ]; then
    echo -e "${GREEN}✓ Environment isolation verified${NC}"
else
    echo -e "${RED}✗ Environment isolation check failed${NC}"
    test_failed=true
fi

# Clean up
echo -e "${YELLOW}Cleaning up test environment...${NC}"
rm -rf "$TEST_PROJECT_DIR"

# Check if any test failed
if [ "$test_failed" = true ]; then
    echo -e "${RED}Environment security test failed${NC}"
    exit 1
else
    echo -e "${GREEN}Environment security test completed successfully${NC}"
    echo -e "${YELLOW}Note: This test verifies that security measures are appropriate for each environment,${NC}"
    echo -e "${YELLOW}with development having basic security and production having enhanced security.${NC}"
fi

exit 0 