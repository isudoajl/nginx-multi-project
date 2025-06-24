#!/bin/bash

# Module for deployment verification

# Function: Verify proxy health
function verify_proxy_health() {
  log "Verifying proxy health..."
  
  local max_attempts=10
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if $CONTAINER_ENGINE exec nginx-proxy nginx -t &>/dev/null; then
      log "Proxy configuration is valid"
      return 0
    fi
    sleep 2
    ((attempt++))
  done
  
  log "ERROR: Failed to verify proxy health after $max_attempts attempts"
  return 1
}

# Function: Verify project container status
function verify_project_container() {
  log "Verifying project container status..."
  
  local container_status=$(check_container_status "$PROJECT_NAME")
  
  if [[ "$container_status" == "RUNNING" ]]; then
    log "Project container is running"
    return 0
  else
    log "ERROR: Project container is not running (status: $container_status)"
    return 1
  fi
}

# Function: Verify project health endpoint
function verify_project_health() {
  log "Verifying project health endpoint..."
  
  local health_url="http://localhost:${PROJECT_PORT}/health"
  local response=""
  
  # Try to access health endpoint
  if command -v curl &>/dev/null; then
    response=$(curl -s -o /dev/null -w "%{http_code}" "$health_url" 2>/dev/null)
  elif command -v wget &>/dev/null; then
    response=$(wget -q -O /dev/null --server-response "$health_url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -n 1)
  else
    log "WARNING: Neither curl nor wget is available. Skipping health check."
    return 0
  fi
  
  if [[ "$response" == "200" ]]; then
    log "Project health endpoint is accessible"
    return 0
  else
    log "WARNING: Project health endpoint returned status $response"
    return 1
  fi
}

# Function: Verify proxy routing
function verify_proxy_routing() {
  log "Verifying proxy routing..."
  
  local proxy_url="https://${DOMAIN_NAME}"
  local response=""
  
  # Try to access through proxy
  if command -v curl &>/dev/null; then
    response=$(curl -s -k -o /dev/null -w "%{http_code}" "$proxy_url" 2>/dev/null)
  elif command -v wget &>/dev/null; then
    response=$(wget -q --no-check-certificate -O /dev/null --server-response "$proxy_url" 2>&1 | awk '/^  HTTP/{print $2}' | tail -n 1)
  else
    log "WARNING: Neither curl nor wget is available. Skipping proxy routing check."
    return 0
  fi
  
  if [[ "$response" == "200" ]]; then
    log "Proxy routing is working correctly"
    return 0
  else
    log "WARNING: Proxy routing returned status $response"
    return 1
  fi
}

# Function: Verify deployment
function verify_deployment() {
  log "Verifying deployment..."
  
  local errors=0
  
  # Verify proxy health
  if ! verify_proxy_health; then
    ((errors++))
  fi
  
  # Verify project container status
  if ! verify_project_container; then
    ((errors++))
  fi
  
  # Verify project health endpoint
  if ! verify_project_health; then
    ((errors++))
  fi
  
  # Verify proxy routing (only if hosts file was updated)
  if [[ "$ENV_TYPE" == "DEV" ]]; then
    if ! verify_proxy_routing; then
      ((errors++))
    fi
  fi
  
  if [[ $errors -eq 0 ]]; then
    log "Deployment verification completed successfully"
    return 0
  else
    log "WARNING: Deployment verification completed with $errors warnings"
    return 0  # Don't fail the deployment due to verification warnings
  fi
} 