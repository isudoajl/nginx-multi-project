# Project Container Specification

## Overview
This document specifies the configuration and functionality of individual project containers in the microservices architecture. Each project container runs an isolated Nginx server that hosts a specific website or application.

## Core Functionality

1. **Static Content Serving**
   - HTML, CSS, JavaScript, and other static assets
   - Optimized caching and compression
   - Custom error pages

2. **Security Implementation**
   - Project-specific security headers
   - Content Security Policy
   - Rate limiting
   - Input validation

3. **Integration Points**
   - Communication with the central proxy
   - Optional OAuth authentication
   - Optional API backend proxying

## Project Container Structure

### Directory Layout
```
projects/
└── {project-name}/
    ├── docker-compose.yml          # Project-specific compose
    ├── Dockerfile                  # Custom nginx image
    ├── nginx.conf                  # Project nginx config
    ├── conf.d/                     # Additional configurations
    │   ├── security.conf           # Security settings
    │   └── compression.conf        # Compression settings
    ├── html/                       # Frontend files
    │   └── index.html
    └── certs/                      # Project-specific certs (optional)
        ├── cert.pem
        └── cert-key.pem
```

## Docker Compose Configuration

```yaml
version: '3.8'

services:
  {project-name}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: {project-name}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./html:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - {project-name}-network
    environment:
      - PROJECT_NAME={project-name}
      - DOMAIN_NAME={domain-name}

networks:
  {project-name}-network:
    driver: bridge
```

## Dockerfile

```dockerfile
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl

# Create nginx user
RUN adduser -D -H -u 1000 -s /sbin/nologin nginx

# Create required directories
RUN mkdir -p /etc/nginx/conf.d \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx

# Set permissions
RUN chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# Switch to non-root user
USER nginx

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

## Nginx Configuration (nginx.conf)

```nginx
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
    tcp_nopush      on;
    tcp_nodelay     on;

    keepalive_timeout  65;

    # Include additional configurations
    include /etc/nginx/conf.d/*.conf;

    # Default server
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        
        root /usr/share/nginx/html;
        index index.html;

        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header Referrer-Policy "strict-origin-when-cross-origin" always;
        add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self'; style-src 'self'; frame-ancestors 'none'; base-uri 'self'; form-action 'self';" always;
        add_header Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()" always;

        # Static files handling
        location / {
            try_files $uri $uri/ =404;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|otf|eot|mp4)$ {
            expires max;
            log_not_found off;
        }

        # Custom error pages
        error_page 404 /404.html;
        error_page 500 502 503 504 /50x.html;
    }
}
```

## Security Configuration (conf.d/security.conf)

```nginx
# Security settings
# Rate limiting zone - limits clients to 10 requests per second
limit_req_zone $binary_remote_addr zone=projectlimit:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=projectconn:10m;

# Apply rate limiting to all locations
limit_req zone=projectlimit burst=20 nodelay;
limit_conn projectconn 20;

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

# Return 444 for bad bots and unusual methods
if ($bad_bot = 1) {
    return 444;
}

if ($method_allowed = 0) {
    return 444;
}

# Block WordPress and common CMS scanning
location ~* \.(php|asp|aspx|jsp|cgi)$ {
    return 444;
}

# Block WordPress specific patterns
location ~* wp-(admin|includes|content|login) {
    return 444;
}

# Block common vulnerability scanning paths
location ~* \.(git|svn|hg|bzr|cvs|env)(/.*)?$ {
    return 444;
}

location ~* /(xmlrpc\.php|wp-config\.php|config\.php|configuration\.php|config\.inc\.php|settings\.php|settings\.inc\.php|\.env|\.git) {
    return 444;
}
```

## Compression Configuration (conf.d/compression.conf)

```nginx
# Compression settings
gzip on;
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
```

## Environment-Specific Configurations

### Development Environment
- Self-signed certificates
- Local host file entries
- Debug-level logging
- No Cloudflare integration

### Production Environment
- Real domain certificates
- Cloudflare integration
- Notice-level logging
- Enhanced security measures

## Customization Points

Each project container can be customized with:

1. **Domain-specific configurations**
   - Custom server names
   - Path-specific handlers
   - Redirects and rewrites

2. **Custom error pages**
   - 404 Not Found
   - 50x Server Error

3. **Performance tuning**
   - Worker processes
   - Connection limits
   - Buffer sizes

4. **Backend service integration**
   - Proxy configurations for APIs
   - Authentication service connections

## Integration with Proxy

The project container is designed to work with the central Nginx proxy:

1. **Network Configuration**
   - Project container exposes port 80 internally
   - Connected to both project-specific and proxy networks
   - Only accepts connections from the proxy

2. **Headers Handling**
   - Processes X-Forwarded-* headers from the proxy
   - Sets appropriate response headers

3. **Health Checks**
   - Exposes health check endpoint for the proxy
   - Reports container status

This specification provides a comprehensive guide for implementing individual project containers in the microservices architecture. It ensures secure, efficient, and isolated hosting of project-specific content. 