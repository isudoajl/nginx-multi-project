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

# Function: Check proxy status and create if needed
function check_proxy() {
  log "Checking proxy status..."
  
  local proxy_container="nginx-proxy"
  local proxy_dir="${PROJECT_ROOT}/proxy"
  local proxy_network="nginx-proxy-network"
  
  # Check if proxy container exists and is running
  if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    log "Proxy container '${proxy_container}' is already running"
    PROXY_RUNNING=true
  elif $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    log "Proxy container '${proxy_container}' exists but is stopped. Starting..."
    cd "${proxy_dir}" || handle_error "Failed to change to proxy directory"
    $CONTAINER_ENGINE start "${proxy_container}" || handle_error "Failed to start proxy container"
    PROXY_RUNNING=true
    log "Proxy container started successfully"
  else
    log "Proxy container '${proxy_container}' does not exist. Creating..."
    create_proxy_infrastructure
    PROXY_RUNNING=true
  fi
  
  # Ensure proxy network exists
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${proxy_network}$"; then
    log "Creating proxy network '${proxy_network}'..."
    $CONTAINER_ENGINE network create "${proxy_network}" || handle_error "Failed to create proxy network"
  fi
  
  # Verify proxy is healthy
  if ! verify_proxy_health; then
    handle_error "Proxy container is not healthy after startup"
  fi
  
  log "Proxy status check completed successfully"
}

# Function: Create proxy infrastructure from scratch
function create_proxy_infrastructure() {
  log "Creating complete proxy infrastructure..."
  
  local proxy_dir="${PROJECT_ROOT}/proxy"
  local proxy_network="nginx-proxy-network"
  
  # Ensure proxy directory exists
  if [[ ! -d "${proxy_dir}" ]]; then
    handle_error "Proxy directory '${proxy_dir}' does not exist. Please ensure the proxy configuration is available."
  fi
  
  # Create proxy network
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${proxy_network}$"; then
    log "Creating proxy network '${proxy_network}'..."
    $CONTAINER_ENGINE network create "${proxy_network}" || handle_error "Failed to create proxy network"
  fi
  
  # Generate proxy certificates if they don't exist
  local proxy_certs_dir="${proxy_dir}/certs"
  if [[ ! -f "${proxy_certs_dir}/fallback-cert.pem" ]]; then
    log "Generating fallback SSL certificates for proxy..."
    mkdir -p "${proxy_certs_dir}"
    generate_fallback_certificates "${proxy_certs_dir}"
  fi
  
  # Update proxy configuration to include fallback certificates
  ensure_proxy_default_ssl "${proxy_dir}"
  
  # Build and start proxy container
  log "Building and starting proxy container..."
  cd "${proxy_dir}" || handle_error "Failed to change to proxy directory"
  
  # Use podman-compose or docker-compose based on available container engine
  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    if command -v podman-compose &> /dev/null; then
      podman-compose up -d --build || handle_error "Failed to start proxy with podman-compose"
    else
      # Fallback to podman build and run
      $CONTAINER_ENGINE build -t proxy_nginx-proxy . || handle_error "Failed to build proxy image"
      $CONTAINER_ENGINE run -d --name nginx-proxy \
        --network "${proxy_network}" \
        -p 8080:80 -p 8443:443 \
        -v "${proxy_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
        -v "${proxy_dir}/conf.d:/etc/nginx/conf.d:ro" \
        -v "${proxy_dir}/certs:/etc/nginx/certs:ro" \
        -v "${proxy_dir}/html:/usr/share/nginx/html:ro" \
        -v "${proxy_dir}/logs:/var/log/nginx" \
        proxy_nginx-proxy || handle_error "Failed to run proxy container"
    fi
  else
    docker-compose up -d --build || handle_error "Failed to start proxy with docker-compose"
  fi
  
  # Wait for proxy to be ready
  log "Waiting for proxy to be ready..."
  local max_attempts=30
  local attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if $CONTAINER_ENGINE exec nginx-proxy nginx -t &>/dev/null; then
      log "Proxy is ready"
      break
    fi
    sleep 2
    ((attempt++))
  done
  
  if [ $attempt -eq $max_attempts ]; then
    handle_error "Proxy failed to become ready within timeout"
  fi
  
  log "Proxy infrastructure created successfully"
}

