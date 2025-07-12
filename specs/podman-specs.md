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

# Get container IP address
container_ip=$(podman inspect "${PROJECT_NAME}" | grep -A 20 "\"${proxy_network}\"" | grep '"IPAddress"' | head -1 | sed 's/.*"IPAddress": "\([^"]*\)".*/\1/')

# Use IP address in proxy configuration
proxy_pass http://${container_ip}:80;
```

### 4. Volume Mounting

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

### 5. Project Creation and Deployment

#### Requirements

- Must create project structure
- Must generate nginx configuration
- Must set up SSL certificates
- Must create and start containers
- Must configure networking
- Must update proxy configuration
- Must verify deployment

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