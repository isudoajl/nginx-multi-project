#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROXY_DIR="${PROJECT_ROOT}/proxy"
DOCS_DIR="${PROJECT_ROOT}/docs"

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
}

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Validate the completeness of proxy documentation."
  echo ""
  echo "Options:"
  echo "  -d, --docs-dir DIR    Documentation directory (default: ../docs)"
  echo "  -v, --verbose         Show detailed validation results"
  echo "  -h, --help            Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --verbose"
  echo "  $0 --docs-dir /path/to/docs"
}

# Function: Parse arguments
function parse_arguments() {
  # Default values
  DOCS_DIR="${PROJECT_ROOT}/docs"
  VERBOSE=false
  
  while [[ "$#" -gt 0 ]]; do
    case $1 in
      -d|--docs-dir)
        DOCS_DIR="$2"
        shift 2
        ;;
      -v|--verbose)
        VERBOSE=true
        shift
        ;;
      -h|--help)
        display_help
        exit 0
        ;;
      *)
        echo "Unknown parameter: $1"
        display_help
        exit 1
        ;;
    esac
  done
}

# Function: Create docs directory if it doesn't exist
function create_docs_directory() {
  if [ ! -d "$DOCS_DIR" ]; then
    echo -e "${YELLOW}Documentation directory not found. Creating...${NC}"
    mkdir -p "$DOCS_DIR"
    mkdir -p "$DOCS_DIR/technical"
    mkdir -p "$DOCS_DIR/operational"
    mkdir -p "$DOCS_DIR/integration"
  fi
}

# Function: Check technical documentation
function check_technical_documentation() {
  echo "Checking technical documentation..."
  
  local missing_docs=0
  local tech_docs=(
    "proxy-architecture.md"
    "configuration-options.md"
    "networking-setup.md"
  )
  
  for doc in "${tech_docs[@]}"; do
    if [ -f "${DOCS_DIR}/technical/${doc}" ]; then
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ ${doc} exists${NC}"
      fi
    else
      echo -e "${RED}✗ Missing technical documentation: ${doc}${NC}"
      missing_docs=$((missing_docs+1))
    fi
  done
  
  return $missing_docs
}

# Function: Check operational documentation
function check_operational_documentation() {
  echo "Checking operational documentation..."
  
  local missing_docs=0
  local op_docs=(
    "proxy-management.md"
    "troubleshooting.md"
    "maintenance.md"
  )
  
  for doc in "${op_docs[@]}"; do
    if [ -f "${DOCS_DIR}/operational/${doc}" ]; then
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ ${doc} exists${NC}"
      fi
    else
      echo -e "${RED}✗ Missing operational documentation: ${doc}${NC}"
      missing_docs=$((missing_docs+1))
    fi
  done
  
  return $missing_docs
}

# Function: Check integration documentation
function check_integration_documentation() {
  echo "Checking integration documentation..."
  
  local missing_docs=0
  local int_docs=(
    "project-integration.md"
    "proxy-management-api.md"
    "integration-examples.md"
  )
  
  for doc in "${int_docs[@]}"; do
    if [ -f "${DOCS_DIR}/integration/${doc}" ]; then
      if [ "$VERBOSE" = true ]; then
        echo -e "${GREEN}✓ ${doc} exists${NC}"
      fi
    else
      echo -e "${RED}✗ Missing integration documentation: ${doc}${NC}"
      missing_docs=$((missing_docs+1))
    fi
  done
  
  return $missing_docs
}

