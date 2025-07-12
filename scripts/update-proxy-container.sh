#!/bin/bash

# This script updates the proxy container to use the proper podman configuration
# It recreates the proxy container with the correct network settings

# See https://vaneyckt.io/posts/safer_bash_scripts_with_set_euxo_pipefail/
set -euo pipefail

# Constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
PROXY_DIR="${PROJECT_ROOT}/proxy"
CERTS_DIR="${PROJECT_ROOT}/certs"

# Check if we're in Nix environment
if [ -z "${IN_NIX_SHELL:-}" ]; then
  echo "ERROR: Please enter Nix environment with 'nix develop' first"
  exit 1
fi

# Determine container engine
if command -v podman &> /dev/null; then
  CONTAINER_ENGINE="podman"
else
  CONTAINER_ENGINE="docker"
fi

echo "Using container engine: $CONTAINER_ENGINE"

# Create required directories
echo "Creating required directories..."
mkdir -p "${PROXY_DIR}/conf.d"
mkdir -p "${PROXY_DIR}/conf.d/domains"
mkdir -p "${PROXY_DIR}/certs"
mkdir -p "${PROXY_DIR}/logs"

# Check if nginx.conf exists, if not create a basic one
if [ ! -f "${PROXY_DIR}/nginx.conf" ]; then
  echo "Creating basic nginx.conf..."
  cat > "${PROXY_DIR}/nginx.conf" << EOF
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log warn;
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
    #tcp_nopush     on;

    keepalive_timeout  65;

    #gzip  on;

    include /etc/nginx/conf.d/*.conf;
    include /etc/nginx/conf.d/domains/*.conf;
}
EOF
fi

# Copy certificates to proxy/certs directory
echo "Copying certificates to proxy/certs directory..."
if [ -f "${CERTS_DIR}/cert.pem" ] && [ -f "${CERTS_DIR}/cert-key.pem" ]; then
  cp "${CERTS_DIR}/cert.pem" "${PROXY_DIR}/certs/cert.pem"
  cp "${CERTS_DIR}/cert-key.pem" "${PROXY_DIR}/certs/cert-key.pem"
  echo "Certificates copied successfully"
else
  echo "WARNING: Main certificates not found, creating self-signed certificates"
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
    -keyout "${PROXY_DIR}/certs/cert-key.pem" \
    -out "${PROXY_DIR}/certs/cert.pem" \
    -subj "/CN=localhost" \
    -addext "subjectAltName = DNS:localhost"
fi

# Always create/update the default.conf
echo "Creating basic default.conf..."
cat > "${PROXY_DIR}/conf.d/default.conf" << EOF
# Default server configuration
server {
    listen 80 default_server;
    server_name _;
    
    location / {
        return 404 "No site configured for this domain";
    }
}

server {
    listen 443 ssl default_server;
    server_name _;
    
    # Certificate
    ssl_certificate /etc/nginx/certs/cert.pem;
    ssl_certificate_key /etc/nginx/certs/cert-key.pem;
    
    location / {
        return 404 "No site configured for this domain";
    }
}
EOF

# Ensure the nginx-proxy-network exists
echo "Checking for nginx-proxy-network..."
if ! $CONTAINER_ENGINE network ls | grep -q "nginx-proxy-network"; then
  echo "Creating nginx-proxy network..."
  $CONTAINER_ENGINE network create nginx-proxy-network
fi

# Check if the proxy container exists
echo "Checking for existing proxy container..."
if $CONTAINER_ENGINE ps -a | grep -q "nginx-proxy"; then
  echo "Stopping and removing existing proxy container..."
  $CONTAINER_ENGINE stop nginx-proxy || true
  $CONTAINER_ENGINE rm nginx-proxy || true
fi

# Create the proxy container
echo "Creating proxy container..."
$CONTAINER_ENGINE run -d \
  --name nginx-proxy \
  --network nginx-proxy-network \
  -p 8080:80 \
  -p 8443:443 \
  -v "${PROXY_DIR}/nginx.conf:/etc/nginx/nginx.conf:ro" \
  -v "${PROXY_DIR}/conf.d:/etc/nginx/conf.d:ro" \
  -v "${PROXY_DIR}/certs:/etc/nginx/certs:ro" \
  -v "${PROXY_DIR}/logs:/var/log/nginx" \
  nginx:alpine

# Wait for container to start
echo "Waiting for proxy container to start..."
sleep 3

# Check if container is running
if ! $CONTAINER_ENGINE ps | grep -q "nginx-proxy"; then
  echo "ERROR: Proxy container failed to start"
  $CONTAINER_ENGINE logs nginx-proxy
  exit 1
fi

# Test nginx configuration
echo "Testing nginx configuration..."
if ! $CONTAINER_ENGINE exec nginx-proxy nginx -t; then
  echo "ERROR: Nginx configuration test failed"
  $CONTAINER_ENGINE logs nginx-proxy
  exit 1
fi

echo "Proxy container updated successfully!"
echo "Proxy is now accessible at:"
echo "  HTTP: http://localhost:8080"
echo "  HTTPS: https://localhost:8443" 