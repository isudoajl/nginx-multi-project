# Project Container Architecture

## Overview

This document provides technical documentation for the project container component of the Microservices Nginx Architecture. Project containers are isolated environments that host individual websites or applications, with their own Nginx configuration, Docker setup, and networking.

## Architecture Components

### 1. Container Structure

Each project container is built on a custom Nginx image with project-specific configurations:

```
Project Container
├── Nginx Server
│   ├── Project-specific configuration
│   ├── Security settings
│   ├── Compression settings
│   └── Static file handling
├── Docker Container
│   ├── Volume mounts
│   ├── Network configuration
│   └── Environment variables
└── Health Check Endpoint
    └── Status monitoring
```

### 2. Configuration Hierarchy

The Nginx configuration follows a modular approach:

```
nginx.conf
├── http context
│   ├── server context
│   │   ├── Main server configuration
│   │   └── Location blocks
│   └── Included configurations
│       ├── conf.d/security.conf
│       ├── conf.d/compression.conf
│       └── conf.d/custom/*.conf
└── Global settings
```

### 3. Network Architecture

Project containers connect to both their own isolated network and the shared proxy network:

```
                    ┌─────────────────┐
                    │   Nginx Proxy   │
                    └─────────────────┘
                            │
                            │ Shared Proxy Network
                            │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
┌────────▼───────┐ ┌───────▼────────┐ ┌─────▼──────────┐
│  Project A     │ │  Project B     │ │  Project C     │
│  Container     │ │  Container     │ │  Container     │
└────────┬───────┘ └───────┬────────┘ └─────┬──────────┘
         │                 │                │
         │                 │                │
┌────────▼───────┐ ┌───────▼────────┐ ┌─────▼──────────┐
│  Project A     │ │  Project B     │ │  Project C     │
│  Network       │ │  Network       │ │  Network       │
└────────────────┘ └────────────────┘ └────────────────┘
```

## Technical Specifications

### 1. Nginx Configuration

#### Base Configuration

```nginx
# nginx.conf
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;

    keepalive_timeout  65;

    # Include project-specific configurations
    include /etc/nginx/conf.d/*.conf;
    
    server {
        listen       80;
        server_name  localhost;
        
        # Health check endpoint
        location /health {
            root   /usr/share/nginx/html;
            index  index.html;
        }
        
        # Static content
        location / {
            root   /usr/share/nginx/html;
            index  index.html index.htm;
            try_files $uri $uri/ /index.html;
        }
        
        # Error pages
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
```

#### Security Configuration

```nginx
# security.conf
# Security headers
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self'; connect-src 'self';" always;

# Prevent access to hidden files
location ~ /\.(?!well-known) {
    deny all;
    return 404;
}

# Disable directory listing
autoindex off;

# Limit request size
client_max_body_size 10M;

# Timeouts
client_body_timeout 12;
client_header_timeout 12;
send_timeout 10;
```

#### Compression Configuration

```nginx
# compression.conf
# Enable Gzip compression
gzip on;
gzip_comp_level 5;
gzip_min_length 256;
gzip_proxied any;
gzip_vary on;

# Compress text-based files
gzip_types
  application/atom+xml
  application/javascript
  application/json
  application/ld+json
  application/manifest+json
  application/rss+xml
  application/vnd.geo+json
  application/vnd.ms-fontobject
  application/x-font-ttf
  application/x-web-app-manifest+json
  application/xhtml+xml
  application/xml
  font/opentype
  image/bmp
  image/svg+xml
  image/x-icon
  text/cache-manifest
  text/css
  text/plain
  text/vcard
  text/vnd.rim.location.xloc
  text/vtt
  text/x-component
  text/x-cross-domain-policy;
```

### 2. Docker Configuration

#### Dockerfile

```dockerfile
FROM nginx:alpine

# Add custom configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d/ /etc/nginx/conf.d/

# Add health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/health || exit 1

# Set working directory
WORKDIR /usr/share/nginx/html

# Copy static content
COPY html/ /usr/share/nginx/html/

# Expose port
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
```