# Function: Check documentation content
function check_documentation_content() {
  echo "Checking documentation content..."
  
  local content_issues=0
  
  # Check technical documentation content
  if [ -f "${DOCS_DIR}/technical/proxy-architecture.md" ]; then
    if ! grep -q "Nginx Proxy Architecture" "${DOCS_DIR}/technical/proxy-architecture.md"; then
      echo -e "${RED}✗ proxy-architecture.md is missing key content${NC}"
      content_issues=$((content_issues+1))
    fi
  fi
  
  if [ -f "${DOCS_DIR}/technical/configuration-options.md" ]; then
    if ! grep -q "Configuration Options" "${DOCS_DIR}/technical/configuration-options.md"; then
      echo -e "${RED}✗ configuration-options.md is missing key content${NC}"
      content_issues=$((content_issues+1))
    fi
  fi
  
  # Check operational documentation content
  if [ -f "${DOCS_DIR}/operational/troubleshooting.md" ]; then
    if ! grep -q "Troubleshooting" "${DOCS_DIR}/operational/troubleshooting.md"; then
      echo -e "${RED}✗ troubleshooting.md is missing key content${NC}"
      content_issues=$((content_issues+1))
    fi
  fi
  
  # Check integration documentation content
  if [ -f "${DOCS_DIR}/integration/project-integration.md" ]; then
    if ! grep -q "Project Integration" "${DOCS_DIR}/integration/project-integration.md"; then
      echo -e "${RED}✗ project-integration.md is missing key content${NC}"
      content_issues=$((content_issues+1))
    fi
  fi
  
  return $content_issues
}

