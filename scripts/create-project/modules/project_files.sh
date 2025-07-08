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
  
  # Check if using Nix build
  if [[ "$USE_NIX_BUILD" == true ]]; then
    generate_nix_dockerfile "$project_dir"
  else
    # Standard Dockerfile
    cat > "${project_dir}/Dockerfile" << EOF
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl supervisor bash nix nodejs npm

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

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF
  fi
}

# Function: Generate Nix-compatible Dockerfile
function generate_nix_dockerfile() {
  local project_dir="$1"
  
  log "Creating Nix-compatible Dockerfile..."
  
  # First, create the health check HTML file separately
  mkdir -p "${project_dir}/html/health"
  cat > "${project_dir}/html/health/index.html" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Health Check</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
            padding: 0;
            background-color: #f7f7f7;
        }
        .container {
            max-width: 600px;
            margin: 0 auto;
            background-color: #fff;
            padding: 20px;
            border-radius: 5px;
            box-shadow: 0 2px 5px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2ecc71;
            margin-top: 0;
        }
        .status {
            padding: 10px;
            background-color: #e8f8f5;
            border-left: 4px solid #2ecc71;
            margin-bottom: 20px;
        }
        .details {
            margin-top: 20px;
        }
        .details p {
            margin: 5px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Health Check</h1>
        <div class="status">
            <strong>Status:</strong> OK
        </div>
        <div class="details">
            <p><strong>Service:</strong> Frontend</p>
            <p><strong>Time:</strong> <span id="current-time"></span></p>
            <p><strong>Container:</strong> ${PROJECT_NAME}</p>
            <p><strong>Domain:</strong> ${DOMAIN_NAME}</p>
        </div>
    </div>
    <script>
        // Update current time
        function updateTime() {
            document.getElementById("current-time").textContent = new Date().toISOString();
        }
        updateTime();
        setInterval(updateTime, 1000);
    </script>
</body>
</html>
EOF
  
  # Determine the CMD based on whether backend is specified
  local cmd_instruction
  if [ -n "${BACKEND_PATH}" ]; then
    cmd_instruction='CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]'
  else
    cmd_instruction='CMD ["nginx", "-g", "daemon off;"]'
  fi
  
  # Now create the Dockerfile without the problematic multi-line string
  cat > "${project_dir}/Dockerfile" << EOF
# Multi-stage build for Nix-based projects
FROM nixos/nix:latest AS builder

# Copy monorepo
COPY ${MONO_REPO_PATH} /opt/${PROJECT_NAME}
WORKDIR /opt/${PROJECT_NAME}

# Detect and use flake.nix for building frontend
RUN if [ -f flake.nix ]; then \\
      cd ${FRONTEND_PATH} && \\
      nix --extra-experimental-features "nix-command flakes" develop --command bash -c "${FRONTEND_BUILD_CMD}" && \\
      echo "Frontend build completed successfully"; \\
    else \\
      echo "Error: flake.nix not found" && exit 1; \\
    fi

# Build backend if specified
$([ -n "${BACKEND_PATH}" ] && echo "# Build backend
RUN if [ -f flake.nix ]; then \\
      cd ${BACKEND_PATH} && \\
      nix --extra-experimental-features \"nix-command flakes\" develop --command bash -c \"${BACKEND_BUILD_CMD}\" && \\
      echo \"Backend build completed successfully\"; \\
    else \\
      echo \"Error: flake.nix not found\" && exit 1; \\
    fi" || echo "# No backend to build")

# Final image
FROM nginx:alpine

# Install required packages
RUN apk add --no-cache curl supervisor bash nix nodejs npm

# Create required directories
RUN mkdir -p /etc/nginx/conf.d \
    && mkdir -p /usr/share/nginx/html \
    && mkdir -p /var/log/nginx \
    && mkdir -p /opt/backend \
    && mkdir -p /etc/supervisor/conf.d \
    && mkdir -p /usr/share/nginx/html/health \
    && mkdir -p /var/run \
    && touch /var/run/supervisord.sock \
    && chmod 777 /var/run/supervisord.sock

# Copy SSL certificates
COPY --chown=nginx:nginx certs/cert.pem /etc/ssl/certs/cert.pem
COPY --chown=nginx:nginx certs/cert-key.pem /etc/ssl/private/cert-key.pem

# Copy built frontend from builder stage
COPY --from=builder /opt/${PROJECT_NAME}/${FRONTEND_PATH}/${FRONTEND_BUILD_DIR} /usr/share/nginx/html

# Copy health check file
COPY html/health/index.html /usr/share/nginx/html/health/index.html

# Copy backend if specified
$([ -n "${BACKEND_PATH}" ] && echo "# Copy backend code
COPY --from=builder /opt/${PROJECT_NAME}/${BACKEND_PATH} /opt/backend
# CRITICAL FIX: Copy flake.nix to backend directory
COPY --from=builder /opt/${PROJECT_NAME}/flake.nix /opt/backend/flake.nix" || echo "# No backend specified")

# Set permissions
RUN chown -R nginx:nginx /var/log/nginx \\
    && chown -R nginx:nginx /usr/share/nginx/html \\
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\
  CMD curl -f http://localhost/health/ || exit 1

# Expose port
EXPOSE 80

# Start command
${cmd_instruction}
EOF

  # Create supervisord.conf if backend is specified
  if [ -n "${BACKEND_PATH}" ]; then
    log "Creating supervisord.conf..."
    cat > "${project_dir}/supervisord.conf" << EOF
[supervisord]
nodaemon=true
user=root
logfile=/var/log/supervisord.log
logfile_maxbytes=50MB
logfile_backups=10
loglevel=info
pidfile=/var/run/supervisord.pid

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
startretries=5
numprocs=1
startsecs=0
process_name=%(program_name)s_%(process_num)02d
stderr_logfile=/var/log/nginx/error.log
stderr_logfile_maxbytes=10MB
stdout_logfile=/var/log/nginx/access.log
stdout_logfile_maxbytes=10MB

[program:backend]
command=sh -c "cd /opt/backend && npm install && ${BACKEND_START_CMD}"
directory=/opt/backend
autostart=true
autorestart=true
startretries=5
numprocs=1
startsecs=10
user=root
redirect_stderr=true
stdout_logfile=/var/log/backend.log
stdout_logfile_maxbytes=10MB
environment=NODE_ENV=development,PORT=3000,PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

[supervisord:info]
nocleanup=true

[unix_http_server]
file=/var/run/supervisord.sock
chmod=0700
username=dummy
password=dummy

[supervisorctl]
serverurl=unix:///var/run/supervisord.sock
username=dummy
password=dummy

[include]
files = /etc/supervisor/conf.d/*.conf
EOF
  fi
}

# Function: Generate docker-compose.yml
function generate_docker_compose() {
  local project_dir="$1"
  
  log "Creating docker-compose.yml..."
  
  # Process environment variables if specified
  local env_vars_config=""
  if [[ -n "${PROJECT_ENV_VARS}" ]]; then
    log "Processing environment variables..."
    env_vars_config="      # Custom environment variables\n"
    
    # Convert comma-separated list to individual environment variables
    IFS=',' read -ra ENV_VARS_ARRAY <<< "${PROJECT_ENV_VARS}"
    for env_var in "${ENV_VARS_ARRAY[@]}"; do
      env_vars_config+="      - ${env_var}\n"
    done
  fi
  
  # Create health check configuration
  local health_check_config="    healthcheck:\n      test: [\"CMD\", \"curl\", \"-f\", \"http://localhost/health/\"]\n      interval: 30s\n      timeout: 10s\n      retries: 3\n      start_period: 10s"
  
  # For Nix build, we need to add the monorepo as a build context
  if [[ "$USE_NIX_BUILD" == true ]]; then
    # CRITICAL FIX: Let docker-compose/podman-compose use default image naming
    cat > "${project_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${PROJECT_NAME}:
    # Let docker-compose/podman-compose use its default image naming
    # We pre-build the image with the exact name it will look for
    build:
      context: .
      dockerfile: Dockerfile
    container_name: ${PROJECT_NAME}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./logs:/var/log/nginx
$([ -n "${BACKEND_PATH}" ] && echo "      - ./supervisord.conf:/etc/supervisor/conf.d/supervisord.conf:ro" || echo "")
    restart: unless-stopped
    networks:
      - ${PROJECT_NAME}-network
      # Proxy network will be connected during deployment
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DOMAIN_NAME=${DOMAIN_NAME}
$([ -n "${env_vars_config}" ] && echo -e "${env_vars_config}" || echo "")
$([ -n "${health_check_config}" ] && echo -e "${health_check_config}" || echo "")

networks:
  ${PROJECT_NAME}-network:
    name: ${PROJECT_NAME}-network
    external: true
EOF
  else
    # Standard docker-compose.yml for non-Nix build
    cat > "${project_dir}/docker-compose.yml" << EOF
version: '3.8'

services:
  ${PROJECT_NAME}:
    # Let docker-compose/podman-compose use its default image naming
    # We pre-build the image with the exact name it will look for
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
      # Proxy network will be connected during deployment
    environment:
      - PROJECT_NAME=${PROJECT_NAME}
      - DOMAIN_NAME=${DOMAIN_NAME}
$([ -n "${env_vars_config}" ] && echo -e "${env_vars_config}" || echo "")
$([ -n "${health_check_config}" ] && echo -e "${health_check_config}" || echo "")

networks:
  ${PROJECT_NAME}-network:
    name: ${PROJECT_NAME}-network
    external: true
EOF
  fi
  
  log "docker-compose.yml created successfully"
}

# Function: Generate nginx.conf
function generate_nginx_conf() {
  local project_dir="$1"
  
  log "Creating nginx.conf..."
  
  # Base nginx configuration
  local nginx_conf="user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    multi_accept on;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Log format
    log_format main '\$remote_addr - \$remote_user [\$time_local] \"\$request\" '
                    '\$status \$body_bytes_sent \"\$http_referer\" '
                    '\"\$http_user_agent\" \"\$http_x_forwarded_for\"';
    
    access_log /var/log/nginx/access.log main;
    
    # Basic settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    # Include additional configurations
    include /etc/nginx/conf.d/*.conf;
    
    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
        
        # Root directory for frontend static files
        root /usr/share/nginx/html;
        index index.html;
        
        # Health check endpoint for container health monitoring
        location /health/ {
            access_log off;
            add_header Content-Type text/plain;
            return 200 'OK\n';
        }
"

  # Add backend proxy if backend is specified
  if [ -n "${BACKEND_PATH}" ]; then
    nginx_conf+="
        # Backend API proxy
        location /api/ {
            # Proxy to the backend service running in the container
            proxy_pass http://localhost:3000/;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeouts
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # CRITICAL FIX: Add error logging for debugging
            error_log /var/log/nginx/backend_error.log debug;
            access_log /var/log/nginx/backend_access.log;
        }

        # Backend health check endpoint - both with and without trailing slash
        location = /api/health {
            proxy_pass http://localhost:3000/health;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            access_log /var/log/nginx/health_access.log;
            error_log /var/log/nginx/health_error.log debug;
        }
        
        location = /api/health/ {
            proxy_pass http://localhost:3000/health;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            access_log /var/log/nginx/health_access.log;
            error_log /var/log/nginx/health_error.log debug;
        }
"
  fi

  # Add default location and error pages
  nginx_conf+="        
        # Static files handling
        location / {
            try_files \$uri \$uri/ /index.html;
        }

        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|webp|woff|woff2|ttf|otf|eot|mp4)$ {
            expires max;
            log_not_found off;
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
"

  # Write the nginx.conf file
  echo "$nginx_conf" > "${project_dir}/nginx.conf"
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
  
  # Only generate HTML files if not using Nix build
  if [[ "$USE_NIX_BUILD" == false ]]; then
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
  else
    log "Skipping HTML file generation for Nix build..."
    
    # Create health directory for health checks
    mkdir -p "${project_dir}/html/health"
  fi
}
