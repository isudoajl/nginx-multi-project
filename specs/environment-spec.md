# Environment Management Specification

## Overview
This document specifies the comprehensive environment management system for the **Microservices Nginx Architecture** - covering the Nix development environment, environment switching capabilities, and development/production environment configuration. The system ensures consistent, reproducible environments across all deployment scenarios.

## 🎯 Environment Management Status: ✅ **PRODUCTION READY**

The environment management system provides:
- **✅ Nix Development Environment**: Reproducible development setup with all required tools
- **✅ Environment Switching**: Seamless transition between development and production environments
- **✅ Configuration Management**: Environment-specific configuration handling
- **✅ Dependency Management**: Automatic tool and dependency provisioning
- **✅ Environment Validation**: Comprehensive environment verification and setup

## Core Environment Architecture

### Environment Types

#### 1. **Nix Development Environment** ✅
- **Reproducible Setup**: Declarative environment definition using flake.nix
- **Tool Provisioning**: Automatic installation of nginx, podman, openssl, and other required tools
- **Shell Integration**: Seamless integration with development workflow
- **Dependency Isolation**: Isolated environment preventing system conflicts

#### 2. **Development Environment (DEV)** ✅
- **Local Development**: Optimized for local development and testing
- **Self-Signed Certificates**: Automatic generation of development SSL certificates
- **Local DNS**: Host file management for local domain resolution
- **Hot Reload**: Live configuration reloading for rapid development
- **Debug Configuration**: Debug-level logging and development optimizations

#### 3. **Production Environment (PRO)** ✅
- **Production Deployment**: Optimized for production workloads
- **Real Certificates**: Support for production SSL certificates
- **Cloudflare Integration**: CDN and security service integration
- **Performance Optimization**: Production-grade performance tuning
- **Security Hardening**: Enhanced security configuration

### Environment Configuration Structure

```
nginx/
├── config/
│   └── environments/
│       ├── development/
│       │   ├── env.conf              # Development environment configuration
│       │   └── nginx.conf            # Development nginx configuration
│       └── production/
│           ├── env.conf              # Production environment configuration
│           └── nginx.conf            # Production nginx configuration
├── scripts/
│   ├── dev/
│   │   └── dev-workflow.sh           # Development workflow automation
│   └── prod/
│       ├── prod-deployment.sh        # Production deployment automation
│       ├── cert-management.sh        # Production certificate management
│       └── cert-rotation.sh          # Certificate rotation automation
└── tests/
    ├── test-dev-environment.sh       # Development environment testing
    ├── test-env-switching.sh         # Environment switching testing
    ├── test-env-security.sh          # Environment security testing
    └── test-config-consistency.sh    # Configuration consistency testing
```

## Nix Environment Implementation

### Flake Configuration (flake.nix)

```nix
{
  description = "Nginx Multi-Project Development Environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Container engines
            podman
            podman-compose
            
            # Web server
            nginx
            
            # SSL/TLS tools
            openssl
            
            # Network tools
            curl
            dig
            nettools
            
            # Development tools
            git
            bash
            coreutils
            findutils
            gnugrep
            gnused
            
            # Terraform for Cloudflare integration
            terraform
            
            # JSON processing
            jq
          ];

          shellHook = ''
            echo "🚀 Nginx Multi-Project Development Environment"
            echo "Tools available: nginx, podman, openssl, terraform, curl"
            echo "Run 'nginx -v' to verify nginx installation"
            echo "Run 'podman --version' to verify container engine"
            
            # Set environment variables
            export IN_NIX_SHELL=1
            export PROJECT_ROOT=$(pwd)
            export PATH="$PROJECT_ROOT/scripts:$PATH"
            
            # Validate environment
            if command -v nginx &> /dev/null; then
              echo "✅ Nginx: $(nginx -v 2>&1)"
            fi
            
            if command -v podman &> /dev/null; then
              echo "✅ Podman: $(podman --version)"
            fi
            
            if command -v openssl &> /dev/null; then
              echo "✅ OpenSSL: $(openssl version)"
            fi
            
            echo "Environment ready! 🎉"
          '';
        };
      });
}
```

