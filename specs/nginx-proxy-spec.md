# Nginx Proxy Specification

## Overview
This document specifies the configuration and functionality of the central Nginx proxy container that routes traffic to individual project containers. The proxy serves as the main entry point for all incoming traffic and implements shared security policies.

## Core Functionality

1. **Traffic Routing**
   - Domain-based routing to appropriate project containers
   - Container name-based DNS resolution
   - Path-based routing for specific services
   - HTTP to HTTPS redirection
   - Default handling for unknown domains

2. **SSL/TLS Termination**
   - TLS 1.2+ support
   - Modern cipher configuration
   - HTTP/2 and HTTP/3 support
   - OCSP stapling
   - Strict Transport Security (HSTS)

3. **Security Features**
   - DDoS protection
   - Rate limiting
   - Bad bot blocking
   - IP filtering
   - HTTP method restrictions

## Configuration Structure

### Directory Layout
```
proxy/
├── docker-compose.yml
├── Dockerfile
├── nginx.conf                      # Main proxy config
└── conf.d/
    ├── ssl-settings.conf           # SSL/TLS configuration
    ├── security-headers.conf       # Security headers
    ├── cloudflare.conf             # Cloudflare IP allowlist
    └── domains/                    # Domain-specific routing
        ├── example.com.conf
        └── another-domain.com.conf
```

### Main Configuration (nginx.conf)
```nginx
user  nginx;
worker_processes  auto;

error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  1024;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;

    keepalive_timeout  65;

    # Compression
    gzip  on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
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

    # Security settings
    limit_req_zone $binary_remote_addr zone=securitylimit:10m rate=10r/s;
    limit_conn_zone $binary_remote_addr zone=securityconn:10m;

    # Block common malicious bot user agents
    map $http_user_agent $bad_bot {
        default 0;
        ~*(nmap|nikto|sqlmap|arachni|dirbuster|gobuster|w3af|nessus|masscan|ZmEu|zgrab) 1;
        ~*(python-requests|python-urllib|python-httpx|go-http-client|curl|wget) 1;
        "" 1; # Empty user agent
    }

    # Block requests with unusual HTTP methods
    map $request_method $method_allowed {
        default 1;
        ~*(TRACE|TRACK|DEBUG) 0;
    }

    # Default server block for HTTP - redirect to HTTPS
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;
        
        # Return 444 for bad bots and unusual methods
        if ($bad_bot = 1) {
            return 444;
        }

        if ($method_allowed = 0) {
            return 444;
        }
        
        # Redirect to HTTPS
        return 301 https://$host$request_uri;
    }

    # Default server block for HTTPS - return 444 for unknown domains
    server {
        listen 443 ssl http2 default_server;
        listen [::]:443 ssl http2 default_server;
        server_name _;
        
        # Include SSL settings
        include /etc/nginx/conf.d/ssl-settings.conf;
        
        # Return 444 for bad bots and unusual methods
        if ($bad_bot = 1) {
            return 444;
        }

        if ($method_allowed = 0) {
            return 444;
        }
        
        # Return error code 444 (Nginx special code that closes the connection)
        # for unknown domains
        return 444;
    }

    # Include domain-specific configurations
    include /etc/nginx/conf.d/domains/*.conf;
}
```

### SSL Settings (ssl-settings.conf)
```nginx
# SSL/TLS Configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-CHACHA20-POLY1305';

# SSL session settings
ssl_session_timeout 1d;
ssl_session_cache shared:SSL:10m;
ssl_session_tickets off;

# OCSP Stapling
ssl_stapling on;
ssl_stapling_verify on;
resolver 1.1.1.1 1.0.0.1 valid=300s;
resolver_timeout 5s;

# DH parameters for DHE ciphersuites
ssl_dhparam /etc/nginx/dhparam.pem;

# HSTS (15768000 seconds = 6 months)
add_header Strict-Transport-Security "max-age=15768000; includeSubDomains; preload" always;
```

### Security Headers (security-headers.conf)
```nginx
# Security headers
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()" always;
```

### Domain Configuration Template (domains/example.com.conf)
```nginx
# Domain configuration for example.com
# Generated automatically for project: example-project

# HTTPS server block
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name example.com www.example.com;
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/example.com/cert.pem;
    ssl_certificate_key /etc/nginx/certs/example.com/cert-key.pem;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Return 444 for bad bots and unusual methods
    if ($bad_bot = 1) {
        return 444;
    }

    if ($method_allowed = 0) {
        return 444;
    }
    
    # Apply rate limiting
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    # Proxy to project container using container name
    location / {
        proxy_pass http://example-project:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
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
        proxy_pass http://example-project:80/health;
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
    server_name example.com www.example.com;
    
    # Apply rate limiting to HTTP as well
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    return 301 https://$server_name$request_uri;
}
```

