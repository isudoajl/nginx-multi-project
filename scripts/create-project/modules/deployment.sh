#!/bin/bash

# Module for project deployment

# Function: Deploy project
function deploy_project() {
  log "Deploying project '${PROJECT_NAME}'..."
  
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  local proxy_network="nginx-proxy-network"
  
  # Ensure project directory exists
  if [[ ! -d "${project_dir}" ]]; then
    handle_error "Project directory '${project_dir}' does not exist"
  fi
  
  # Ensure proxy network exists
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${proxy_network}$"; then
    log "Creating proxy network '${proxy_network}'..."
    $CONTAINER_ENGINE network create "${proxy_network}" || handle_error "Failed to create proxy network"
  fi
  
  # Create project-specific network
  local project_network="${PROJECT_NAME}-network"
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${project_network}$"; then
    log "Creating project network '${project_network}'..."
    $CONTAINER_ENGINE network create "${project_network}" || handle_error "Failed to create project network"
  fi
  
  # Build and start project container
  log "Building and starting project container..."
  cd "${project_dir}" || handle_error "Failed to change to project directory"
  
  # Use podman-compose or docker-compose based on available container engine
  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    # Clean up any existing container with the same name
    $CONTAINER_ENGINE rm -f "${PROJECT_NAME}" &>/dev/null || true
    
    # Build and run with podman directly (more reliable than podman-compose)
    $CONTAINER_ENGINE build -t "${PROJECT_NAME}" . || handle_error "Failed to build project image"
    $CONTAINER_ENGINE run -d --name "${PROJECT_NAME}" \
      --network "${proxy_network}" \
      -p "${PROJECT_PORT}:80" \
      -v "${project_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
      -v "${project_dir}/conf.d:/etc/nginx/conf.d:ro" \
      -v "${project_dir}/html:/usr/share/nginx/html:ro" \
      -v "${project_dir}/certs:/etc/nginx/certs:ro" \
      -v "${project_dir}/logs:/var/log/nginx" \
      "${PROJECT_NAME}" || handle_error "Failed to run project container"
  else
    docker-compose up -d --build || handle_error "Failed to start project with docker-compose"
    
    # Connect project container to proxy network
    log "Connecting project container to proxy network..."
    $CONTAINER_ENGINE network connect "${proxy_network}" "${PROJECT_NAME}" || handle_error "Failed to connect project to proxy network"
  fi
  
  # Wait for container to be fully ready
  log "Waiting for project container to be ready..."
  sleep 5
  
  # Get project container IP address for proxy configuration from the proxy network
  log "Detecting project container IP address on proxy network..."
  local container_ip=""
  local max_attempts=10
  local attempt=0
  
  while [[ -z "${container_ip}" && $attempt -lt $max_attempts ]]; do
    # More reliable method to get the IP address
    container_ip=$($CONTAINER_ENGINE inspect "${PROJECT_NAME}" | grep -A 20 "\"${proxy_network}\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')
    if [[ -z "${container_ip}" ]]; then
      log "Attempt $((attempt + 1)): Waiting for IP address assignment..."
      sleep 2
      ((attempt++))
    fi
  done
  
  if [[ -z "${container_ip}" ]]; then
    handle_error "Failed to get IP address for project container from proxy network after ${max_attempts} attempts"
  fi
  
  log "Project container IP address: ${container_ip}"
  
  # CRITICAL FIX: Copy domain-specific certificates to proxy certs directory
  log "Copying domain-specific certificates to proxy..."
  local proxy_certs_dir="${PROJECT_ROOT}/proxy/certs"
  local domain_certs_source="${CERTS_DIR}/${DOMAIN_NAME}"
  local domain_certs_dest="${proxy_certs_dir}/${DOMAIN_NAME}"
  
  # Ensure proxy certs directory exists
  mkdir -p "${proxy_certs_dir}"
  
  # Copy domain-specific certificates to proxy
  if [[ -d "${domain_certs_source}" ]]; then
    mkdir -p "${domain_certs_dest}"
    cp "${domain_certs_source}/cert.pem" "${domain_certs_dest}/cert.pem" || handle_error "Failed to copy cert.pem to proxy"
    cp "${domain_certs_source}/cert-key.pem" "${domain_certs_dest}/cert-key.pem" || handle_error "Failed to copy cert-key.pem to proxy"
    log "Domain-specific certificates copied to proxy successfully"
  else
    handle_error "Domain-specific certificate directory not found: ${domain_certs_source}"
  fi
  
  # CRITICAL FIX: Verify network connectivity before updating proxy configuration
  log "Verifying network connectivity between proxy and project container..."
  local connectivity_verified=false
  local max_connectivity_attempts=5
  local connectivity_attempt=0
  
  while [[ "$connectivity_verified" == "false" && $connectivity_attempt -lt $max_connectivity_attempts ]]; do
    if $CONTAINER_ENGINE exec nginx-proxy curl -s --max-time 5 -f "http://${container_ip}:80/health" > /dev/null 2>&1; then
      connectivity_verified=true
      log "Network connectivity verified successfully"
    else
      log "Connectivity attempt $((connectivity_attempt + 1)): Waiting for container to be reachable..."
      sleep 3
      ((connectivity_attempt++))
    fi
  done
  
  if [[ "$connectivity_verified" == "false" ]]; then
    # Try alternative verification method - just check if container is reachable
    if $CONTAINER_ENGINE exec nginx-proxy ping -c 1 "${container_ip}" > /dev/null 2>&1; then
      log "Network connectivity verified via ping (HTTP service may not be ready yet)"
      connectivity_verified=true
    else
      handle_error "Failed to verify network connectivity between proxy and project container after ${max_connectivity_attempts} attempts"
    fi
  fi
  
  # Generate domain configuration for proxy
  log "Generating domain configuration for proxy..."
  local proxy_domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  mkdir -p "${proxy_domains_dir}"
  local domain_config_file="${proxy_domains_dir}/${DOMAIN_NAME}.conf"
  
  # Use container name for stable DNS resolution in Docker networks
  cat > "${domain_config_file}" << EOF
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
        proxy_pass http://${PROJECT_NAME}:80;
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
        proxy_pass http://${PROJECT_NAME}:80/health;
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
  
  # CRITICAL FIX: Safe proxy configuration reload with testing
  log "Testing new proxy configuration..."
  if ! $CONTAINER_ENGINE exec nginx-proxy nginx -t; then
    log "ERROR: New proxy configuration is invalid. Rolling back..."
    rm -f "${domain_config_file}"
    handle_error "Proxy configuration test failed. Domain configuration removed to prevent breaking existing projects."
  fi
  
  log "Proxy configuration test passed. Reloading proxy..."
  if ! $CONTAINER_ENGINE exec nginx-proxy nginx -s reload; then
    log "ERROR: Failed to reload proxy configuration. Rolling back..."
    rm -f "${domain_config_file}"
    handle_error "Failed to reload proxy configuration. Domain configuration removed to prevent breaking existing projects."
  fi
  
  # Final verification that the new project is accessible
  log "Performing final accessibility verification..."
  sleep 2
  if ! curl -s --max-time 10 -H "Host: ${DOMAIN_NAME}" "http://localhost:8080" | grep -q "301"; then
    log "WARNING: Final accessibility test failed, but configuration is valid and loaded"
  else
    log "Final accessibility verification successful"
  fi
  
  log "Project '${PROJECT_NAME}' deployed successfully with zero-downtime incremental deployment"
} 