### Environment Validation

```bash
#!/bin/bash
# Environment validation function

function validate_environment() {
  log "Validating environment..."
  
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
  log "Environment validation completed successfully"
}
```

## Development Environment (DEV)

### Development Configuration Features

1. **Self-Signed Certificate Generation**
```bash
# Automatic development certificate generation
function generate_dev_certificates() {
  local domain="$1"
  local output_dir="$2"
  
  log "Generating development certificates for $domain..."
  
  # Create OpenSSL configuration
  cat > "$output_dir/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $domain

[v3_req]
keyUsage = keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = *.$domain
EOF

  # Generate private key and certificate
  openssl req -new -x509 -nodes \
    -out "$output_dir/cert.pem" \
    -keyout "$output_dir/cert-key.pem" \
    -days 365 \
    -config "$output_dir/openssl.cnf"
    
  # Set proper permissions
  chmod 644 "$output_dir/cert.pem"
  chmod 600 "$output_dir/cert-key.pem"
  
  log "Development certificates generated successfully"
}
```

2. **Local DNS Management**
```bash
# Local hosts file management
function update_local_hosts() {
  local domain="$1"
  local action="$2"
  
  case $action in
    add)
      if ! grep -q "$domain" /etc/hosts; then
        echo "127.0.0.1 $domain" | sudo tee -a /etc/hosts
        log "Added $domain to local hosts file"
      else
        log "$domain already exists in hosts file"
      fi
      ;;
    remove)
      sudo sed -i "/$domain/d" /etc/hosts
      log "Removed $domain from local hosts file"
      ;;
  esac
}
```

3. **Development Environment Setup**
```bash
function setup_development_environment() {
  local project_name="$1"
  local project_port="$2"
  
  log "Setting up development environment for $project_name..."
  
  local project_dir="${PROJECTS_DIR}/${project_name}"
  
  # Create development configuration override
  cat > "$project_dir/docker-compose.override.yml" << EOF
version: '3.8'
services:
  $project_name:
    ports:
      - "$project_port:80"
    environment:
      - NGINX_DEBUG=1
      - ENVIRONMENT=development
    volumes:
      - ./conf.d/dev:/etc/nginx/conf.d/dev:ro
EOF
  
  # Create development-specific nginx configuration
  mkdir -p "$project_dir/conf.d/dev"
  cat > "$project_dir/conf.d/dev/development.conf" << EOF
# Development environment configuration
# Debug logging
error_log /var/log/nginx/error.log debug;

# Disable caching for development
expires -1;
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0";

# CORS headers for development
add_header Access-Control-Allow-Origin "*";
add_header Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS";
add_header Access-Control-Allow-Headers "DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range";
EOF
  
  # Setup health check endpoint
  mkdir -p "$project_dir/html/health"
  cat > "$project_dir/html/health/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Health Check - $project_name</title>
</head>
<body>
    <h1>✅ $project_name is running</h1>
    <p>Environment: Development</p>
    <p>Status: OK</p>
    <p>Timestamp: $(date)</p>
</body>
</html>
EOF
  
  log "Development environment setup completed for $project_name"
}
```

## Production Environment (PRO)

### Production Configuration Features

1. **Production Certificate Management**
```bash
function setup_production_certificates() {
  local domain="$1"
  local cert_dir="$2"
  
  log "Setting up production certificates for $domain..."
  
  # Check if custom certificates are provided
  if [ -f "$cert_dir/cert.pem" ] && [ -f "$cert_dir/cert-key.pem" ]; then
    log "Using provided production certificates"
    # Validate certificate
    validate_certificate "$cert_dir/cert.pem" "$domain"
  else
    log "Generating production certificate request..."
    generate_production_csr "$domain" "$cert_dir"
  fi
}

function generate_production_csr() {
  local domain="$1"
  local output_dir="$2"
  
  # Create OpenSSL configuration for production
  cat > "$output_dir/openssl.cnf" << EOF
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
CN = $domain

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $domain
DNS.2 = www.$domain
EOF

  # Generate private key and CSR
  openssl req -new -nodes \
    -out "$output_dir/cert.csr" \
    -keyout "$output_dir/cert-key.pem" \
    -config "$output_dir/openssl.cnf"
    
  chmod 644 "$output_dir/cert.csr"
  chmod 600 "$output_dir/cert-key.pem"
  
  log "Production certificate request generated: $output_dir/cert.csr"
  log "Submit CSR to your Certificate Authority"
}
```