## Docker Compose Configuration

```yaml
version: '3.8'

services:
  nginx-proxy:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: nginx-proxy
    ports:
      - "8080:80"
      - "8443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./certs:/etc/nginx/certs:ro
      - ./dhparam.pem:/etc/nginx/dhparam.pem:ro
      - ./html:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - nginx-proxy-network

networks:
  nginx-proxy-network:
    driver: bridge
```

## Dockerfile

```dockerfile
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache openssl

# Create nginx user
RUN adduser -D -H -u 1000 -s /sbin/nologin nginx

# Create required directories
RUN mkdir -p /etc/nginx/conf.d/domains \
    && mkdir -p /etc/nginx/certs \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx

# Generate DH parameters
RUN openssl dhparam -out /etc/nginx/dhparam.pem 2048

# Set permissions
RUN chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Switch to non-root user
USER nginx

EXPOSE 80 443

CMD ["nginx", "-g", "daemon off;"]
```

## Container Name-Based Routing

The proxy uses container names for DNS resolution instead of IP addresses. This approach provides several benefits:

1. **Reliability**: Container names are stable and don't change when containers restart
2. **Simplicity**: No need to track and update IP addresses
3. **Security**: No exposed ports required for project containers
4. **Maintainability**: Easier to manage and troubleshoot

### Routing Mechanism

- Each project container is connected to the `nginx-proxy-network`
- The proxy uses container names (e.g., `example-project`) for routing
- DNS resolution happens automatically within the Docker network
- No port conflicts between projects

## Cloudflare Integration

When using Cloudflare in production mode, the proxy will be configured to only accept connections from Cloudflare's IP ranges. The `cloudflare.conf` file will contain these IP ranges and will be included in the domain configurations.

### Cloudflare Configuration (cloudflare.conf)
```nginx
# Allow Cloudflare IPs only
# IPv4
allow 173.245.48.0/20;
allow 103.21.244.0/22;
allow 103.22.200.0/22;
allow 103.31.4.0/22;
allow 141.101.64.0/18;
allow 108.162.192.0/18;
allow 190.93.240.0/20;
allow 188.114.96.0/20;
allow 197.234.240.0/22;
allow 198.41.128.0/17;
allow 162.158.0.0/15;
allow 104.16.0.0/13;
allow 104.24.0.0/14;
allow 172.64.0.0/13;
allow 131.0.72.0/22;

# IPv6
allow 2400:cb00::/32;
allow 2606:4700::/32;
allow 2803:f800::/32;
allow 2405:b500::/32;
allow 2405:8100::/32;
allow 2a06:98c0::/29;
allow 2c0f:f248::/32;

# Real IP configuration
real_ip_header CF-Connecting-IP;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

# Deny all other IPs
deny all;
```

## Performance Considerations

1. **Worker Processes**
   - Set to `auto` to match CPU cores
   - Adjust based on workload and available resources

2. **Worker Connections**
   - Default: 1024
   - Increase based on expected concurrent connections

3. **Keepalive Settings**
   - Timeout: 65 seconds
   - Adjust based on client behavior and load

4. **Buffer Sizes**
   - Configure appropriate buffer sizes for headers and body
   - Optimize based on typical request/response sizes

5. **Compression**
   - Enable gzip compression for appropriate content types
   - Configure compression level based on CPU vs. bandwidth tradeoff

## Monitoring and Logging

1. **Access Logs**
   - Standard format with client IP, timestamp, request, status, bytes, referer, and user agent
   - Optional extended format with request processing time

2. **Error Logs**
   - Notice level by default
   - Configurable to debug, info, warn, error, crit, alert, or emerg

3. **Log Rotation**
   - Daily rotation
   - Compression of old logs
   - Retention period configurable

## Scaling Considerations

1. **Load Balancer Integration**
   - Support for upstream load balancer headers
   - Health check endpoints

2. **Multiple Proxy Instances**
   - Shared configuration through mounted volumes
   - Consistent hashing for session persistence

This specification provides a comprehensive guide for implementing the central Nginx proxy component of the microservices architecture. It ensures secure, efficient, and scalable routing of traffic to individual project containers using container name-based DNS resolution. 