#!/bin/bash

# Module for proxy utilities

# Function: Copy master SSL certificates to proxy
function generate_fallback_certificates() {
  local certs_dir="$1"
  
  log "Copying master SSL certificates to proxy..."
  
  # Define master certificate paths
  local master_cert="${PROJECT_ROOT}/certs/cert.pem"
  local master_key="${PROJECT_ROOT}/certs/cert-key.pem"
  
  # Check if master certificates exist
  if [[ ! -f "${master_cert}" ]]; then
    handle_error "Master certificate not found: ${master_cert}"
  fi
  
  if [[ ! -f "${master_key}" ]]; then
    handle_error "Master certificate key not found: ${master_key}"
  fi
  
  # Copy master certificates to proxy certs directory
  cp "${master_cert}" "${certs_dir}/cert.pem" || handle_error "Failed to copy master certificate"
  cp "${master_key}" "${certs_dir}/cert-key.pem" || handle_error "Failed to copy master certificate key"
  
  log "Master SSL certificates copied successfully to proxy"
}

# Function: Ensure proxy has default SSL configuration
function ensure_proxy_default_ssl() {
  local proxy_dir="$1"
  local nginx_conf="${proxy_dir}/nginx.conf"
  
  # Check if nginx.conf has default SSL server block
  if ! grep -q "ssl_certificate.*cert.pem" "${nginx_conf}"; then
    log "Adding master SSL configuration to proxy nginx.conf..."
    
    # Create backup
    cp "${nginx_conf}" "${nginx_conf}.backup.$(date +%s)"
    
    # Add master SSL certificates to default HTTPS server block
    sed -i '/# Default HTTPS server/,/}/s|# ssl_certificate.*|ssl_certificate /etc/nginx/certs/cert.pem;\n        ssl_certificate_key /etc/nginx/certs/cert-key.pem;|' "${nginx_conf}"
    
    log "Master SSL configuration added to proxy nginx.conf"
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

# Function: Integrate project with proxy
function integrate_with_proxy() {
  log "Integrating project '${PROJECT_NAME}' with proxy..."
  
  # Certificate Workflow Note:
  # At this point, domain-specific certificates should already exist in /opt/nginx-multi-project/certs/{domain}/
  # created by project_structure.sh. We copy them to the proxy's certificate directory.
  
  local proxy_domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  local domain_conf="${proxy_domains_dir}/${DOMAIN_NAME}.conf"
  
  # Ensure domains directory exists
  mkdir -p "${proxy_domains_dir}" || handle_error "Failed to create proxy domains directory"
  
  # Setup certificates for proxy from domain-specific directory
  log "Setting up certificates for proxy for domain ${DOMAIN_NAME}..."
  local proxy_project_certs_dir="${PROJECT_ROOT}/proxy/certs/${DOMAIN_NAME}"
  local domain_certs_dir="${CERTS_DIR}/${DOMAIN_NAME}"
  
  mkdir -p "${proxy_project_certs_dir}" || handle_error "Failed to create proxy project certs directory"
  
  # Domain-specific certificates should already exist from project_structure.sh
  # But double-check and create if missing
  if [[ ! -d "${domain_certs_dir}" ]]; then
    log "Domain-specific certificate directory missing, creating from generic certificates..."
    mkdir -p "${domain_certs_dir}" || handle_error "Failed to create domain certificate directory"
    
    # Check if generic certificates exist
    if [[ ! -f "${CERTS_DIR}/cert.pem" ]] || [[ ! -f "${CERTS_DIR}/cert-key.pem" ]]; then
      handle_error "Generic certificates not found in ${CERTS_DIR}. Please ensure cert.pem and cert-key.pem exist."
    fi
    
    # Copy generic certificates to domain-specific directory
    cp "${CERTS_DIR}/cert.pem" "${domain_certs_dir}/cert.pem" || handle_error "Failed to copy cert.pem to domain directory"
    cp "${CERTS_DIR}/cert-key.pem" "${domain_certs_dir}/cert-key.pem" || handle_error "Failed to copy cert-key.pem to domain directory"
    log "Created domain-specific certificates from generic certificates"
  fi
  
  # Copy domain-specific certificates to proxy
  cp "${domain_certs_dir}/cert.pem" "${proxy_project_certs_dir}/cert.pem" || handle_error "Failed to copy domain cert.pem to proxy"
  cp "${domain_certs_dir}/cert-key.pem" "${proxy_project_certs_dir}/cert-key.pem" || handle_error "Failed to copy domain cert-key.pem to proxy"
  log "Copied domain-specific certificates to proxy directory"

  # Get project container IP address for reliable connectivity
  log "Getting project container IP address..."
  local project_container_ip=""
  local max_attempts=10
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    # Use a simpler approach to get the IP address
    project_container_ip=$($CONTAINER_ENGINE inspect -f '{{.NetworkSettings.Networks.nginx-proxy-network.IPAddress}}' "${PROJECT_NAME}" 2>/dev/null || echo "")
    
    if [[ -z "$project_container_ip" ]]; then
      # Try getting the first IP address from any network
      project_container_ip=$($CONTAINER_ENGINE inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${PROJECT_NAME}" 2>/dev/null | head -n1 || echo "")
    fi
    
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

  create_domain_configuration "$domain_conf" "$project_container_ip"
  
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

# Function to create domain configuration
function create_domain_configuration() {
  local domain_conf="$1"
  local project_container_ip="$2"
  
  # Ensure we have a clean single IP address
  project_container_ip=$(echo "$project_container_ip" | grep -o -E '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
  
  if [[ -z "$project_container_ip" ]]; then
    handle_error "Failed to get a valid IP address for project container"
  fi
  
  log "Using IP address: $project_container_ip for domain configuration"
  
  # Create domain configuration for proxy
  log "Creating domain configuration for '${DOMAIN_NAME}'..."
  cat > "${domain_conf}" << EOC
# Domain configuration for ${DOMAIN_NAME}
# Generated automatically for project: ${PROJECT_NAME}

# HTTPS server block
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
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
EOC
}