2. **Cloudflare Integration**
```bash
function setup_cloudflare_integration() {
  local domain="$1"
  local cf_token="$2"
  local cf_account="$3"
  local cf_zone="$4"
  
  log "Setting up Cloudflare integration for $domain..."
  
  # Validate Cloudflare credentials
  if [ -z "$cf_token" ] || [ -z "$cf_account" ] || [ -z "$cf_zone" ]; then
    log "WARNING: Cloudflare credentials not provided - skipping integration"
    return 0
  fi
  
  # Use Terraform for Cloudflare configuration
  cd nginx/terraform/cloudflare
  
  # Create terraform variables
  cat > "terraform.tfvars" << EOF
cloudflare_api_token = "$cf_token"
domain_name = "$domain"
origin_ip = "$(curl -s https://ipv4.icanhazip.com)"
account_id = "$cf_account"
zone_id = "$cf_zone"
EOF

  # Initialize and apply Terraform
  terraform init
  terraform plan -var-file="terraform.tfvars"
  terraform apply -var-file="terraform.tfvars" -auto-approve
  
  cd - > /dev/null
  
  log "Cloudflare integration completed for $domain"
}
```

3. **Production Environment Configuration**
```bash
function setup_production_environment() {
  local project_name="$1"
  local domain="$2"
  
  log "Setting up production environment for $project_name..."
  
  local project_dir="${PROJECTS_DIR}/${project_name}"
  
  # Create production nginx configuration
  cat > "$project_dir/nginx.conf" << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    access_log /var/log/nginx/access.log main;

    # Performance optimizations
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;

    # Include configurations
    include /etc/nginx/conf.d/*.conf;

    server {
        listen 80 default_server;
        server_name $domain www.$domain;
        
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        include /etc/nginx/conf.d/security.conf;
        
        # Compression
        include /etc/nginx/conf.d/compression.conf;

        location / {
            try_files \$uri \$uri/ =404;
        }

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "OK\\n";
            add_header Content-Type text/plain;
        }

        # Static file optimization
        location ~* \\.(jpg|jpeg|png|gif|ico|css|js|pdf|txt|webp|svg)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
            access_log off;
        }

        # Custom error pages
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }
}
EOF
  
  log "Production environment setup completed for $project_name"
}
```

## Environment Switching

### Dynamic Environment Configuration

```bash
function switch_environment() {
  local project_name="$1"
  local target_env="$2"  # DEV or PRO
  
  log "Switching $project_name to $target_env environment..."
  
  local project_dir="${PROJECTS_DIR}/${project_name}"
  local env_config_dir="nginx/config/environments/${target_env,,}"
  
  # Validate target environment
  if [ ! -d "$env_config_dir" ]; then
    handle_error "Environment configuration not found: $env_config_dir"
  fi
  
  # Stop current environment
  stop_project_environment "$project_name"
  
  # Switch configuration
  case $target_env in
    DEV)
      setup_development_environment "$project_name"
      ;;
    PRO)
      setup_production_environment "$project_name"
      ;;
    *)
      handle_error "Invalid environment: $target_env"
      ;;
  esac
  
  # Start new environment
  start_project_environment "$project_name"
  
  log "Environment switch completed: $project_name -> $target_env"
}
```

### Configuration Consistency Validation

```bash
function validate_environment_consistency() {
  log "Validating environment configuration consistency..."
  
  local dev_config="nginx/config/environments/development"
  local prod_config="nginx/config/environments/production"
  
  # Check required files exist
  local required_files=("env.conf" "nginx.conf")
  for file in "${required_files[@]}"; do
    if [ ! -f "$dev_config/$file" ]; then
      handle_error "Missing development configuration: $file"
    fi
    if [ ! -f "$prod_config/$file" ]; then
      handle_error "Missing production configuration: $file"
    fi
  done
  
  # Validate nginx configuration syntax
  nginx -t -c "$dev_config/nginx.conf" || handle_error "Invalid development nginx configuration"
  nginx -t -c "$prod_config/nginx.conf" || handle_error "Invalid production nginx configuration"
  
  log "Environment configuration consistency validated"
}
```

