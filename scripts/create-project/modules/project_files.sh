#!/bin/bash

# Module for generating project files

# Function: Generate project files
function generate_project_files() {
  log "Generating project files for $PROJECT_NAME..."
  
  # Create project directory
  local project_dir="${PROJECTS_DIR}/${PROJECT_NAME}"
  
  # Create Dockerfile
  generate_dockerfile "$project_dir"
  
  # Create docker-compose.yml
  generate_docker_compose "$project_dir"
  
  # Create nginx.conf
  generate_nginx_conf "$project_dir"
  
  # Create configuration files
  generate_config_files "$project_dir"
  
  # Create HTML files
  generate_html_files "$project_dir"
  
  log "Project files generated successfully for $PROJECT_NAME"
}

# Function: Generate Dockerfile
function generate_dockerfile() {
  local project_dir="$1"
  
  log "Creating Dockerfile..."
  
  # Check if this is a monorepo project
  if [[ "$IS_MONOREPO" == true ]]; then
    generate_monorepo_dockerfile "$project_dir"
  else
    generate_standard_dockerfile "$project_dir"
  fi
}

# Function: Generate standard Dockerfile (original functionality)
function generate_standard_dockerfile() {
  local project_dir="$1"
  
  log "Creating standard Dockerfile..."
  cat > "${project_dir}/Dockerfile" << EOF
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl

# Copy SSL certificates
COPY --chown=nginx:nginx certs/cert.pem /etc/ssl/certs/cert.pem
COPY --chown=nginx:nginx certs/cert-key.pem /etc/ssl/private/cert-key.pem

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /usr/share/nginx/html \\
    && mkdir -p /var/log/nginx \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
}

# Function: Generate multi-stage Dockerfile for monorepo projects
function generate_monorepo_dockerfile() {
  local project_dir="$1"
  
  log "Creating multi-stage Dockerfile for monorepo project..."
  
  # Determine build strategy based on Nix detection
  if [[ "$USE_EXISTING_NIX" == true ]]; then
    generate_nix_monorepo_dockerfile "$project_dir"
  else
    generate_npm_monorepo_dockerfile "$project_dir"
  fi
}

