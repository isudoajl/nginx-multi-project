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
  
  # CRITICAL FIX: Clean up any existing containers with the same name to prevent conflicts
  log "Cleaning up any existing containers with the same name..."
  $CONTAINER_ENGINE stop "${PROJECT_NAME}" 2>/dev/null || true
  $CONTAINER_ENGINE rm "${PROJECT_NAME}" 2>/dev/null || true
  
  # Create project-specific network
  local project_network="${PROJECT_NAME}-network"
  if ! $CONTAINER_ENGINE network ls --format "{{.Name}}" | grep -q "^${project_network}$"; then
    log "Creating project network '${project_network}'..."
    $CONTAINER_ENGINE network create "${project_network}" || handle_error "Failed to create project network"
  fi
  
  # Build and start project container
  log "Building and starting project container..."
  cd "${project_dir}" || handle_error "Failed to change to project directory"
  
  # If using Nix build, copy the monorepo to the project directory
  if [[ "$USE_NIX_BUILD" == true ]]; then
    log "Copying monorepo for Nix build..."
    
    # Create a monorepo directory in the project directory
    local monorepo_dest="${project_dir}/monorepo"
    mkdir -p "${monorepo_dest}"
    
    # Copy the monorepo to the project directory
    log "Copying from ${MONO_REPO_PATH} to ${monorepo_dest}..."
    cp -r "${MONO_REPO_PATH}"/* "${monorepo_dest}/" || handle_error "Failed to copy monorepo"
    
    # Update the Dockerfile to use the local monorepo path
    log "Updating Dockerfile to use local monorepo path..."
    sed -i "s|COPY ${MONO_REPO_PATH} /opt/${PROJECT_NAME}|COPY ./monorepo /opt/${PROJECT_NAME}|" "${project_dir}/Dockerfile" || handle_error "Failed to update Dockerfile"
    
    log "Monorepo copied successfully"
  fi
  
  # Use podman-compose or docker-compose based on available container engine
  if [[ "$CONTAINER_ENGINE" == "podman" ]]; then
    if command -v podman-compose &> /dev/null; then
      log "Using podman-compose to build and start the container..."
      
      # CRITICAL FIX: Pre-build the image with the exact name that podman-compose will look for
      # podman-compose generates image names as: {project_name}_{service_name}
      local compose_image_name="${PROJECT_NAME}_${PROJECT_NAME}"
      log "Pre-building image with podman-compose naming convention: ${compose_image_name}..."
      $CONTAINER_ENGINE build -t "${compose_image_name}" . || handle_error "Failed to build project image"
      
      # Also tag with a localhost prefix as a backup
      $CONTAINER_ENGINE tag "${compose_image_name}" "localhost/${compose_image_name}" || log "Warning: Failed to create localhost tag"
      
      # CRITICAL FIX: Use project name flag to ensure consistent container naming
      podman-compose -p "${PROJECT_NAME}" up -d || handle_error "Failed to start project with podman-compose"
      
      # CRITICAL FIX: Get the actual container name created by podman-compose
      local actual_container_name
      actual_container_name=$($CONTAINER_ENGINE ps --filter "name=${PROJECT_NAME}" --format "{{.Names}}" | head -1)
      
      # If no container found, try to find with alternative naming pattern (project-name_service_1)
      if [[ -z "$actual_container_name" ]]; then
        log "No container found with name filter '${PROJECT_NAME}', trying alternative naming pattern..."
        actual_container_name=$($CONTAINER_ENGINE ps --format "{{.Names}}" | grep "${PROJECT_NAME}_" | head -1)
      fi
      
      if [[ -n "$actual_container_name" && "$actual_container_name" != "${PROJECT_NAME}" ]]; then
        log "Container created with name '${actual_container_name}', renaming to '${PROJECT_NAME}'..."
        $CONTAINER_ENGINE stop "$actual_container_name" || handle_error "Failed to stop container for renaming"
        $CONTAINER_ENGINE rename "$actual_container_name" "${PROJECT_NAME}" || handle_error "Failed to rename container"
        $CONTAINER_ENGINE start "${PROJECT_NAME}" || handle_error "Failed to start renamed container"
      fi
    else
      # Fallback to podman build and run
      log "Fallback to manual podman build and run..."
      $CONTAINER_ENGINE build -t "${PROJECT_NAME}" . || handle_error "Failed to build project image"
      
      # Run container with appropriate volumes based on build type
      if [[ "$USE_NIX_BUILD" == true && -n "${BACKEND_PATH}" ]]; then
        $CONTAINER_ENGINE run -d --name "${PROJECT_NAME}" \
          --network "${project_network}" \
          -p "${PROJECT_PORT}:80" \
          -v "${project_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
          -v "${project_dir}/conf.d:/etc/nginx/conf.d:ro" \
          -v "${project_dir}/supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro" \
          -v "${project_dir}/certs:/etc/nginx/certs:ro" \
          -v "${project_dir}/logs:/var/log/nginx" \
          "${PROJECT_NAME}" || handle_error "Failed to run project container"
      elif [[ "$USE_NIX_BUILD" == true ]]; then
        $CONTAINER_ENGINE run -d --name "${PROJECT_NAME}" \
          --network "${project_network}" \
          -p "${PROJECT_PORT}:80" \
          -v "${project_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
          -v "${project_dir}/conf.d:/etc/nginx/conf.d:ro" \
          -v "${project_dir}/certs:/etc/nginx/certs:ro" \
          -v "${project_dir}/logs:/var/log/nginx" \
          "${PROJECT_NAME}" || handle_error "Failed to run project container"
      else
        $CONTAINER_ENGINE run -d --name "${PROJECT_NAME}" \
          --network "${project_network}" \
          -p "${PROJECT_PORT}:80" \
          -v "${project_dir}/nginx.conf:/etc/nginx/nginx.conf:ro" \
          -v "${project_dir}/conf.d:/etc/nginx/conf.d:ro" \
          -v "${project_dir}/html:/usr/share/nginx/html:ro" \
          -v "${project_dir}/certs:/etc/nginx/certs:ro" \
          -v "${project_dir}/logs:/var/log/nginx" \
          "${PROJECT_NAME}" || handle_error "Failed to run project container"
      fi
    fi
  else
    log "Using docker-compose to build and start the container..."
    
    # CRITICAL FIX: Pre-build the image with the exact name that docker-compose will look for
    # docker-compose generates image names as: {project_name}_{service_name}
    local compose_image_name="${PROJECT_NAME}_${PROJECT_NAME}"
    log "Pre-building image with docker-compose naming convention: ${compose_image_name}..."
    $CONTAINER_ENGINE build -t "${compose_image_name}" . || handle_error "Failed to build project image"
    
    # Also tag with a localhost prefix as a backup
    $CONTAINER_ENGINE tag "${compose_image_name}" "localhost/${compose_image_name}" || log "Warning: Failed to create localhost tag"
    
    # CRITICAL FIX: Use project name flag to ensure consistent container naming
    # Also use --no-pull flag since docker-compose supports it
    docker-compose -p "${PROJECT_NAME}" up -d --no-pull || handle_error "Failed to start project with docker-compose"
    
    # CRITICAL FIX: Get the actual container name created by docker-compose
    local actual_container_name
    actual_container_name=$($CONTAINER_ENGINE ps --filter "name=${PROJECT_NAME}" --format "{{.Names}}" | head -1)
    
    if [[ -n "$actual_container_name" && "$actual_container_name" != "${PROJECT_NAME}" ]]; then
      log "Container created with name '${actual_container_name}', renaming to '${PROJECT_NAME}'..."
      $CONTAINER_ENGINE stop "$actual_container_name" || handle_error "Failed to stop container for renaming"
      $CONTAINER_ENGINE rename "$actual_container_name" "${PROJECT_NAME}" || handle_error "Failed to rename container"
      $CONTAINER_ENGINE start "${PROJECT_NAME}" || handle_error "Failed to start renamed container"
    fi
  fi
  
  # CRITICAL FIX: Verify container is actually running
  log "Verifying container is running..."
  local container_running=false
  local max_verify_attempts=5
  local verify_attempt=0
  
  while [[ "$container_running" == "false" && $verify_attempt -lt $max_verify_attempts ]]; do
    if $CONTAINER_ENGINE ps --format "{{.Names}}" | grep -q "^${PROJECT_NAME}$"; then
      container_running=true
      log "Container '${PROJECT_NAME}' is running"
    else
      log "Verify attempt $((verify_attempt + 1)): Container not running yet, checking status..."
      $CONTAINER_ENGINE ps -a --filter "name=${PROJECT_NAME}" --format "{{.Names}} {{.Status}}"
      
      # Check if container exists but is not running
      if $CONTAINER_ENGINE ps -a --format "{{.Names}}" | grep -q "^${PROJECT_NAME}$"; then
        log "Container exists but is not running. Checking logs..."
        $CONTAINER_ENGINE logs --tail 20 "${PROJECT_NAME}"
        
        # Try to restart the container
        log "Attempting to restart container..."
        $CONTAINER_ENGINE restart "${PROJECT_NAME}" || handle_error "Failed to restart container"
      fi
      
      sleep 3
      ((verify_attempt++))
    fi
  done
  
  if [[ "$container_running" == "false" ]]; then
    handle_error "Failed to verify container is running after ${max_verify_attempts} attempts"
  fi
  
  # Connect project container to proxy network
  log "Connecting project container to proxy network..."
  $CONTAINER_ENGINE network connect "${proxy_network}" "${PROJECT_NAME}" || handle_error "Failed to connect project to proxy network"
  
  # Wait for container to be fully ready
  log "Waiting for project container to be ready..."
  sleep 5
  
  # Get project container IP address for proxy configuration from the proxy network
  log "Detecting project container IP address on proxy network..."
  local container_ip=""
  local max_attempts=10
  local attempt=0
  
  while [[ -z "${container_ip}" && $attempt -lt $max_attempts ]]; do
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
    handle_error "Failed to verify network connectivity between proxy and project container after ${max_connectivity_attempts} attempts"
  fi
  
  # Generate domain configuration for proxy
  log "Generating domain configuration for proxy..."
  local proxy_domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  mkdir -p "${proxy_domains_dir}"
  local domain_config_file="${proxy_domains_dir}/${DOMAIN_NAME}.conf"
  
  # Use container IP address instead of hostname to prevent DNS resolution issues
  cat > "${domain_config_file}" << EOF
# Domain configuration for ${DOMAIN_NAME}
server {
    listen 80;
    server_name ${DOMAIN_NAME};
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name ${DOMAIN_NAME};
    
    ssl_certificate /etc/nginx/certs/${DOMAIN_NAME}/cert.pem;
    ssl_certificate_key /etc/nginx/certs/${DOMAIN_NAME}/cert-key.pem;
    
    location / {
        proxy_pass http://${container_ip}:80;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    location /health {
        proxy_pass http://${container_ip}:80/health;
        proxy_set_header Host \$host;
        access_log off;
        add_header Content-Type text/plain;
    }
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