## Integration with Deployment Scripts

### Environment Detection in Scripts

```bash
function detect_and_configure_environment() {
  local env_type="$1"  # DEV or PRO
  local project_name="$2"
  local domain="$3"
  
  log "Configuring $env_type environment for $project_name..."
  
  case $env_type in
    DEV)
      configure_dev_environment "$project_name" "$domain"
      ;;
    PRO)
      configure_prod_environment "$project_name" "$domain"
      ;;
    *)
      handle_error "Invalid environment type: $env_type"
      ;;
  esac
}

function configure_dev_environment() {
  local project_name="$1"
  local domain="$2"
  
  # Generate self-signed certificates
  generate_dev_certificates "$domain" "${PROJECTS_DIR}/${project_name}/certs"
  
  # Update local hosts file
  update_local_hosts "$domain" "add"
  
  # Configure development environment
  setup_development_environment "$project_name"
  
  log "Development environment configured successfully for $project_name"
}

function configure_prod_environment() {
  local project_name="$1"
  local domain="$2"
  
  # Setup production certificates
  setup_production_certificates "$domain" "${PROJECTS_DIR}/${project_name}/certs"
  
  # Configure Cloudflare if credentials provided
  if [ -n "$CF_TOKEN" ] && [ -n "$CF_ACCOUNT" ] && [ -n "$CF_ZONE" ]; then
    setup_cloudflare_integration "$domain" "$CF_TOKEN" "$CF_ACCOUNT" "$CF_ZONE"
  fi
  
  # Configure production environment
  setup_production_environment "$project_name" "$domain"
  
  log "Production environment configured successfully for $project_name"
}
```

## Environment Monitoring and Validation

### Health Checks

```bash
function validate_environment_health() {
  local project_name="$1"
  local env_type="$2"
  
  log "Validating environment health for $project_name ($env_type)..."
  
  # Check container status
  validate_container_running "$project_name"
  
  # Check configuration
  validate_nginx_configuration "$project_name"
  
  # Check certificates
  validate_ssl_certificates "$project_name"
  
  # Environment-specific validation
  case $env_type in
    DEV)
      validate_development_features "$project_name"
      ;;
    PRO)
      validate_production_features "$project_name"
      ;;
  esac
  
  log "Environment health validation completed for $project_name"
}
```

### Performance Monitoring

```bash
function monitor_environment_performance() {
  local project_name="$1"
  
  log "Monitoring environment performance for $project_name..."
  
  # Container resource usage
  podman stats --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}" --no-stream
  
  # Response time testing
  local response_time=$(curl -o /dev/null -s -w '%{time_total}' "http://localhost:8080")
  log "Response time: ${response_time}s"
  
  # SSL handshake performance (production)
  if [ "$ENVIRONMENT" = "PRO" ]; then
    local ssl_time=$(curl -o /dev/null -s -w '%{time_appconnect}' "https://localhost:8443")
    log "SSL handshake time: ${ssl_time}s"
  fi
}
```

## Best Practices

### Environment Management Best Practices

1. **Always Use Nix Environment**: All operations must be performed within the Nix development shell
2. **Environment Validation**: Validate environment configuration before deployment
3. **Consistent Configuration**: Maintain configuration consistency across environments
4. **Proper Certificate Management**: Use appropriate certificates for each environment
5. **Environment Isolation**: Ensure proper isolation between development and production

### Security Considerations

1. **Certificate Security**: Proper permissions and storage for SSL certificates
2. **Credential Management**: Secure handling of API tokens and sensitive configuration
3. **Network Security**: Proper network isolation and access control
4. **Configuration Security**: Secure configuration file permissions and access

The environment management system ensures consistent, reproducible, and secure environments across all deployment scenarios, supporting both development workflows and production deployments! 🌍 