# Function: Generate fallback SSL certificates
function generate_fallback_certificates() {
  local certs_dir="$1"
  
  log "Generating fallback SSL certificates..."
  
  # Create OpenSSL configuration for fallback certificate
  cat > "${certs_dir}/fallback.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = Nginx Proxy
OU = Development
CN = nginx-proxy-fallback

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = nginx-proxy-fallback
DNS.2 = localhost
IP.1 = 127.0.0.1
EOF

  # Generate fallback certificate and key
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${certs_dir}/fallback-key.pem" \
    -out "${certs_dir}/fallback-cert.pem" \
    -config "${certs_dir}/fallback.cnf" \
    -extensions v3_req || handle_error "Failed to generate fallback certificates"
  
  log "Fallback SSL certificates generated successfully"
}

# Function: Ensure proxy has default SSL configuration
function ensure_proxy_default_ssl() {
  local proxy_dir="$1"
  local nginx_conf="${proxy_dir}/nginx.conf"
  
  # Check if nginx.conf has default SSL server block
  if ! grep -q "ssl_certificate.*fallback-cert.pem" "${nginx_conf}"; then
    log "Adding fallback SSL configuration to proxy nginx.conf..."
    
    # Create backup
    cp "${nginx_conf}" "${nginx_conf}.backup.$(date +%s)"
    
    # Add fallback SSL certificates to default HTTPS server block
    sed -i '/# Default HTTPS server/,/}/s|# ssl_certificate.*|ssl_certificate /etc/nginx/certs/fallback-cert.pem;\n        ssl_certificate_key /etc/nginx/certs/fallback-key.pem;|' "${nginx_conf}"
    
    log "Fallback SSL configuration added to proxy nginx.conf"
  fi
}

