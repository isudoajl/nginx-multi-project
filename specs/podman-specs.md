# Podman Integration Specifications

## Overview

This document specifies the implementation details for the podman integration in the Nginx Multi-Project architecture.

## Components

### 1. Nix Development Environment

#### Requirements

- Must provide a consistent development environment across different machines
- Must include all necessary tools for development (nginx, podman, openssl)
- Must set up podman for rootless operation automatically
- Must provide a Docker compatibility layer

#### Implementation

```nix
# flake.nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { 
          inherit system; 
          config = { allowUnfree = true; };
        };

        # Podman setup scripts and utilities
        # ...
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            openssl
            nginx
            podman
            conmon
            runc
            slirp4netns
            shadow
            # Custom scripts
            # ...
          ];

          shellHook = ''
            export IN_NIX_SHELL=1
            # Podman setup
            # ...
          '';
        };
      }
    );
}
```

### 2. Podman Setup

#### Requirements

- Must set up podman for rootless operation
- Must create necessary configuration files
- Must set required capabilities for user namespace mapping
- Must be idempotent (can be run multiple times without issues)

#### Implementation

```bash
# scripts/setup-podman.sh
#!/bin/bash

# Create required directories
mkdir -p ~/.config/containers

# Create policy.json if it doesn't exist
if [ ! -f ~/.config/containers/policy.json ]; then
  # Create policy.json
  # ...
fi

# Create registries.conf if it doesn't exist
if [ ! -f ~/.config/containers/registries.conf ]; then
  # Create registries.conf
  # ...
fi

# Set capabilities for rootless podman
NEWUIDMAP=$(readlink --canonicalize $(which newuidmap))
NEWGIDMAP=$(readlink --canonicalize $(which newgidmap))

if ! getcap "$NEWUIDMAP" | grep -q "cap_setuid+ep"; then
  sudo setcap cap_setuid+ep "$NEWUIDMAP"
  sudo setcap cap_setgid+ep "$NEWGIDMAP"
  sudo chmod -s "$NEWUIDMAP"
  sudo chmod -s "$NEWGIDMAP"
fi
```

### 3. Container Networking

#### Requirements

- Must provide reliable container-to-container communication
- Must support DNS resolution between containers
- Must handle network connectivity verification
- Must use IP address-based proxy_pass directives to avoid DNS resolution issues

#### Implementation

```bash
# Create the nginx-proxy network
podman network create nginx-proxy-network

# Connect containers to the network
podman run --network nginx-proxy-network ...

# Get container IP address - UPDATED with more reliable method
container_ip=$(podman inspect "${PROJECT_NAME}" | grep -A 20 "\"${proxy_network}\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')

# Use IP address in proxy configuration
proxy_pass http://${container_ip}:80;
```

### 4. Network Connectivity Verification

#### Requirements

- Must verify connectivity between proxy and project containers before updating proxy configuration
- Must provide fallback verification methods if primary method fails
- Must prevent proxy configuration updates if connectivity cannot be verified

#### Implementation

```bash
# Verify network connectivity between proxy and project container
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
```

### 5. Volume Mounting

#### Requirements

- Must mount configuration files and certificates as read-only
- Must mount logs as read-write
- Must handle permissions correctly

#### Implementation

```bash
podman run -d \
  --name nginx-proxy \
  --network nginx-proxy-network \
  -p 8080:80 \
  -p 8443:443 \
  -v "${PROXY_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "${PROXY_DIR}/conf.d:/etc/nginx/conf.d:ro" \
  -v "${PROXY_DIR}/certs:/etc/nginx/certs:ro" \
  -v "${PROXY_DIR}/logs:/var/log/nginx" \
  nginx:alpine
```

### 6. Project Creation and Deployment

#### Requirements

- Must create project structure
- Must generate nginx configuration
- Must set up SSL certificates
- Must create and start containers
- Must configure networking
- Must update proxy configuration
- Must verify deployment
- Must verify network connectivity before updating proxy configuration
- Must use IP-based routing for reliable proxy_pass directives

#### Implementation

```bash
# scripts/create-project-modular.sh
#!/bin/bash

# Parse command line arguments
parse_arguments "$@"

# Validate environment
validate_environment

# Validate SSL certificates
validate_certificates

# Check and setup proxy
check_proxy

# Setup project structure
setup_project_structure

# Generate project files
generate_project_files

# Configure environment based on type
if [[ "$ENV_TYPE" == "DEV" ]]; then
  configure_dev_environment
else
  configure_pro_environment
fi

# Deploy project
deploy_project

# Verify deployment
verify_deployment
```

### 7. Certificate Management

#### Requirements

- Must support both development and production certificates
- Must handle domain-specific certificates
- Must properly copy certificates to proxy container
- Must ensure proper permissions for certificate files

#### Implementation

```bash
# Copy domain-specific certificates to proxy certs directory
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
```

## Testing

### Network Connectivity Testing

```bash
# scripts/test-podman-network.sh
#!/bin/bash

# Create test containers
podman run -d --name test-server --network nginx-proxy-network nginx:alpine
podman run -d --name test-client --network nginx-proxy-network alpine sh -c "apk add --no-cache curl && sleep 3600"

# Test HTTP connectivity
podman exec test-client curl -s --max-time 5 "http://test-server/" | grep -q "Welcome to nginx"
```

### Proxy Configuration Testing

```bash
# Test nginx configuration
podman exec nginx-proxy nginx -t

# Test proxy accessibility
curl -s --max-time 10 -H "Host: ${DOMAIN_NAME}" "http://localhost:8080" | grep -q "301"
```

### IP Address Detection Testing

```bash
# Test IP address detection
container_ip=$(podman inspect "${PROJECT_NAME}" | grep -A 20 "\"${proxy_network}\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')
echo "Container IP: ${container_ip}"
if [[ -z "${container_ip}" || "${container_ip}" == *"."* ]]; then
  echo "IP address detection failed"
  exit 1
fi
```

## Cleanup

```bash
# scripts/cleanup-podman.sh
#!/bin/bash

# Stop and remove all containers
podman ps --all --quiet | xargs --no-run-if-empty podman stop
podman ps --all --quiet | xargs --no-run-if-empty podman rm --force

# Remove all images
podman images --quiet | xargs --no-run-if-empty podman rmi --force

# Prune containers and images
podman container prune --force
podman image prune --force

# Remove networks and volumes
podman network ls --quiet | grep -v "podman" | xargs --no-run-if-empty podman network rm
podman volume ls --quiet | xargs --no-run-if-empty podman volume prune --force
``` 