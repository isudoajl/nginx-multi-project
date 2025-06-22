#!/bin/bash

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
LOG_FILE="${SCRIPT_DIR}/logs/create-project.log"
TEMPLATE_DIR="${PROJECT_ROOT}/conf"
PROJECTS_DIR="${PROJECT_ROOT}/projects"

# Create logs directory if it doesn't exist
mkdir -p "${SCRIPT_DIR}/logs"
mkdir -p "${PROJECTS_DIR}"

# Function: Display help
function display_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "Create a new project container with all necessary configuration files."
  echo ""
  echo "Options:"
  echo "  --name, -n NAME          Project name (required, alphanumeric with hyphens)"
  echo "  --port, -p PORT          Internal container port (required, 1024-65535)"
  echo "  --domain, -d DOMAIN      Domain name (required, valid FQDN format)"
  echo "  --frontend, -f DIR       Path to static files (optional, default: ./projects/{project_name}/html)"
  echo "  --cert, -c FILE          Path to SSL certificate (optional)"
  echo "  --key, -k FILE           Path to SSL private key (optional)"
  echo "  --env, -e ENV            Environment type: DEV or PRO (optional, default: DEV)"
  echo "  --cf-token TOKEN         Cloudflare API token (PRO only)"
  echo "  --cf-account ID          Cloudflare account ID (PRO only)"
  echo "  --cf-zone ID             Cloudflare zone ID (PRO only)"
  echo "  --help, -h               Display this help message"
  echo ""
  echo "Examples:"
  echo "  $0 --name my-project --port 8080 --domain example.com"
  echo "  $0 -n my-project -p 8080 -d example.com -e DEV"
  echo "  $0 -n my-project -p 8080 -d example.com -e PRO --cf-token xxx --cf-account xxx --cf-zone xxx"
}