# Function: Verify proxy health
function verify_proxy_health() {
  local max_attempts=10
  local attempt=0
  
  log "Verifying proxy health..."
  
  while [ $attempt -lt $max_attempts ]; do
    # Check if container is running
    if ! $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^nginx-proxy$"; then
      log "Proxy container is not running (attempt $((attempt + 1))/$max_attempts)"
      sleep 3
      ((attempt++))
      continue
    fi
    
    # Check if nginx configuration is valid
    if ! $CONTAINER_ENGINE exec nginx-proxy nginx -t &>/dev/null; then
      log "Proxy nginx configuration is invalid (attempt $((attempt + 1))/$max_attempts)"
      sleep 3
      ((attempt++))
      continue
    fi
    
    # Check if nginx processes are running
    if ! $CONTAINER_ENGINE exec nginx-proxy ps aux | grep -q "[n]ginx.*worker"; then
      log "Proxy nginx worker processes not found (attempt $((attempt + 1))/$max_attempts)"
      sleep 3
      ((attempt++))
      continue
    fi
    
    # Check if ports are accessible
    if ! $CONTAINER_ENGINE exec nginx-proxy netstat -tlnp | grep -q ":80.*LISTEN"; then
      log "Proxy port 80 not listening (attempt $((attempt + 1))/$max_attempts)"
      sleep 3
      ((attempt++))
      continue
    fi
    
    log "Proxy health verification successful"
    return 0
  done
  
  log "Proxy health verification failed after $max_attempts attempts"
  # Get detailed error information
  log "=== Proxy Container Status ==="
  $CONTAINER_ENGINE ps -a | grep nginx-proxy || log "No proxy container found"
  log "=== Proxy Logs ==="
  $CONTAINER_ENGINE logs nginx-proxy --tail 20 || log "Cannot get proxy logs"
  log "=== Proxy Configuration Test ==="
  $CONTAINER_ENGINE exec nginx-proxy nginx -t || log "Configuration test failed"
  
  return 1
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

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /usr/share/nginx/html \\
    && mkdir -p /var/log/nginx \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1

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

        # Security rules (must be in server context)
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

# Note: if directives for bad_bot and method_allowed are applied in server blocks
# See nginx.conf server block for implementation

# Note: Location-based security rules moved to server context in nginx.conf
# WordPress and vulnerability scanning protection implemented in main server block
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
  local project_network="${PROJECT_NAME}-network"
  local proxy_network="nginx-proxy-network"
  
  # Create project network
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${project_network}$"; then
    log "Creating project network '${project_network}'..."
    $CONTAINER_ENGINE network create "${project_network}" || handle_error "Failed to create project network"
  fi
  
  # Build and start the container
  cd "$project_dir" || handle_error "Failed to change directory to $project_dir"
  
  log "Building project container..."
  $CONTAINER_ENGINE build -t "${PROJECT_NAME}_${PROJECT_NAME}:latest" . || handle_error "Failed to build project container"
  
  # Remove existing container if it exists
  if $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${PROJECT_NAME}$"; then
    log "Removing existing container '${PROJECT_NAME}'..."
    $CONTAINER_ENGINE rm -f "${PROJECT_NAME}" || handle_error "Failed to remove existing container"
  fi
  
  # Start the project container
  log "Starting project container..."
  $CONTAINER_ENGINE run -d --name "${PROJECT_NAME}" \
    --network "${project_network}" \
    -p "${PROJECT_PORT}:80" \
    -v "${project_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
    -v "${project_dir}/conf.d:/etc/nginx/conf.d:ro" \
    -v "${project_dir}/html:/usr/share/nginx/html:ro" \
    -v "${project_dir}/logs:/var/log/nginx" \
    "${PROJECT_NAME}_${PROJECT_NAME}:latest" || handle_error "Failed to start project container"
  
  # Connect project container to proxy network
  log "Connecting project container to proxy network..."
  $CONTAINER_ENGINE network connect "${proxy_network}" "${PROJECT_NAME}" || handle_error "Failed to connect project to proxy network"
  
  # Wait for project container to be ready
  log "Waiting for project container to be ready..."
  local max_attempts=30
  local attempt=0
  while [ $attempt -lt $max_attempts ]; do
    if $CONTAINER_ENGINE exec "${PROJECT_NAME}" nginx -t &>/dev/null; then
      log "Project container is ready"
      break
    fi
    sleep 2
    ((attempt++))
  done
  
  if [ $attempt -eq $max_attempts ]; then
    handle_error "Project container failed to become ready within timeout"
  fi
  
  # Update proxy configuration
  log "Integrating project with proxy..."
  integrate_with_proxy
  
  log "Project container deployed successfully for $PROJECT_NAME"
}

# Function: Integrate project with proxy
function integrate_with_proxy() {
  log "Integrating project '${PROJECT_NAME}' with proxy..."
  
  local proxy_domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  local domain_conf="${proxy_domains_dir}/${DOMAIN_NAME}.conf"
  
  # Ensure domains directory exists
  mkdir -p "${proxy_domains_dir}" || handle_error "Failed to create proxy domains directory"
  
  # Generate project certificates for proxy
  local project_certs_dir="${PROJECT_ROOT}/proxy/certs/${DOMAIN_NAME}"
  mkdir -p "${project_certs_dir}" || handle_error "Failed to create project certificates directory"
  
  # Generate certificates for the domain
  generate_domain_certificates "${DOMAIN_NAME}" "${project_certs_dir}"
  
  # Get project container IP address for reliable connectivity
  log "Getting project container IP address..."
  local project_container_ip=""
  local max_attempts=10
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    project_container_ip=$($CONTAINER_ENGINE inspect "${PROJECT_NAME}" --format '{{range $k, $v := .NetworkSettings.Networks}}{{if eq $k "nginx-proxy-network"}}{{$v.IPAddress}}{{end}}{{end}}' 2>/dev/null || echo "")
    if [[ -n "$project_container_ip" ]]; then
      log "Project container IP: $project_container_ip"
      break
    fi
    sleep 1
    ((attempt++))
  done
  
  if [[ -z "$project_container_ip" ]]; then
    handle_error "Failed to get project container IP address after $max_attempts attempts"
  fi

  # Create domain configuration for proxy
  log "Creating domain configuration for '${DOMAIN_NAME}'..."
  cat > "${domain_conf}" << EOF
# Domain configuration for ${DOMAIN_NAME}
# Generated automatically for project: ${PROJECT_NAME}

# HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/${DOMAIN_NAME}/cert.pem;
    ssl_certificate_key /etc/nginx/certs/${DOMAIN_NAME}/cert-key.pem;
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Security rules from variables defined in security-headers.conf
    if (\$bad_bot = 1) {
        return 444;
    }

    if (\$method_allowed = 0) {
        return 444;
    }
    
    # Apply rate limiting
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    # Proxy to project container
    location / {
        proxy_pass http://${project_container_ip}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://${project_container_ip}:80/health;
        access_log off;
    }
    
    # Custom error handling
    error_page 502 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }
}

# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
    
    # Apply rate limiting to HTTP as well
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    return 301 https://\$server_name\$request_uri;
}
EOF
  
  # Reload proxy configuration
  log "Reloading proxy configuration..."
  if $CONTAINER_ENGINE exec nginx-proxy nginx -t; then
    $CONTAINER_ENGINE exec nginx-proxy nginx -s reload || handle_error "Failed to reload proxy configuration"
    log "Proxy configuration reloaded successfully"
  else
    handle_error "Invalid nginx configuration in proxy. Check domain configuration for ${DOMAIN_NAME}"
  fi
  
  log "Project '${PROJECT_NAME}' successfully integrated with proxy"
}

# Function: Generate domain certificates
function generate_domain_certificates() {
  local domain="$1"
  local certs_dir="$2"
  
  log "Generating SSL certificates for domain '${domain}'..."
  
  # Create OpenSSL configuration for domain certificate
  cat > "${certs_dir}/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = US
ST = California
L = San Francisco
O = ${PROJECT_NAME}
OU = Development
CN = ${domain}

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${domain}
DNS.2 = www.${domain}
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

  # Generate certificate and key
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${certs_dir}/cert-key.pem" \
    -out "${certs_dir}/cert.pem" \
    -config "${certs_dir}/openssl.cnf" \
    -extensions v3_req || handle_error "Failed to generate certificates for ${domain}"
  
  log "SSL certificates generated successfully for domain '${domain}'"
}

