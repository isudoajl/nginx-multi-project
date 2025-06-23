# Script Automation Specification

## Overview
This document specifies the automation scripts that will be used to create, manage, and deploy the microservices Nginx architecture. These scripts will simplify the process of creating new project containers, configuring the central proxy, and managing the overall infrastructure.

## Core Script: `create-project.sh`

### Purpose
The main script that creates a new project container with all necessary configuration files.

### Input Parameters
1. **Project Name** (`--name`, `-n`)
   - Alphanumeric with hyphens allowed
   - Required
   - Validation: `^[a-zA-Z0-9-]+$`

2. **Port** (`--port`, `-p`)
   - Internal container port
   - Required
   - Validation: 1024-65535, uniqueness check

3. **Domain Name** (`--domain`, `-d`)
   - Valid FQDN format
   - Required
   - Validation: `^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$`

4. **Frontend Location** (`--frontend`, `-f`)
   - Path to static files
   - Optional
   - Default: `./projects/{project_name}/html`

5. **SSL Certificate Paths** (`--cert`, `-c` and `--key`, `-k`)
   - Private Key and Certificate paths
   - Optional
   - Defaults:
     - Private Key: `/etc/ssl/certs/private/cert-key.pem`
     - Certificate: `/etc/ssl/certs/cert.pem`

6. **Environment Type** (`--env`, `-e`)
   - DEV or PRO
   - Optional
   - Default: DEV

7. **Cloudflare Integration** (PRO only)
   - API Token (`--cf-token`)
   - Account ID (`--cf-account`)
   - Zone ID (`--cf-zone`)
   - Optional for PRO environment

### Script Structure

```bash
#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE_DIR="${SCRIPT_DIR}/conf"
PROXY_DIR="${SCRIPT_DIR}/proxy"
PROJECTS_DIR="${SCRIPT_DIR}/projects"

# Function: Display help
function display_help() {
  # Help text
}

# Function: Validate inputs
function validate_inputs() {
  # Input validation logic
}

# Function: Check environment
function check_environment() {
  # Verify Nix environment
  # Check Podman/Docker availability
}

# Function: Check proxy status (Enhanced 2025-06-23)
function check_proxy() {
  # Intelligent proxy state detection:
  # - Missing: Create complete proxy infrastructure
  # - Stopped: Start existing proxy container
  # - Running: Verify health and proceed
  # - Corrupted: Clean up and recreate
}

# Function: Generate project files
function generate_project_files() {
  # Create project directory structure
  # Generate configuration files from templates
}

# Function: Configure development environment
function configure_dev_environment() {
  # Generate self-signed certificates
  # Configure for localhost testing
}

# Function: Configure production environment
function configure_pro_environment() {
  # Configure Cloudflare integration
  # Set up production settings
}

# Function: Deploy project container (Enhanced 2025-06-23)
function deploy_project() {
  # Build and start the project container
  # Create isolated project network
  # Connect to shared proxy network
  # Update proxy configuration with zero-downtime
  # Reload proxy configuration using hot reload
}

# Function: Verify deployment (Enhanced 2025-06-23)
function verify_deployment() {
  # Check container status and health
  # Verify proxy → project connectivity
  # Test external HTTP/HTTPS routing
  # Validate network isolation
  # Verify existing projects remain untouched
  # Comprehensive integration testing
}

# Main script execution
parse_arguments "$@"
validate_inputs
check_environment
check_proxy
generate_project_files

if [[ "$ENV_TYPE" == "DEV" ]]; then
  configure_dev_environment
else
  configure_pro_environment
fi

deploy_project
verify_deployment

echo "Project $PROJECT_NAME successfully created and deployed!"
```

## Support Script: `update-proxy.sh`

### Purpose
Updates the central proxy configuration when a new project is added or an existing project is modified.

### Input Parameters
1. **Action** (`--action`, `-a`)
   - add, remove, or update
   - Required

2. **Project Name** (`--name`, `-n`)
   - Name of the project to add, remove, or update
   - Required

### Script Structure

