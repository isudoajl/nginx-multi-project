#!/bin/bash

# Module for proxy management and configuration

# Function: Check proxy status and create if needed
function check_proxy() {
  log "Checking proxy status..."
  
  local proxy_container="nginx-proxy"
  local proxy_dir="${PROJECT_ROOT}/proxy"
  local proxy_network="nginx-proxy-network"
  
  # CRITICAL FIX: Only clean up stale domain configs for FRESH deployments (when no proxy exists)
  # DO NOT remove existing domain configs during incremental deployments
  local proxy_exists=false
  if $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    proxy_exists=true
  fi
  
  if [[ "$proxy_exists" == "false" ]]; then
    log "Fresh deployment detected - cleaning up any stale domain configurations..."
    rm -f "${proxy_dir}/conf.d/domains"/*.conf || log "No stale domain configs to clean"
  else
    log "Existing proxy detected - preserving existing domain configurations for incremental deployment"
  fi
  
  # Check if proxy container exists and is running
  if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    log "Proxy container '${proxy_container}' is already running"
    PROXY_RUNNING=true
  elif $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${proxy_container}$"; then
    log "Proxy container '${proxy_container}' exists but is stopped."
    
    # Check if container is in a crashed state by trying to start it
    if ! $CONTAINER_ENGINE start "${proxy_container}" 2>/dev/null; then
      log "Proxy container appears to be crashed. Removing and recreating..."
      $CONTAINER_ENGINE rm -f "${proxy_container}" || log "Failed to remove crashed container"
      create_proxy_infrastructure
    else
      log "Proxy container started successfully"
    fi
    PROXY_RUNNING=true
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