# Function: Generate Nix-based monorepo Dockerfile
function generate_nix_monorepo_dockerfile() {
  local project_dir="$1"
  
  log "Creating Nix-based multi-stage Dockerfile..."
  cat > "${project_dir}/Dockerfile" << EOF
# Stage 1: Build frontend using existing Nix flake
FROM nixos/nix:latest AS frontend-builder

# Enable flakes support
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /build

# Copy entire monorepo (to access flake.nix and frontend directory)
COPY . .

# Build using existing flake.nix
RUN $NIX_BUILD_CMD

# Stage 2: Nginx web server
FROM nginx:alpine

WORKDIR /opt/$PROJECT_NAME

# Install required packages
RUN apk add --no-cache curl

# Smart copy: Try multiple common Nix build result patterns
COPY --from=frontend-builder /build/result /tmp/nix-result
RUN set -e; \
    if [ -d "/tmp/nix-result/dist" ] && [ "\$(ls -A /tmp/nix-result/dist 2>/dev/null)" ]; then \
        echo "Detected build output in dist/ subdirectory"; \
        cp -r /tmp/nix-result/dist/* /usr/share/nginx/html/; \
    elif [ -d "/tmp/nix-result/build" ] && [ "\$(ls -A /tmp/nix-result/build 2>/dev/null)" ]; then \
        echo "Detected build output in build/ subdirectory"; \
        cp -r /tmp/nix-result/build/* /usr/share/nginx/html/; \
    elif [ -d "/tmp/nix-result/public" ] && [ "\$(ls -A /tmp/nix-result/public 2>/dev/null)" ]; then \
        echo "Detected build output in public/ subdirectory"; \
        cp -r /tmp/nix-result/public/* /usr/share/nginx/html/; \
    elif [ "\$(ls -A /tmp/nix-result 2>/dev/null)" ]; then \
        echo "Detected build output directly in result directory"; \
        cp -r /tmp/nix-result/* /usr/share/nginx/html/; \
    else \
        echo "ERROR: No build output found"; \
        echo "Contents of /tmp/nix-result:"; \
        ls -la /tmp/nix-result/; \
        exit 1; \
    fi && \
    rm -rf /tmp/nix-result

# Create SSL certificate directories (certificates will be mounted at runtime)
RUN mkdir -p /etc/ssl/certs /etc/ssl/private

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /var/log/nginx \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chown -R nginx:nginx /usr/share/nginx/html \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
}

# Function: Generate npm-based monorepo Dockerfile
function generate_npm_monorepo_dockerfile() {
  local project_dir="$1"
  
  log "Creating npm-based multi-stage Dockerfile..."
  cat > "${project_dir}/Dockerfile" << EOF
# Stage 1: Build frontend using npm
FROM node:18-alpine AS frontend-builder

WORKDIR /build

# Copy package files for dependency installation
COPY $FRONTEND_SUBDIR/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy frontend source code
COPY $FRONTEND_SUBDIR .

# Build the frontend
RUN ${FRONTEND_BUILD_CMD:-npm run build}

# Stage 2: Nginx web server
FROM nginx:alpine

WORKDIR /opt/$PROJECT_NAME

# Install required packages
RUN apk add --no-cache curl

# Copy built frontend from builder stage
COPY --from=frontend-builder /build/$BUILD_OUTPUT_DIR /usr/share/nginx/html

# Create SSL certificate directories (certificates will be mounted at runtime)
RUN mkdir -p /etc/ssl/certs /etc/ssl/private

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /var/log/nginx \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chown -R nginx:nginx /usr/share/nginx/html \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \\
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
EOF
}

# Function: Generate docker-compose.yml
function generate_docker_compose() {
  local project_dir="$1"
  
  log "Creating docker-compose.yml..."
  
  # Check if this is a monorepo project
  if [[ "$IS_MONOREPO" == true ]]; then
    generate_monorepo_docker_compose "$project_dir"
  else
    generate_standard_docker_compose "$project_dir"
  fi
}

# Function: Generate standard docker-compose.yml
function generate_standard_docker_compose() {
  local project_dir="$1"
  
  log "Creating standard docker-compose.yml..."
  cat > "${project_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${PROJECT_NAME}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ${FRONTEND_MOUNT}:/usr/share/nginx/html:ro
      - ./logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - ${PROJECT_NAME}-network
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DOMAIN_NAME=${DOMAIN_NAME}

networks:
  ${PROJECT_NAME}-network:
    external: true
EOF
}

# Function: Generate monorepo docker-compose.yml
function generate_monorepo_docker_compose() {
  local project_dir="$1"
  
  log "Creating monorepo docker-compose.yml..."
  cat > "${project_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${PROJECT_NAME}:
    build:
      context: ${MONOREPO_DIR}
      dockerfile: ${project_dir}/Dockerfile
    container_name: ${PROJECT_NAME}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./logs:/var/log/nginx
      - ./certs/cert.pem:/etc/ssl/certs/cert.pem:ro
      - ./certs/cert-key.pem:/etc/ssl/private/cert-key.pem:ro
    restart: unless-stopped
    networks:
      - ${PROJECT_NAME}-network
      - nginx-proxy-network
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DOMAIN_NAME=${DOMAIN_NAME}
      - IS_MONOREPO=true
      - MONOREPO_DIR=${MONOREPO_DIR}
      - FRONTEND_SUBDIR=${FRONTEND_SUBDIR}
      - BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR}

networks:
  ${PROJECT_NAME}-network:
    name: ${PROJECT_NAME}-network
  nginx-proxy-network:
    external: true
EOF
}

# Function: Generate nginx.conf
function generate_nginx_conf() {
  local project_dir="$1"
  
  log "Creating nginx.conf..."
  cat > "${project_dir}/nginx.conf" << EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Log format
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 80;
        server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
        
        # Include configuration files
        include /etc/nginx/conf.d/*.conf;
        
        # Root directory
        root /usr/share/nginx/html;
        index index.html;
        
        # Health check endpoint
        location /health {
            access_log off;
            add_header Content-Type text/plain;
            return 200 'OK';
        }
        
        # Default location
        location / {
            try_files \$uri \$uri/ =404;
        }
        
        # Error pages
        error_page 404 /404.html;
        location = /404.html {
            root /usr/share/nginx/html;
            internal;
        }
        
        error_page 500 502 503 504 /50x.html;
        location = /50x.html {
            root /usr/share/nginx/html;
            internal;
        }
    }
}
EOF
}

# Function: Generate configuration files
function generate_config_files() {
  local project_dir="$1"
  
  log "Creating configuration files..."
  
  # Create security.conf
  cat > "${project_dir}/conf.d/security.conf" << EOF
# Security settings
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self'; img-src 'self'; style-src 'self'; font-src 'self'; connect-src 'self'; frame-ancestors 'self'; form-action 'self';" always;

# Disable server tokens
server_tokens off;

# Prevent browser from caching sensitive data
add_header Cache-Control "no-store, no-cache, must-revalidate, proxy-revalidate, max-age=0" always;
EOF
  
  # Create compression.conf
  cat > "${project_dir}/conf.d/compression.conf" << EOF
# Compression settings
gzip on;
gzip_disable "msie6";
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_buffers 16 8k;
gzip_http_version 1.1;
gzip_min_length 256;
gzip_types
  application/atom+xml
  application/geo+json
  application/javascript
  application/json
  application/ld+json
  application/manifest+json
  application/rdf+xml
  application/rss+xml
  application/vnd.ms-fontobject
  application/wasm
  application/x-font-ttf
  application/x-javascript
  application/x-web-app-manifest+json
  application/xhtml+xml
  application/xml
  font/eot
  font/otf
  font/ttf
  image/bmp
  image/svg+xml
  text/cache-manifest
  text/calendar
  text/css
  text/javascript
  text/markdown
  text/plain
  text/vcard
  text/vnd.rim.location.xloc
  text/vtt
  text/x-component
  text/x-cross-domain-policy;
EOF
}

# Function: Generate HTML files
function generate_html_files() {
  local project_dir="$1"
  
  log "Creating HTML files..."
  
  # Create index.html
  cat > "${project_dir}/html/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${PROJECT_NAME} - ${DOMAIN_NAME}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            color: #333;
            background-color: #f4f4f4;
            text-align: center;
            padding: 50px 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #fff;
            padding: 30px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
        }
        p {
            margin-bottom: 20px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${PROJECT_NAME}</h1>
        <p>This site is running on ${DOMAIN_NAME}</p>
        <p>Nginx Multi-Project System</p>
    </div>
</body>
</html>
EOF
  
  # Create 404.html
  cat > "${project_dir}/html/404.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>404 - Page Not Found</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            color: #333;
            background-color: #f4f4f4;
            text-align: center;
            padding: 50px 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #fff;
            padding: 30px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #e74c3c;
        }
        p {
            margin-bottom: 20px;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>404 - Page Not Found</h1>
        <p>The page you are looking for does not exist.</p>
        <p><a href="/">Return to Homepage</a></p>
    </div>
</body>
</html>
EOF
  
  # Create 50x.html
  cat > "${project_dir}/html/50x.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Server Error</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            line-height: 1.6;
            margin: 0;
            padding: 0;
            color: #333;
            background-color: #f4f4f4;
            text-align: center;
            padding: 50px 20px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: #fff;
            padding: 30px;
            border-radius: 5px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #e74c3c;
        }
        p {
            margin-bottom: 20px;
        }
        a {
            color: #3498db;
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Server Error</h1>
        <p>Sorry, something went wrong on our end.</p>
        <p>Please try again later or contact the administrator.</p>
        <p><a href="/">Return to Homepage</a></p>
    </div>
</body>
</html>
EOF
  
  # Create health check directory and file
  mkdir -p "${project_dir}/html/health"
  echo "OK" > "${project_dir}/html/health/index.html"
}
