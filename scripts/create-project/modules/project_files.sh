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
  
  # Check if backend is enabled for full-stack deployment
  if [[ "$HAS_BACKEND" == "true" ]]; then
    log "Generating full-stack Dockerfile with backend support"
    if [[ "$USE_EXISTING_NIX" == true ]]; then
      generate_nix_fullstack_dockerfile "$project_dir"
    else
      generate_npm_fullstack_dockerfile "$project_dir"
    fi
  else
    log "Generating frontend-only Dockerfile"
    # Determine build strategy based on Nix detection
    if [[ "$USE_EXISTING_NIX" == true ]]; then
      generate_nix_monorepo_dockerfile "$project_dir"
    else
      generate_npm_monorepo_dockerfile "$project_dir"
    fi
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

# Fix common hardcoded API configurations for relative URLs (exclude node_modules)
RUN find . -path "*/node_modules" -prune -o -name "*.ts" -print -o -name "*.js" -print -o -name "*.tsx" -print -o -name "*.jsx" -print | \
    xargs grep -l "localhost:3000\|localhost:8000\|localhost:4000" 2>/dev/null | \
    head -10 | \
    while read file; do \
        [ -f "\$file" ] && sed -i "s/'http:\/\/localhost:[0-9]*'/''/g; s/\"http:\/\/localhost:[0-9]*\"/''/g; s/const API_BASE_URL = 'http:\/\/localhost:[0-9]*'/const API_BASE_URL = ''/g" "\$file" || true; \
    done || true

# Build the frontend (with API config for relative URLs)
RUN export REACT_APP_API_URL='' && export VITE_API_URL='' && ${FRONTEND_BUILD_CMD:-npm run build}

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

