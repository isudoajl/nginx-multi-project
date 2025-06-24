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
    if command -v podman-compose &> /dev/null; then
      podman-compose up -d --build || handle_error "Failed to start project with podman-compose"
    else
      # Fallback to podman build and run
      $CONTAINER_ENGINE build -t "${PROJECT_NAME}" . || handle_error "Failed to build project image"
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
  else
    docker-compose up -d --build || handle_error "Failed to start project with docker-compose"
  fi
  
  # Connect project container to proxy network
  log "Connecting project container to proxy network..."
  $CONTAINER_ENGINE network connect "${proxy_network}" "${PROJECT_NAME}" || handle_error "Failed to connect project to proxy network"
  
  # Get project container IP address for proxy configuration from the proxy network
  # Use a different approach since network names with hyphens cause template parsing issues
  local container_ip=$($CONTAINER_ENGINE inspect "${PROJECT_NAME}" | grep -A 10 "\"${proxy_network}\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')
  if [[ -z "${container_ip}" ]]; then
    handle_error "Failed to get IP address for project container from proxy network"
  fi
  
  # Generate domain configuration for proxy
  log "Generating domain configuration for proxy..."
  local proxy_domains_dir="${PROJECT_ROOT}/proxy/conf.d/domains"
  mkdir -p "${proxy_domains_dir}"
  
  # Use container IP address instead of hostname to prevent DNS resolution issues
  cat > "${proxy_domains_dir}/${DOMAIN_NAME}.conf" << EOF
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
  
  # Reload proxy configuration
  log "Reloading proxy configuration..."
  $CONTAINER_ENGINE exec nginx-proxy nginx -s reload || handle_error "Failed to reload proxy configuration"
  
  log "Project '${PROJECT_NAME}' deployed successfully"
} 