#### Docker Compose Configuration

```yaml
version: '3.8'

services:
  project-name:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: project-name
    restart: unless-stopped
    volumes:
      - ./html:/usr/share/nginx/html:ro
      - ./conf.d:/etc/nginx/conf.d:ro
    networks:
      - project-network
      - proxy-network

networks:
  project-network:
    driver: bridge
  proxy-network:
    external: true
    name: nginx-proxy-network
```

### 3. Health Check Implementation

#### HTML Endpoint

```html
<!DOCTYPE html>
<html>
<head>
  <title>Health Check</title>
</head>
<body>
  <h1>Service is healthy</h1>
  <p>Environment: Production</p>
  <p>Project: project-name</p>
  <p>Time: <span id="current-time"></span></p>
  
  <script>
    document.getElementById('current-time').textContent = new Date().toISOString();
  </script>
</body>
</html>
```

## Development Environment Configuration

### Docker Compose Override

```yaml
version: '3.8'

services:
  project-name:
    # Development-specific overrides
    volumes:
      # Add volume for live reloading
      - ./html:/usr/share/nginx/html:ro
      # Mount custom development configuration
      - ./conf.d/dev:/etc/nginx/conf.d/dev:ro
    environment:
      # Development environment variables
      - NGINX_ENVSUBST_TEMPLATE_DIR=/etc/nginx/templates
      - NGINX_ENVSUBST_OUTPUT_DIR=/etc/nginx/conf.d
      - ENVIRONMENT=development
    # Enable development ports
    ports:
      - "8080:80"
    # Development-specific healthcheck
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/health"]
      interval: 10s
      timeout: 3s
      retries: 3
      start_period: 5s
    # Development-specific restart policy
    restart: unless-stopped
    # Add development labels
    labels:
      - "dev.environment=true"
      - "dev.project=project-name"

networks:
  project-name-network:
    driver: bridge
    # Development-specific network configuration
    ipam:
      config:
        - subnet: 172.28.5.0/24
```

## Integration Points

### 1. Proxy Integration

Project containers integrate with the central Nginx proxy through:

1. **Network Connection**: Joining the shared proxy network
2. **Domain Registration**: Registering the project domain with the proxy
3. **SSL Termination**: Utilizing the proxy's SSL certificates

### 2. Script Integration

Project containers are managed through automation scripts:

1. **Creation**: `create-project.sh` generates project container files
2. **Proxy Update**: `update-proxy.sh` registers the project with the proxy
3. **Certificate Management**: `generate-certs.sh` creates SSL certificates
4. **Development Environment**: `dev-environment.sh` manages the development setup

## Security Considerations

1. **Isolation**: Each project runs in its own container with isolated configuration
2. **Network Segmentation**: Projects have their own networks
3. **Security Headers**: Default security headers protect against common web vulnerabilities
4. **Resource Limits**: Container resources are limited to prevent DoS attacks
5. **Access Control**: File permissions and access controls restrict unauthorized access

## Performance Optimization

1. **Compression**: Static content is compressed to reduce bandwidth usage
2. **Caching**: Browser caching is configured for static assets
3. **Resource Limits**: Container resources are optimized for performance
4. **Connection Handling**: Nginx connection settings are tuned for optimal performance

## Scalability

Project containers can be scaled through:

1. **Horizontal Scaling**: Multiple container instances behind a load balancer
2. **Resource Allocation**: Adjusting container resource limits
3. **Network Configuration**: Optimizing network settings for increased traffic

## Monitoring and Logging

1. **Health Checks**: Regular health checks monitor container status
2. **Logging**: Access and error logs capture request information
3. **Metrics**: Container metrics track resource usage

## Deployment Process

1. **Build**: Build the project container image
2. **Test**: Validate the container configuration
3. **Deploy**: Start the container and register with the proxy
4. **Verify**: Confirm the project is accessible and functioning correctly 