# Function: Generate Nix-based full-stack Dockerfile (frontend + backend)
function generate_nix_fullstack_dockerfile() {
  local project_dir="$1"
  
  log "Creating Nix-based full-stack Dockerfile..."
  cat > "${project_dir}/Dockerfile" << EOF
# Stage 1: Build frontend using existing Nix flake
FROM nixos/nix:latest AS frontend-builder

# Enable flakes support
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /build

# Copy entire monorepo (to access flake.nix and frontend directory)
COPY . .

# Fix common hardcoded API configurations for relative URLs (exclude node_modules)
RUN find . -path "*/node_modules" -prune -o -name "*.ts" -print -o -name "*.js" -print -o -name "*.tsx" -print -o -name "*.jsx" -print | \
    xargs grep -l "localhost:3000\|localhost:8000\|localhost:4000" 2>/dev/null | \
    head -10 | \
    while read file; do \
        [ -f "\$file" ] && perl -i -pe "s/'http:\/\/localhost:\d+'/''/g; s/\"http:\/\/localhost:\d+\"/''/g; s/const API_BASE_URL = 'http:\/\/localhost:\d+'/const API_BASE_URL = ''/g" "\$file" || true; \
    done || true

# Build frontend using Nix dev environment + build command (with API config)
RUN nix --extra-experimental-features "nix-command flakes" develop --command bash -c "cd $FRONTEND_SUBDIR && export REACT_APP_API_URL='' && export VITE_API_URL='' && ${FRONTEND_BUILD_CMD:-npm run build}"

# Stage 2: Build backend using Rust with musl for static linking
FROM rust:alpine AS backend-builder

# Install build dependencies for static linking
RUN apk add --no-cache musl-dev gcc libc-dev openssl-dev openssl-libs-static pkgconfig

WORKDIR /build

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Create .cargo/config.toml for static linking
RUN mkdir -p .cargo && \\
    echo '[target.x86_64-unknown-linux-musl]' > .cargo/config.toml && \\
    echo 'rustflags = ["-C", "target-feature=+crt-static"]' >> .cargo/config.toml

# Build backend using framework-specific approach
$(generate_backend_build_commands)

# Stage 3: Final multi-service image
FROM nginx:alpine

WORKDIR /opt/$PROJECT_NAME

# Install required packages for backend runtime
$(generate_backend_runtime_packages)

# Copy built frontend from frontend-builder stage
COPY --from=frontend-builder /build/$FRONTEND_SUBDIR/${BUILD_OUTPUT_DIR:-dist} /usr/share/nginx/html

# Copy built backend from backend-builder stage
$(generate_backend_copy_commands)

# Create SSL certificate directories (certificates will be mounted at runtime)
RUN mkdir -p /etc/ssl/certs /etc/ssl/private

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /var/log/nginx \\
    && mkdir -p /opt/backend \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chown -R nginx:nginx /usr/share/nginx/html \\
    && chmod -R 755 /var/log/nginx \\
    && chmod +x /opt/backend/* 2>/dev/null || true

# Copy startup script for multi-service management
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Health check (check both nginx and backend)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\
  CMD curl -f http://localhost/ && curl -f http://localhost:$BACKEND_PORT/health || exit 1

CMD ["/start.sh"]
EOF

  # Generate startup script for multi-service management
  generate_startup_script "$project_dir"
}

# Function: Generate npm-based full-stack Dockerfile (frontend + backend)
function generate_npm_fullstack_dockerfile() {
  local project_dir="$1"
  
  log "Creating npm-based full-stack Dockerfile..."
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

# Fix common hardcoded API configurations for relative URLs (exclude node_modules)
RUN find . -path "*/node_modules" -prune -o -name "*.ts" -print -o -name "*.js" -print -o -name "*.tsx" -print -o -name "*.jsx" -print | \
    xargs grep -l "localhost:3000\|localhost:8000\|localhost:4000" 2>/dev/null | \
    head -10 | \
    while read file; do \
        [ -f "\$file" ] && sed -i "s/'http:\/\/localhost:[0-9]*'/''/g; s/\"http:\/\/localhost:[0-9]*\"/''/g; s/const API_BASE_URL = 'http:\/\/localhost:[0-9]*'/const API_BASE_URL = ''/g" "\$file" || true; \
    done || true

# Build the frontend (with API config for relative URLs)
RUN export REACT_APP_API_URL='' && export VITE_API_URL='' && ${FRONTEND_BUILD_CMD:-npm run build}

# Stage 2: Build backend
$(generate_npm_backend_builder_stage)

# Stage 3: Final multi-service image
FROM nginx:alpine

WORKDIR /opt/$PROJECT_NAME

# Install required packages for backend runtime
$(generate_backend_runtime_packages)

# Copy built frontend from frontend-builder stage
COPY --from=frontend-builder /build/${BUILD_OUTPUT_DIR:-dist} /usr/share/nginx/html

# Copy built backend from backend-builder stage
$(generate_backend_copy_commands)

# Create SSL certificate directories (certificates will be mounted at runtime)
RUN mkdir -p /etc/ssl/certs /etc/ssl/private

# Create required directories and set permissions
RUN mkdir -p /etc/nginx/conf.d \\
    && mkdir -p /var/log/nginx \\
    && mkdir -p /opt/backend \\
    && chown -R nginx:nginx /var/log/nginx \\
    && chown -R nginx:nginx /usr/share/nginx/html \\
    && chmod -R 755 /var/log/nginx \\
    && chmod +x /opt/backend/* 2>/dev/null || true

# Copy startup script for multi-service management
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Health check (check both nginx and backend)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \\
  CMD curl -f http://localhost/ && curl -f http://localhost:$BACKEND_PORT/health || exit 1

CMD ["/start.sh"]
EOF

  # Generate startup script for multi-service management
  generate_startup_script "$project_dir"
}

# Function: Generate backend build commands based on framework
function generate_backend_build_commands() {
  case "${BACKEND_FRAMEWORK:-unknown}" in
    "rust")
      echo "# Build backend using Rust with musl for static linking"
      echo "RUN rustup target add x86_64-unknown-linux-musl"
      echo "RUN RUSTFLAGS=\"-C target-feature=+crt-static\" cargo build --release --target x86_64-unknown-linux-musl"
      ;;
    "nodejs")
      echo "# Build backend using Nix dev environment + npm"
      echo "RUN nix --extra-experimental-features \"nix-command flakes\" develop --command bash -c \"cd $BACKEND_SUBDIR && ${BACKEND_BUILD_CMD:-npm run build}\""
      ;;
    "go")
      echo "# Build backend using Nix dev environment + go"
      echo "RUN nix --extra-experimental-features \"nix-command flakes\" develop --command bash -c \"cd $BACKEND_SUBDIR && ${BACKEND_BUILD_CMD:-go build -o bin/ .}\""
      ;;
    "python")
      echo "# Build backend using Nix dev environment + python"
      echo "RUN nix --extra-experimental-features \"nix-command flakes\" develop --command bash -c \"cd $BACKEND_SUBDIR && ${BACKEND_BUILD_CMD:-pip install -r requirements.txt}\""
      ;;
    *)
      echo "# Generic backend build using Nix dev environment"
      echo "RUN nix --extra-experimental-features \"nix-command flakes\" develop --command bash -c \"cd $BACKEND_SUBDIR && ${BACKEND_BUILD_CMD:-echo 'No build command specified'}\""
      ;;
  esac
}

# Function: Generate npm backend builder stage
function generate_npm_backend_builder_stage() {
  case "${BACKEND_FRAMEWORK:-unknown}" in
    "nodejs")
      cat << EOF
# Stage 2: Build backend using npm
FROM node:18-alpine AS backend-builder

WORKDIR /build

# Copy backend package files
COPY $BACKEND_SUBDIR/package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Build the backend
RUN ${BACKEND_BUILD_CMD:-npm run build}
EOF
      ;;
    "rust")
      cat << EOF
# Stage 2: Build backend using Rust
FROM rust:alpine AS backend-builder

# Install build dependencies
RUN apk add --no-cache musl-dev gcc libc-dev

WORKDIR /build

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Build the backend
RUN ${BACKEND_BUILD_CMD:-cargo build --release}
EOF
      ;;
    "go")
      cat << EOF
# Stage 2: Build backend using Go
FROM golang:alpine AS backend-builder

WORKDIR /build

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Build the backend
RUN ${BACKEND_BUILD_CMD:-go build -o bin/ .}
EOF
      ;;
    "python")
      cat << EOF
# Stage 2: Prepare backend using Python
FROM python:alpine AS backend-builder

WORKDIR /build

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Install dependencies
RUN ${BACKEND_BUILD_CMD:-pip install -r requirements.txt --target ./packages}
EOF
      ;;
    *)
      cat << EOF
# Stage 2: Generic backend builder
FROM alpine AS backend-builder

WORKDIR /build

# Copy backend source code
COPY $BACKEND_SUBDIR .

# Generic build command (customize as needed)
RUN ${BACKEND_BUILD_CMD:-echo "No specific build command for backend framework"}
EOF
      ;;
  esac
}

# Function: Generate backend runtime packages
function generate_backend_runtime_packages() {
  case "${BACKEND_FRAMEWORK:-unknown}" in
    "rust")
      echo "RUN apk add --no-cache bash curl ca-certificates"
      ;;
    "nodejs")
      echo "RUN apk add --no-cache bash curl nodejs npm"
      ;;
    "go")
      echo "RUN apk add --no-cache bash curl ca-certificates"
      ;;
    "python")
      echo "RUN apk add --no-cache bash curl python3 py3-pip"
      ;;
    *)
      echo "RUN apk add --no-cache bash curl"
      ;;
  esac
}

# Function: Generate backend copy commands
function generate_backend_copy_commands() {
  case "${BACKEND_FRAMEWORK:-unknown}" in
    "rust")
      cat << EOF
# Copy statically linked backend from musl target directory
COPY --from=backend-builder /build/target/x86_64-unknown-linux-musl/release /tmp/backend-result
RUN mkdir -p /opt/backend && \\
    echo "Copying statically linked Rust backend binaries..."; \\
    find /tmp/backend-result -type f -executable ! -name "*.d" | while read binary; do \\
        binary_name=\$(basename "\$binary"); \\
        echo "Found backend binary: \$binary_name"; \\
        cp "\$binary" "/opt/backend/\$binary_name"; \\
    done && \\
    chmod +x /opt/backend/* 2>/dev/null || true && \\
    rm -rf /tmp/backend-result
EOF
      ;;
    "nodejs")
      echo "COPY --from=backend-builder /build/${BACKEND_OUTPUT_DIR:-dist} /opt/backend"
      ;;
    "go")
      echo "COPY --from=backend-builder /build/bin /opt/backend"
      ;;
    "python")
      cat << EOF
COPY --from=backend-builder /build /opt/backend
# Install Python packages in final image
RUN cd /opt/backend && pip install -r requirements.txt
EOF
      ;;
    *)
      echo "COPY --from=backend-builder /build /opt/backend"
      ;;
  esac
}

# Function: Generate startup script for multi-service management
function generate_startup_script() {
  local project_dir="$1"
  
  log "Creating startup script for multi-service management..."
  cat > "${project_dir}/start.sh" << EOF
#!/bin/bash

# Multi-service startup script for frontend + backend

set -e

# Function to log with timestamp
log() {
    echo "[\$(date '+%Y-%m-%d %H:%M:%S')] \$1"
}

# Function to start backend service
start_backend() {
    log "Starting backend service on port $BACKEND_PORT..."
    
    case "${BACKEND_FRAMEWORK:-unknown}" in
        "rust")
            # Find the main Rust binary and start it
            # Look for the main backend binary with common naming patterns
            if [[ -f "/opt/backend/$PROJECT_NAME" ]]; then
                backend_binary="/opt/backend/$PROJECT_NAME"
            elif [[ -f "/opt/backend/${PROJECT_NAME//-/_}" ]]; then
                backend_binary="/opt/backend/${PROJECT_NAME//-/_}"
            elif [[ -f "/opt/backend/${PROJECT_NAME//mapa-kms/mapas-km-backend}" ]]; then
                backend_binary="/opt/backend/${PROJECT_NAME//mapa-kms/mapas-km-backend}"
            else
                # Look for any *backend* binary without hash suffix, prioritizing over other binaries
                backend_binary=\$(find /opt/backend -type f -executable -name "*backend" ! -name "*-*" 2>/dev/null | head -n 1)
                if [[ -z "\$backend_binary" ]]; then
                    # Fallback to finding any backend binary that doesn't contain 'test' or 'populate'
                    backend_binary=\$(find /opt/backend -type f -executable ! -name "*test*" ! -name "*populate*" | head -n 1)
                fi
            fi
            
            if [[ -n "\$backend_binary" ]]; then
                log "Starting Rust backend: \$backend_binary"
                # Rust backend typically manages its own port configuration
                "\$backend_binary" &
            else
                log "ERROR: No Rust backend binary found in /opt/backend"
                exit 1
            fi
            ;;
        "nodejs")
            log "Starting Node.js backend"
            cd /opt/backend
            PORT=$BACKEND_PORT node index.js &
            ;;
        "go")
            # Find the main Go binary and start it
            backend_binary=\$(find /opt/backend -type f -executable | head -n 1)
            if [[ -n "\$backend_binary" ]]; then
                log "Starting Go backend: \$backend_binary"
                PORT=$BACKEND_PORT "\$backend_binary" &
            else
                log "ERROR: No Go backend binary found in /opt/backend"
                exit 1
            fi
            ;;
        "python")
            log "Starting Python backend"
            cd /opt/backend
            PORT=$BACKEND_PORT python3 main.py &
            ;;
        *)
            log "WARNING: Unknown backend framework '${BACKEND_FRAMEWORK:-unknown}', skipping backend startup"
            ;;
    esac
    
    BACKEND_PID=\$!
    log "Backend service started with PID: \$BACKEND_PID"
    
    # Wait for backend to be ready before starting nginx
    log "Waiting for backend to be ready..."
    for i in {1..30}; do
        if curl -f http://localhost:$BACKEND_PORT/health >/dev/null 2>&1; then
            log "Backend is ready!"
            break
        fi
        if [[ \$i -eq 30 ]]; then
            log "WARNING: Backend health check timeout after 30 seconds"
        fi
        sleep 1
    done
}

# Function to start nginx
start_nginx() {
    log "Starting Nginx frontend service..."
    nginx -g "daemon off;" &
    NGINX_PID=\$!
    log "Nginx started with PID: \$NGINX_PID"
}

# Function to handle shutdown
shutdown() {
    log "Shutting down services..."
    if [[ -n "\$BACKEND_PID" ]]; then
        log "Stopping backend service (PID: \$BACKEND_PID)"
        kill -TERM "\$BACKEND_PID" 2>/dev/null || true
    fi
    if [[ -n "\$NGINX_PID" ]]; then
        log "Stopping Nginx (PID: \$NGINX_PID)"
        kill -TERM "\$NGINX_PID" 2>/dev/null || true
    fi
    exit 0
}

# Set up signal handlers
trap shutdown SIGTERM SIGINT

# Start services
start_backend
start_nginx

# Wait for all background processes
wait
EOF

  chmod +x "${project_dir}/start.sh"
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
  
  # Check if backend is enabled to add backend-specific configuration
  local backend_env_vars=""
  local backend_volumes=""
  if [[ "$HAS_BACKEND" == "true" ]]; then
    backend_env_vars="
      - HAS_BACKEND=${HAS_BACKEND}
      - BACKEND_SUBDIR=${BACKEND_SUBDIR}
      - BACKEND_PORT=${BACKEND_PORT}
      - BACKEND_FRAMEWORK=${BACKEND_FRAMEWORK:-unknown}
      - DATABASE_URL=sqlite:${MONOREPO_DIR}/dev.db
      - FRONTEND_URL=https://${DOMAIN_NAME}"
    
    # Add database volume mount for backends that need it
    if [[ "${BACKEND_FRAMEWORK:-unknown}" == "rust" ]]; then
      backend_volumes="
      - ${MONOREPO_DIR}:${MONOREPO_DIR}"
    fi
  fi
  
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
      - ./certs/cert-key.pem:/etc/ssl/private/cert-key.pem:ro${backend_volumes}
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
      - BUILD_OUTPUT_DIR=${BUILD_OUTPUT_DIR}${backend_env_vars}

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
  
  # Check if backend is enabled to generate full-stack nginx config
  if [[ "$HAS_BACKEND" == "true" ]]; then
    generate_fullstack_nginx_conf "$project_dir"
  else
    generate_frontend_nginx_conf "$project_dir"
  fi
}

# Function: Generate frontend-only nginx.conf
function generate_frontend_nginx_conf() {
  local project_dir="$1"
  
  log "Creating frontend-only nginx.conf..."
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

# Function: Generate full-stack nginx.conf (frontend + backend)
function generate_fullstack_nginx_conf() {
  local project_dir="$1"
  
  log "Creating full-stack nginx.conf with backend API routing..."
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
    
    # Upstream backend server
    upstream backend {
        server localhost:${BACKEND_PORT};
    }
    
    server {
        listen 80;
        server_name ${DOMAIN_NAME} www.${DOMAIN_NAME};
        
        # Include configuration files
        include /etc/nginx/conf.d/*.conf;
        
        # Root directory for frontend
        root /usr/share/nginx/html;
        index index.html;
        
        # Health check endpoint
        location /health {
            access_log off;
            add_header Content-Type text/plain;
            return 200 'OK';
        }
        
        # Backend health check endpoint
        location /api/health {
            access_log off;
            proxy_pass http://backend/health;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
        }
        
        # API routes - proxy to backend
        location /api/ {
            proxy_pass http://backend;
            proxy_http_version 1.1;
            proxy_set_header Upgrade \$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_cache_bypass \$http_upgrade;
            
            # Timeout settings for backend
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Frontend routes - serve static files with fallback to index.html (SPA support)
        location / {
            try_files \$uri \$uri/ @fallback;
        }
        
        # Fallback for SPA routing
        location @fallback {
            try_files /index.html =404;
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