# Function: Log messages
function log() {
  local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Function: Handle errors
function handle_error() {
  log "ERROR: $1"
  exit 1
}

# Function: Validate environment
function validate_environment() {
  # Check if we're in Nix environment
  if [ -z "$IN_NIX_SHELL" ]; then
    handle_error "Please enter Nix environment with 'nix develop' first"
  fi
  
  # Check if Docker/Podman is installed
  if ! command -v docker &> /dev/null && ! command -v podman &> /dev/null; then
    handle_error "Neither Docker nor Podman is installed. Please install one of them and try again."
  fi
  
  # Determine which container engine to use
  if command -v podman &> /dev/null; then
    CONTAINER_ENGINE="podman"
  else
    CONTAINER_ENGINE="docker"
  fi
  log "Using container engine: $CONTAINER_ENGINE"
}

# Function: Parse arguments
function parse_arguments() {
  PROJECT_NAME=""
  PROJECT_PORT=""
  DOMAIN_NAME=""
  FRONTEND_DIR=""
  CERT_PATH=""
  KEY_PATH=""
  ENV_TYPE="DEV"
  CF_TOKEN=""
  CF_ACCOUNT=""
  CF_ZONE=""

  while [[ $# -gt 0 ]]; do
    case $1 in
      --name|-n)
        PROJECT_NAME="$2"
        shift 2
        ;;
      --port|-p)
        PROJECT_PORT="$2"
        shift 2
        ;;
      --domain|-d)
        DOMAIN_NAME="$2"
        shift 2
        ;;
      --frontend|-f)
        FRONTEND_DIR="$2"
        shift 2
        ;;
      --cert|-c)
        CERT_PATH="$2"
        shift 2
        ;;
      --key|-k)
        KEY_PATH="$2"
        shift 2
        ;;
      --env|-e)
        ENV_TYPE="$2"
        shift 2
        ;;
      --cf-token)
        CF_TOKEN="$2"
        shift 2
        ;;
      --cf-account)
        CF_ACCOUNT="$2"
        shift 2
        ;;
      --cf-zone)
        CF_ZONE="$2"
        shift 2
        ;;
      --help|-h)
        display_help
        exit 0
        ;;
      *)
        handle_error "Unknown parameter: $1"
        ;;
    esac
  done

  # Validate required parameters
  if [[ -z "$PROJECT_NAME" ]]; then
    handle_error "Project name is required. Use --name or -n to specify."
  fi

  if [[ -z "$PROJECT_PORT" ]]; then
    handle_error "Port is required. Use --port or -p to specify."
  fi

  if [[ -z "$DOMAIN_NAME" ]]; then
    handle_error "Domain name is required. Use --domain or -d to specify."
  fi

  # Validate project name format
  if ! [[ "$PROJECT_NAME" =~ ^[a-zA-Z0-9-]+$ ]]; then
    handle_error "Invalid project name format: $PROJECT_NAME. Use only alphanumeric characters and hyphens."
  fi

  # Validate port number
  if ! [[ "$PROJECT_PORT" =~ ^[0-9]+$ ]] || [ "$PROJECT_PORT" -lt 1024 ] || [ "$PROJECT_PORT" -gt 65535 ]; then
    handle_error "Invalid port number: $PROJECT_PORT. Must be between 1024 and 65535."
  fi

  # Validate domain format
  if ! [[ "$DOMAIN_NAME" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    handle_error "Invalid domain format: $DOMAIN_NAME"
  fi

  # Validate environment type
  if [[ "$ENV_TYPE" != "DEV" && "$ENV_TYPE" != "PRO" ]]; then
    handle_error "Environment type must be either DEV or PRO."
  fi

  # Validate Cloudflare parameters for PRO environment
  if [[ "$ENV_TYPE" == "PRO" ]]; then
    if [[ -z "$CF_TOKEN" || -z "$CF_ACCOUNT" || -z "$CF_ZONE" ]]; then
      log "WARNING: Cloudflare parameters not provided for PRO environment. Cloudflare integration will be skipped."
    fi
  fi

  # Set default frontend directory if not specified
  if [[ -z "$FRONTEND_DIR" ]]; then
    FRONTEND_DIR="${PROJECTS_DIR}/${PROJECT_NAME}/html"
  fi

  # Set default certificate paths if not specified
  if [[ -z "$CERT_PATH" ]]; then
    CERT_PATH="/etc/ssl/certs/cert.pem"
  fi

  if [[ -z "$KEY_PATH" ]]; then
    KEY_PATH="/etc/ssl/certs/private/cert-key.pem"
  fi
}

# Function: Check proxy status
function check_proxy() {
  log "Checking proxy status..."
  
  # This is a stub for now - will be implemented in integration phase
  log "Proxy check is currently a stub and will be implemented in the integration phase."
}

# Function: Generate project files
function generate_project_files() {
  log "Generating project files for $PROJECT_NAME..."
  
  # Create project directory
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  mkdir -p "$project_dir" || handle_error "Failed to create project directory: $project_dir"
  
  # Create subdirectories
  mkdir -p "${project_dir}/html" || handle_error "Failed to create html directory"
  mkdir -p "${project_dir}/conf.d" || handle_error "Failed to create conf.d directory"
  mkdir -p "${project_dir}/logs" || handle_error "Failed to create logs directory"
  
  # Create Dockerfile
  log "Creating Dockerfile..."
  cat > "${project_dir}/Dockerfile" << EOF
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl

# Create nginx user
RUN adduser -D -H -u 1000 -s /sbin/nologin nginx

# Create required directories
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /usr/share/nginx/html \\
    && mkdir -p /var/log/nginx

# Set permissions
RUN chown -R nginx:nginx /var/log/nginx \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1

# Switch to non-root user
USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

  # Create docker-compose.yml
  log "Creating docker-compose.yml..."
  cat > "${project_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${PROJECT_NAME}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./html:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - ${PROJECT_NAME}-network
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DOMAIN_NAME=${DOMAIN_NAME}

networks:
  ${PROJECT_NAME}-network:
    driver: bridge
EOF

  # Create nginx.conf
  log "Creating nginx.conf..."
  cat > "${project_dir}/nginx.conf" << EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                      '\$status \$body_bytes_sent "\$http_referer" '
                      '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;

    keepalive_timeout  65;

    # Include additional configurations
    include /etc/nginx/conf.d/*.conf;

    # Default server
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';" always;
        add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()" always;

        # Static files handling
        location / {
            try_files \$uri \$uri/ =404;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|otf|eot|mp4)$ {
            expires max;
            log_not_found off;
        }

        # Custom error pages
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }
}
EOF

  # Create security.conf
  log "Creating security configuration..."
  cat > "${project_dir}/conf.d/security.conf" << EOF
# Security settings
# Rate limiting zone - limits clients to 10 requests per second
limit_req_zone \$binary_remote_addr zone=projectlimit:10m rate=10r/s;
limit_conn_zone \$binary_remote_addr zone=projectconn:10m;

# Apply rate limiting to all locations
limit_req zone=projectlimit burst=20 nodelay;
limit_conn projectconn 20;

# Block common malicious bot user agents
map \$http_user_agent \$bad_bot {
    default 0;
    ~*(nmap|nikto|sqlmap|arachni|dirbuster|gobuster|w3af|nessus|masscan|ZmEu|zgrab) 1;
    ~*(python-requests|python-urllib|python-httpx|go-http-client|curl|wget) 1;
    "" 1; # Empty user agent
}

# Block requests with unusual HTTP methods
map \$request_method \$method_allowed {
    default 1;
    ~*(TRACE|TRACK|DEBUG) 0;
}

# Return 444 for bad bots and unusual methods
if (\$bad_bot = 1) {
    return 444;
}

if (\$method_allowed = 0) {
    return 444;
}

# Block WordPress and common CMS scanning
location ~* \.(php|asp|aspx|jsp|cgi)$ {
    return 444;
}

# Block WordPress specific patterns
location ~* wp-(admin|includes|content|login) {
    return 444;
}

# Block common vulnerability scanning paths
location ~* \.(git|svn|hg|bzr|cvs|env)(/.*)?$ {
    return 444;
}

location ~* /(xmlrpc\.php|wp-config\.php|config\.php|configuration\.php|config\.inc\.php|settings\.php|settings\.inc\.php|\.env|\.git) {
    return 444;
}
EOF

  # Create compression.conf
  log "Creating compression configuration..."
  cat > "${project_dir}/conf.d/compression.conf" << EOF
# Compression settings
gzip on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;
gzip_types
    application/atom+xml
    application/javascript
    application/json
    application/ld+json
    application/manifest+json
    application/rss+xml
    application/vnd.geo+json
    application/vnd.ms-fontobject
    application/x-font-ttf
    application/x-web-app-manifest+json
    application/xhtml+xml
    application/xml
    font/opentype
    image/bmp
    image/svg+xml
    image/x-icon
    text/cache-manifest
    text/css
    text/plain
    text/javascript
    text/xml;
EOF

  # Create sample index.html
  log "Creating sample index.html..."
  cat > "${project_dir}/html/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>${PROJECT_NAME}</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 20px;
      color: #333;
      max-width: 800px;
      margin: 0 auto;
    }
    header {
      background-color: #f4f4f4;
      padding: 20px;
      border-radius: 5px;
      margin-bottom: 20px;
    }
    h1 {
      color: #0066cc;
    }
    footer {
      margin-top: 40px;
      border-top: 1px solid #eee;
      padding-top: 10px;
      font-size: 0.8em;
      color: #777;
    }
  </style>
</head>
<body>
  <header>
    <h1>${PROJECT_NAME}</h1>
    <p>Welcome to your new project container!</p>
  </header>
  
  <main>
    <h2>Project Information</h2>
    <ul>
      <li><strong>Project Name:</strong> ${PROJECT_NAME}</li>
      <li><strong>Domain:</strong> ${DOMAIN_NAME}</li>
      <li><strong>Environment:</strong> ${ENV_TYPE}</li>
    </ul>
    
    <h2>Next Steps</h2>
    <ol>
      <li>Replace this placeholder content with your actual website.</li>
      <li>Configure any additional settings in the nginx.conf file.</li>
      <li>Add your custom static files to the html directory.</li>
    </ol>
  </main>
  
  <footer>
    <p>Generated by create-project.sh on $(date)</p>
  </footer>
</body>
</html>
EOF

  # Create 404.html
  log "Creating 404.html..."
  cat > "${project_dir}/html/404.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>404 - Page Not Found</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 20px;
      color: #333;
      text-align: center;
      max-width: 800px;
      margin: 0 auto;
    }
    h1 {
      color: #cc0000;
      font-size: 3em;
      margin-bottom: 10px;
    }
    a {
      color: #0066cc;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h1>404</h1>
  <h2>Page Not Found</h2>
  <p>The page you are looking for might have been removed, had its name changed, or is temporarily unavailable.</p>
  <p><a href="/">Return to Homepage</a></p>
</body>
</html>
EOF

  # Create 50x.html
  log "Creating 50x.html..."
  cat > "${project_dir}/html/50x.html" << EOF
<!DOCTYPE html>
<html>
<head>
  <title>Server Error</title>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      font-family: Arial, sans-serif;
      line-height: 1.6;
      margin: 0;
      padding: 20px;
      color: #333;
      text-align: center;
      max-width: 800px;
      margin: 0 auto;
    }
    h1 {
      color: #cc0000;
      font-size: 3em;
      margin-bottom: 10px;
    }
    a {
      color: #0066cc;
      text-decoration: none;
    }
    a:hover {
      text-decoration: underline;
    }
  </style>
</head>
<body>
  <h1>Server Error</h1>
  <h2>Something went wrong</h2>
  <p>The server encountered an internal error and was unable to complete your request.</p>
  <p>Please try again later or contact the administrator if the problem persists.</p>
  <p><a href="/">Return to Homepage</a></p>
</body>
</html>
EOF

  log "Project files generated successfully for $PROJECT_NAME"
}

# Function: Configure development environment
function configure_dev_environment() {
  log "Configuring development environment for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Generate self-signed certificates
  local certs_dir="${project_dir}/certs"
  mkdir -p "$certs_dir" || handle_error "Failed to create certificates directory"
  
  log "Generating self-signed certificates..."
  "${SCRIPT_DIR}/generate-certs.sh" --domain "$DOMAIN_NAME" --output "$certs_dir" --env DEV || handle_error "Failed to generate certificates"
  
  # Update local hosts file
  log "Updating local hosts file..."
  sudo "${SCRIPT_DIR}/update-hosts.sh" --domain "$DOMAIN_NAME" --action add || handle_error "Failed to update hosts file"
  
  # Configure development environment
  log "Setting up development environment..."
  "${SCRIPT_DIR}/dev-environment.sh" --project "$PROJECT_NAME" --action setup --port "$PROJECT_PORT" || handle_error "Failed to setup development environment"
  
  log "Development environment configured successfully for $PROJECT_NAME"
}

# Function: Configure production environment
function configure_pro_environment() {
  log "Configuring production environment for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Create Cloudflare directory if Cloudflare parameters are provided
  if [[ -n "$CF_TOKEN" && -n "$CF_ACCOUNT" && -n "$CF_ZONE" ]]; then
    log "Setting up Cloudflare integration..."
    local cf_dir="${project_dir}/cloudflare"
    mkdir -p "$cf_dir" || handle_error "Failed to create Cloudflare directory"
    
    # Create Terraform files for Cloudflare integration
    cat > "${cf_dir}/main.tf" << EOF
terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "domain" {
  zone_id = var.cloudflare_zone_id
  name    = "${DOMAIN_NAME}"
  value   = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = "${DOMAIN_NAME}"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_page_rule" "https" {
  zone_id = var.cloudflare_zone_id
  target  = "http://${DOMAIN_NAME}/*"
  actions {
    always_use_https = true
  }
}
EOF

    cat > "${cf_dir}/variables.tf" << EOF
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare Account ID"
  type        = string
}

variable "server_ip" {
  description = "Server IP address"
  type        = string
}
EOF

    cat > "${cf_dir}/terraform.tfvars.example" << EOF
cloudflare_api_token = "${CF_TOKEN}"
cloudflare_zone_id   = "${CF_ZONE}"
cloudflare_account_id = "${CF_ACCOUNT}"
server_ip            = "1.2.3.4"  # Replace with your actual server IP
EOF

    log "Cloudflare integration files created. Update terraform.tfvars.example with your server IP."
  else
    log "Skipping Cloudflare integration setup due to missing parameters."
  fi
  
  # Prepare for production certificates
  local certs_dir="${project_dir}/certs"
  mkdir -p "$certs_dir" || handle_error "Failed to create certificates directory"
  
  log "Preparing production certificates..."
  "${SCRIPT_DIR}/generate-certs.sh" --domain "$DOMAIN_NAME" --output "$certs_dir" --env PRO || handle_error "Failed to prepare production certificates"
  
  log "Production environment configured successfully for $PROJECT_NAME"
}

# Function: Deploy project container
function deploy_project() {
  log "Deploying project container for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Build and start the container
  cd "$project_dir" || handle_error "Failed to change directory to $project_dir"
  
  if [[ "$ENV_TYPE" == "DEV" ]]; then
    log "Starting development environment..."
    "${SCRIPT_DIR}/dev-environment.sh" --project "$PROJECT_NAME" --action start --port "$PROJECT_PORT" || handle_error "Failed to start development environment"
  else
    log "Building and starting production container..."
    if [ "$CONTAINER_ENGINE" == "podman" ]; then
      podman-compose up -d || handle_error "Failed to start production container"
    else
      docker-compose up -d || handle_error "Failed to start production container"
    fi
  fi
  
  # Update proxy configuration (stub for now)
  log "Updating proxy configuration (stub)..."
  # This will be implemented in the integration phase
  
  log "Project container deployed successfully for $PROJECT_NAME"
}

# Function: Verify deployment
function verify_deployment() {
  log "Verifying deployment for $PROJECT_NAME..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  local container_name="$PROJECT_NAME"
  
  # Check if container is running
  if [ "$CONTAINER_ENGINE" == "podman" ]; then
    if ! podman ps | grep -q "$container_name"; then
      handle_error "Container $container_name is not running"
    fi
  else
    if ! docker ps | grep -q "$container_name"; then
      handle_error "Container $container_name is not running"
    fi
  fi
  
  log "Container $container_name is running"
  
  # In development mode, check if the site is accessible
  if [[ "$ENV_TYPE" == "DEV" ]]; then
    log "Checking if site is accessible at http://localhost:${PROJECT_PORT}..."
    if ! curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PROJECT_PORT}" | grep -q "200"; then
      log "WARNING: Site is not accessible at http://localhost:${PROJECT_PORT}"
    else
      log "Site is accessible at http://localhost:${PROJECT_PORT}"
    fi
  fi
  
  log "Deployment verification completed for $PROJECT_NAME"
}

# Main script execution
validate_environment
parse_arguments "$@"
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
exit 0