```bash
#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROXY_DIR="${SCRIPT_DIR}/proxy"
PROXY_DOMAINS_DIR="${PROXY_DIR}/conf.d/domains"

# Function: Add project to proxy
function add_project() {
  # Generate domain configuration file
  # Add network to docker-compose.yml
}

# Function: Remove project from proxy
function remove_project() {
  # Remove domain configuration file
  # Remove network from docker-compose.yml
}

# Function: Update project in proxy
function update_project() {
  # Update domain configuration file
}

# Function: Reload proxy configuration
function reload_proxy() {
  # Reload Nginx configuration without downtime
}

# Main script execution
parse_arguments "$@"

case "$ACTION" in
  add)
    add_project
    ;;
  remove)
    remove_project
    ;;
  update)
    update_project
    ;;
  *)
    echo "Invalid action: $ACTION"
    exit 1
    ;;
esac

reload_proxy
echo "Proxy configuration updated for project $PROJECT_NAME!"
```

## Advanced Features (Implemented 2025-06-23)

### Incremental Deployment System

The enhanced `create-project.sh` script now supports intelligent incremental deployment, allowing new projects to be added to existing ecosystems without disrupting running services.

#### Key Functions

1. **`check_proxy()`** - Intelligent Proxy Detection
   - Detects proxy container state (missing/stopped/running/corrupted)
   - Automatically creates proxy infrastructure when missing
   - Starts stopped proxy containers
   - Validates proxy health before proceeding

2. **`create_proxy_infrastructure()`** - Self-Healing Infrastructure
   - Creates complete proxy from scratch when needed
   - Generates fallback SSL certificates
   - Sets up proxy networks and configurations
   - Ensures proxy is ready for project integration

3. **`verify_proxy_health()`** - Comprehensive Health Checks
   - Validates proxy container status
   - Tests proxy configuration syntax
   - Verifies network connectivity
   - Ensures proxy is ready for new projects

4. **`integrate_with_proxy()`** - Zero-Downtime Integration
   - Generates SSL certificates for new domains
   - Creates domain configuration files
   - Hot-reloads proxy configuration without downtime
   - Connects new projects to shared proxy network

#### Deployment Modes

**Mode 1: From-Scratch Deployment**
- Detects no proxy exists
- Creates complete proxy infrastructure
- Deploys first project with full setup

**Mode 2: Incremental Deployment**
- Detects existing proxy and projects
- Preserves existing ecosystem completely
- Adds new project without disruption
- Validates existing projects remain functional

#### Validation System

The script performs comprehensive validation:
- **Container Health**: All containers running and responsive
- **Network Connectivity**: Proxy can reach all projects
- **External Routing**: HTTP/HTTPS routing works correctly
- **Security Consistency**: All security headers properly configured
- **Ecosystem Preservation**: Existing projects remain untouched

## Support Script: `generate-certs.sh`

### Purpose
Generates self-signed certificates for development environments or prepares production certificates.

### Input Parameters
1. **Domain Name** (`--domain`, `-d`)
   - Domain for the certificate
   - Required

2. **Output Directory** (`--output`, `-o`)
   - Where to save the certificates
   - Required

3. **Environment Type** (`--env`, `-e`)
   - DEV or PRO
   - Optional
   - Default: DEV

### Script Structure

```bash
#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function: Generate self-signed certificate
function generate_self_signed() {
  # Generate self-signed certificate with OpenSSL
}

# Function: Prepare for production certificate
function prepare_production() {
  # Generate CSR for production certificate
  # Provide instructions for obtaining a real certificate
}

# Main script execution
parse_arguments "$@"

if [[ "$ENV_TYPE" == "DEV" ]]; then
  generate_self_signed
else
  prepare_production
fi

echo "Certificate generation complete!"
```

## Support Script: `setup-cloudflare.sh`

### Purpose
Sets up Cloudflare integration for a project in production environment.

### Input Parameters
1. **Project Name** (`--name`, `-n`)
   - Name of the project
   - Required

2. **Domain Name** (`--domain`, `-d`)
   - Domain name for Cloudflare
   - Required

3. **API Token** (`--token`, `-t`)
   - Cloudflare API token
   - Required

4. **Account ID** (`--account`, `-a`)
   - Cloudflare account ID
   - Optional