# Function: Generate documentation template
function generate_documentation_template() {
  echo "Generating documentation templates..."
  
  # Create technical documentation templates
  mkdir -p "${DOCS_DIR}/technical"
  
  if [ ! -f "${DOCS_DIR}/technical/proxy-architecture.md" ]; then
    cat > "${DOCS_DIR}/technical/proxy-architecture.md" << EOF
# Nginx Proxy Architecture

## Overview
This document describes the architecture of the central Nginx proxy used in the microservices Nginx architecture.

## Components
- Main Nginx Configuration
- SSL/TLS Settings
- Security Headers
- Domain-specific Routing

## Directory Structure
\`\`\`
proxy/
├── docker-compose.yml
├── Dockerfile
├── nginx.conf                      # Main proxy config
└── conf.d/
    ├── ssl-settings.conf           # SSL/TLS configuration
    ├── security-headers.conf       # Security headers
    ├── cloudflare.conf             # Cloudflare IP allowlist
    └── domains/                    # Domain-specific routing
        ├── example.com.conf
        └── another-domain.com.conf
\`\`\`

## Network Architecture
The proxy container connects to each project's network to route traffic appropriately.

## Security Architecture
The proxy implements multiple layers of security:
- TLS termination
- DDoS protection
- Rate limiting
- IP filtering
- HTTP method restrictions
- Bad bot blocking
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/technical/configuration-options.md" ]; then
    cat > "${DOCS_DIR}/technical/configuration-options.md" << EOF
# Configuration Options

## Overview
This document describes the configuration options available for the Nginx proxy.

## Main Configuration (nginx.conf)
- Worker processes and connections
- Logging settings
- MIME types
- Compression settings
- Security settings
- Default server blocks

## SSL/TLS Configuration (ssl-settings.conf)
- SSL protocols
- Cipher suites
- Session settings
- OCSP stapling
- HSTS settings

## Security Headers (security-headers.conf)
- X-Frame-Options
- X-Content-Type-Options
- X-XSS-Protection
- Referrer-Policy
- Content-Security-Policy
- Permissions-Policy

## Domain Configuration (domains/*.conf)
- Server name
- SSL certificates
- Rate limiting
- Proxy settings
- Error handling
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/technical/networking-setup.md" ]; then
    cat > "${DOCS_DIR}/technical/networking-setup.md" << EOF
# Networking Setup

## Overview
This document describes the networking setup for the microservices Nginx architecture.

## Network Isolation
Each project runs in its own isolated network, with the proxy being the only component with access to all networks.

## Docker Compose Configuration
The proxy's docker-compose.yml file defines the networks:

\`\`\`yaml
networks:
  proxy-network:
    driver: bridge
  project-a-network:
    external: true
  project-b-network:
    external: true
  # Additional project networks as needed
\`\`\`

## Adding a New Project Network
When adding a new project, its network must be added to the proxy's docker-compose.yml file.

## Network Security
The network isolation ensures that projects cannot directly communicate with each other, enhancing security.
EOF
  fi
  
  # Create operational documentation templates
  mkdir -p "${DOCS_DIR}/operational"
  
  if [ ! -f "${DOCS_DIR}/operational/proxy-management.md" ]; then
    cat > "${DOCS_DIR}/operational/proxy-management.md" << EOF
# Proxy Management Guide

## Overview
This document provides instructions for managing the central Nginx proxy.

## Starting the Proxy
\`\`\`bash
cd proxy
docker-compose up -d
\`\`\`

## Stopping the Proxy
\`\`\`bash
cd proxy
docker-compose down
\`\`\`

## Reloading Configuration
\`\`\`bash
docker exec nginx-proxy nginx -s reload
\`\`\`

## Viewing Logs
\`\`\`bash
docker logs nginx-proxy
\`\`\`

## Monitoring
- Check container status: \`docker ps\`
- Check resource usage: \`docker stats nginx-proxy\`
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/operational/troubleshooting.md" ]; then
    cat > "${DOCS_DIR}/operational/troubleshooting.md" << EOF
# Troubleshooting

## Overview
This document provides troubleshooting procedures for common issues with the Nginx proxy.

## Common Issues

### 502 Bad Gateway
- Check if the project container is running
- Verify network connectivity between proxy and project container
- Check project container logs for errors

### SSL/TLS Certificate Issues
- Verify certificate paths in domain configuration
- Check certificate expiration dates
- Ensure certificate permissions are correct

### Configuration Syntax Errors
- Use \`docker exec nginx-proxy nginx -t\` to validate configuration
- Check error messages in logs
- Restore from backup if needed

## Diagnostic Commands
- \`docker logs nginx-proxy\`
- \`docker exec nginx-proxy nginx -t\`
- \`docker exec nginx-proxy cat /var/log/nginx/error.log\`
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/operational/maintenance.md" ]; then
    cat > "${DOCS_DIR}/operational/maintenance.md" << EOF
# Maintenance Guide

## Overview
This document provides maintenance procedures for the Nginx proxy.

## Routine Maintenance

### Certificate Renewal
- Check certificate expiration dates regularly
- Renew certificates before expiration
- Reload proxy configuration after renewal

### Configuration Backup
- Backup configuration files regularly
- Store backups securely
- Test restoration procedures

### Log Rotation
- Configure log rotation to prevent disk space issues
- Archive old logs for analysis
- Monitor log sizes

## Performance Optimization
- Use the \`optimize-proxy.sh\` script to optimize proxy performance
- Monitor resource usage during peak load
- Adjust settings based on real-world performance

## Security Updates
- Keep Nginx version updated
- Apply security patches promptly
- Review and update security headers regularly
EOF
  fi
  
  # Create integration documentation templates
  mkdir -p "${DOCS_DIR}/integration"
  
  if [ ! -f "${DOCS_DIR}/integration/project-integration.md" ]; then
    cat > "${DOCS_DIR}/integration/project-integration.md" << EOF
# Project Integration

## Overview
This document describes how to integrate new projects with the Nginx proxy.

## Project Requirements
- Docker container exposing an HTTP service
- Unique domain name
- Internal port number

## Integration Steps
1. Create project container with appropriate network
2. Add project to proxy using \`update-proxy.sh\`
3. Verify connectivity and functionality

## Example Integration
\`\`\`bash
# Create project network
docker network create my-project-network

# Start project container
docker run -d --name my-project --network my-project-network -p 8080:8080 my-project-image

# Add project to proxy
./scripts/update-proxy.sh --action add --name my-project --domain example.com --port 8080
\`\`\`

## Testing Integration
- Verify domain resolves to proxy
- Check SSL/TLS configuration
- Test application functionality
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/integration/proxy-management-api.md" ]; then
    cat > "${DOCS_DIR}/integration/proxy-management-api.md" << EOF
# Proxy Management API

## Overview
This document describes the API for managing the Nginx proxy.

## Script API

### update-proxy.sh
\`\`\`bash
./scripts/update-proxy.sh --action add --name my-project --domain example.com --port 8080
./scripts/update-proxy.sh --action remove --name my-project
./scripts/update-proxy.sh --action update --name my-project --domain example.com --port 8080
\`\`\`

### optimize-proxy.sh
\`\`\`bash
./scripts/optimize-proxy.sh --cpu 4 --memory 2048 --level 2
\`\`\`

## Docker API
The proxy can also be managed using standard Docker commands:

\`\`\`bash
docker exec nginx-proxy nginx -s reload
docker logs nginx-proxy
docker restart nginx-proxy
\`\`\`

## Configuration Files
Projects can also interact with the proxy by modifying configuration files:

- Add domain configuration to \`proxy/conf.d/domains/\`
- Update docker-compose.yml to add network connections
EOF
  fi
  
  if [ ! -f "${DOCS_DIR}/integration/integration-examples.md" ]; then
    cat > "${DOCS_DIR}/integration/integration-examples.md" << EOF
# Integration Examples

## Overview
This document provides examples of integrating various types of projects with the Nginx proxy.

## Example 1: Static Website
\`\`\`bash
# Create project
mkdir -p projects/static-site/html
echo "<h1>Hello World</h1>" > projects/static-site/html/index.html

# Create Dockerfile
cat > projects/static-site/Dockerfile << EOL
FROM nginx:alpine
COPY html /usr/share/nginx/html
EOL

# Create docker-compose.yml
cat > projects/static-site/docker-compose.yml << EOL
version: '3.8'
services:
  static-site:
    build: .
    container_name: static-site_container
    networks:
      - static-site-network
networks:
  static-site-network:
    name: static-site-network
EOL

# Start project
cd projects/static-site
docker-compose up -d

# Add to proxy
./scripts/update-proxy.sh --action add --name static-site --domain static.example.com --port 80
\`\`\`

## Example 2: Node.js Application
\`\`\`bash
# Add to proxy
./scripts/update-proxy.sh --action add --name nodejs-app --domain app.example.com --port 3000
\`\`\`

## Example 3: Python Flask Application
\`\`\`bash
# Add to proxy
./scripts/update-proxy.sh --action add --name flask-app --domain flask.example.com --port 5000
\`\`\`
EOF
  fi
  
  echo -e "${GREEN}Documentation templates generated in ${DOCS_DIR}${NC}"
}

# Function: Generate summary report
function generate_summary_report() {
  local tech_missing=$1
  local op_missing=$2
  local int_missing=$3
  local content_issues=$4
  
  local total_missing=$((tech_missing + op_missing + int_missing))
  local total_docs=9
  local completion_percentage=$(( (total_docs - total_missing) * 100 / total_docs ))
  
  echo ""
  echo "Documentation Validation Summary:"
  echo "--------------------------------"
  echo "Technical Documentation: $((3 - tech_missing))/3 files present"
  echo "Operational Documentation: $((3 - op_missing))/3 files present"
  echo "Integration Documentation: $((3 - int_missing))/3 files present"
  echo "Content Issues: $content_issues"
  echo ""
  echo "Overall Completion: $completion_percentage%"
  
  if [ $total_missing -eq 0 ] && [ $content_issues -eq 0 ]; then
    echo -e "${GREEN}Documentation is complete!${NC}"
    return 0
  elif [ $completion_percentage -ge 80 ]; then
    echo -e "${YELLOW}Documentation is mostly complete but has some gaps.${NC}"
    return 1
  else
    echo -e "${RED}Documentation has significant gaps.${NC}"
    return 2
  fi
}

# Main script execution
check_environment
parse_arguments "$@"
create_docs_directory

tech_missing=0
op_missing=0
int_missing=0
content_issues=0

check_technical_documentation
tech_missing=$?

check_operational_documentation
op_missing=$?

check_integration_documentation
int_missing=$?

if [ $tech_missing -eq 0 ] && [ $op_missing -eq 0 ] && [ $int_missing -eq 0 ]; then
  check_documentation_content
  content_issues=$?
fi

total_missing=$((tech_missing + op_missing + int_missing))

if [ $total_missing -gt 0 ] || [ $content_issues -gt 0 ]; then
  echo ""
  echo -e "${YELLOW}Documentation is incomplete. Generating templates...${NC}"
  generate_documentation_template
fi

generate_summary_report $tech_missing $op_missing $int_missing $content_issues
exit_code=$?

exit $exit_code