# Function: Verify deployment
function verify_deployment() {
  log "Verifying deployment for $PROJECT_NAME..."
  
  local container_name="$PROJECT_NAME"
  local proxy_container="nginx-proxy"
  
  # Check if project container is running
  if ! $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${container_name}$"; then
    handle_error "Project container '${container_name}' is not running"
  fi
  log "✓ Project container '${container_name}' is running"
  
  # Check if proxy container is running
  if ! $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    handle_error "Proxy container '${proxy_container}' is not running"
  fi
  log "✓ Proxy container '${proxy_container}' is running"
  
  # Check project container health
  log "Checking project container health..."
  if ! $CONTAINER_ENGINE exec "${container_name}" nginx -t &>/dev/null; then
    handle_error "Project container nginx configuration is invalid"
  fi
  log "✓ Project container nginx configuration is valid"
  
  # Test direct access to project container
  log "Testing direct access to project container..."
  local direct_response=$($CONTAINER_ENGINE exec "${container_name}" curl -s -o /dev/null -w "%{http_code}" "http://localhost/" 2>/dev/null || echo "000")
  if [[ "$direct_response" != "200" ]]; then
    log "WARNING: Direct access to project container failed (HTTP $direct_response)"
  else
    log "✓ Direct access to project container is working (HTTP $direct_response)"
  fi
  
  # Test internal network connectivity from proxy to project
  log "Testing proxy → project container connectivity..."
  local project_ip=$($CONTAINER_ENGINE inspect "${container_name}" --format '{{range $k, $v := .NetworkSettings.Networks}}{{if eq $k "nginx-proxy-network"}}{{$v.IPAddress}}{{end}}{{end}}' 2>/dev/null || echo "")
  local proxy_to_project_response=""
  if [[ -n "$project_ip" ]]; then
    proxy_to_project_response=$($CONTAINER_ENGINE exec nginx-proxy curl -s -o /dev/null -w "%{http_code}" "http://${project_ip}:80/" 2>/dev/null || echo "000")
  else
    proxy_to_project_response="000"
  fi
  if [[ "$proxy_to_project_response" != "200" ]]; then
    log "WARNING: Proxy cannot reach project container (HTTP $proxy_to_project_response)"
  else
    log "✓ Proxy → project container connectivity is working (HTTP $proxy_to_project_response)"
  fi
  
  # Test external HTTP access through proxy
  log "Testing external HTTP access through proxy..."
  local external_http_response=$(curl -s -o /dev/null -w "%{http_code}" -H "Host: ${DOMAIN_NAME}" "http://localhost:8080/" 2>/dev/null || echo "000")
  if [[ "$external_http_response" == "301" ]]; then
    log "✓ HTTP → HTTPS redirect is working (HTTP $external_http_response)"
  elif [[ "$external_http_response" == "200" ]]; then
    log "✓ HTTP access through proxy is working (HTTP $external_http_response)"
  else
    log "WARNING: External HTTP access failed (HTTP $external_http_response)"
  fi
  
  # Test external HTTPS access through proxy
  log "Testing external HTTPS access through proxy..."
  local external_https_response=$(curl -k -s -o /dev/null -w "%{http_code}" -H "Host: ${DOMAIN_NAME}" "https://localhost:8443/" 2>/dev/null || echo "000")
  if [[ "$external_https_response" == "200" ]]; then
    log "✓ HTTPS access through proxy is working (HTTP $external_https_response)"
  else
    log "WARNING: External HTTPS access failed (HTTP $external_https_response)"
  fi
  
  # Check network connectivity
  log "Verifying network connectivity..."
  local proxy_networks=$($CONTAINER_ENGINE inspect nginx-proxy --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")
  local project_networks=$($CONTAINER_ENGINE inspect "${container_name}" --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}} {{end}}' 2>/dev/null || echo "")
  
  if [[ "$proxy_networks" == *"nginx-proxy-network"* ]] && [[ "$project_networks" == *"nginx-proxy-network"* ]]; then
    log "✓ Both containers are connected to nginx-proxy-network"
  else
    log "WARNING: Network connectivity issue detected"
    log "  Proxy networks: $proxy_networks"
    log "  Project networks: $project_networks"
  fi
  
  # Show deployment summary
  log "=== DEPLOYMENT SUMMARY ==="
  log "Project Name: $PROJECT_NAME"
  log "Domain Name: $DOMAIN_NAME"
  log "Project Port: $PROJECT_PORT"
  log "Project Container: ${container_name} ($(if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${container_name}$"; then echo "RUNNING"; else echo "STOPPED"; fi))"
  log "Proxy Container: ${proxy_container} ($(if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${proxy_container}$"; then echo "RUNNING"; else echo "STOPPED"; fi))"
  log "Direct Access: http://localhost:${PROJECT_PORT}"
  log "Proxy HTTP: http://localhost:8080 (Host: ${DOMAIN_NAME})"
  log "Proxy HTTPS: https://localhost:8443 (Host: ${DOMAIN_NAME})"
  log "=========================="
  
  # Final health check
  if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${container_name}$" && \
     $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${proxy_container}$" && \
     [[ "$proxy_to_project_response" == "200" ]]; then
    log "✅ DEPLOYMENT VERIFICATION SUCCESSFUL"
    return 0
  else
    log "❌ DEPLOYMENT VERIFICATION FAILED"
    log "Please check the logs and container status for troubleshooting"
    return 1
  fi
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