5. **Zone ID** (`--zone`, `-z`)
   - Cloudflare zone ID
   - Optional

### Script Structure

```bash
#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECTS_DIR="${SCRIPT_DIR}/projects"

# Function: Setup Terraform configuration
function setup_terraform() {
  # Create Terraform configuration files
  # Initialize Terraform
}

# Function: Apply Terraform configuration
function apply_terraform() {
  # Run Terraform plan and apply
}

# Function: Verify Cloudflare setup
function verify_cloudflare() {
  # Check DNS records
  # Verify SSL/TLS settings
}

# Main script execution
parse_arguments "$@"
setup_terraform
apply_terraform
verify_cloudflare

echo "Cloudflare setup complete for project $PROJECT_NAME!"
```

## Template Files

### Nginx Proxy Template (`conf/nginx-proxy-template.conf`)
Base configuration for the central Nginx proxy.

### Nginx Server Template (`conf/nginx-server-template.conf`)
Base configuration for individual project Nginx servers.

### Domain Template (`conf/domain-template.conf`)
Template for domain-specific routing in the proxy.

### Security Headers Template (`conf/security-headers.conf`)
Reusable security headers configuration.

### SSL Settings Template (`conf/ssl-settings.conf`)
SSL/TLS best practices configuration.

### Docker Compose Template (`conf/docker-compose-template.yml`)
Template for project-specific Docker Compose files.

### Dockerfile Template (`conf/dockerfile-template`)
Template for project-specific Dockerfiles.

## Template Variables

The following variables will be replaced in the templates:

- `{{PROJECT_NAME}}` - Name of the project
- `{{DOMAIN_NAME}}` - Domain name for the project
- `{{PORT}}` - Internal container port
- `{{CERT_PATH}}` - Path to SSL certificate
- `{{CERT_KEY_PATH}}` - Path to SSL certificate key
- `{{FRONTEND_PATH}}` - Path to static frontend files
- `{{ENV_TYPE}}` - Environment type (DEV or PRO)

## Script Execution Flow

1. **User Invokes `create-project.sh`**
   ```bash
   ./create-project.sh -n my-project -p 8080 -d example.com -e PRO
   ```

2. **Script Validates Inputs**
   - Checks project name format
   - Verifies port availability
   - Validates domain name format

3. **Script Checks Environment**
   - Verifies Nix environment
   - Checks Podman/Docker availability

4. **Script Checks Proxy Status**
   - If proxy doesn't exist: Creates proxy infrastructure
   - If proxy exists but stopped: Starts the proxy
   - If proxy is running: Continues to project creation

5. **Script Generates Project Files**
   - Creates project directory structure
   - Generates configuration files from templates

6. **Script Configures Environment**
   - DEV: Generates self-signed certificates
   - PRO: Sets up Cloudflare integration

7. **Script Deploys Project**
   - Builds and starts project container
   - Updates proxy configuration
   - Reloads proxy configuration

8. **Script Verifies Deployment**
   - Checks container status
   - Verifies connectivity

## Error Handling

1. **Input Validation Errors**
   - Display specific error message
   - Show correct format
   - Exit with status code 1

2. **Environment Check Errors**
   - Display requirements
   - Provide installation instructions
   - Exit with status code 2

3. **Deployment Errors**
   - Display error details
   - Attempt cleanup
   - Provide troubleshooting steps
   - Exit with status code 3

4. **Verification Errors**
   - Display verification failure details
   - Suggest manual checks
   - Exit with status code 4

## Logging

All scripts will log their actions to:

1. **Console** - For interactive feedback
2. **Log File** - For detailed debugging
   - Location: `./logs/script-{timestamp}.log`
   - Format: `[TIMESTAMP] [LEVEL] [SCRIPT] Message`

## Script Testing

Each script will include a `--test` flag that performs a dry run:

- Validates inputs
- Shows what would be created/modified
- Doesn't make actual changes

This specification provides a comprehensive guide for implementing the automation scripts that will manage the microservices Nginx architecture. These scripts will simplify the process of creating, configuring, and deploying project containers and the central proxy. 