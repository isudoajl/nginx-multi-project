# Nix Integration Plan for Monorepo Container Setup

This document outlines the detailed plan for integrating Nix into the monorepo container setup, focusing on reproducible builds for both frontend and backend components.

## Core Principles

1. **Reproducible Builds**: Ensure builds are deterministic and reproducible across environments
2. **Minimal Dependencies**: Avoid unnecessary dependencies in the final container
3. **Framework Agnostic**: Support various frontend and backend frameworks
4. **Environment Consistency**: Maintain consistency between development and production
5. **Simplicity**: Keep configuration simple and maintainable

## Phase 1: Frontend Nix Integration

### 1. Nix Environment Detection

The script will detect if the monorepo is already using Nix by checking for:
- `flake.nix` or `default.nix` in the monorepo root
- `.envrc` with direnv configuration
- `shell.nix` for development environment

If Nix is already configured, the script will leverage the existing setup. Otherwise, it will generate appropriate Nix files.

### 2. Frontend Build Configuration

#### 2.1 Template for `frontend.nix`

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  # Detect Node.js version from .nvmrc or package.json
  nodeVersion = pkgs.lib.removeSuffix "\n" (builtins.readFile ./frontend/.nvmrc or "18");
  nodejs = pkgs.nodejs-${nodeVersion}_x;
in

pkgs.stdenv.mkDerivation {
  name = "{{PROJECT_NAME}}-frontend";
  src = ./frontend;
  
  buildInputs = with pkgs; [
    nodejs
    nodePackages.npm
    # Framework-specific dependencies will be added here
  ];
  
  buildPhase = ''
    # Setup environment
    export HOME=$TMPDIR
    cd $src
    
    # Install dependencies
    npm ci --no-audit --no-fund
    
    # Build frontend with environment variables
    export NODE_ENV=production
    export PUBLIC_URL="/"
    export REACT_APP_API_URL="/api"  # For React apps
    export VITE_API_URL="/api"       # For Vite apps
    
    npm run build
  '';
  
  installPhase = ''
    # Create output directory
    mkdir -p $out/dist
    
    # Copy build artifacts (adjust path based on framework)
    cp -r build/* $out/dist/
    # or: cp -r dist/* $out/dist/ (for Vite, Vue, etc.)
  '';
}
```

#### 2.2 Framework-Specific Configurations

The script will detect the frontend framework and adjust the Nix configuration accordingly:

##### React
```nix
# Additional dependencies
buildInputs = with pkgs; [
  nodejs
  nodePackages.npm
];

# Build output directory
installPhase = ''
  mkdir -p $out/dist
  cp -r build/* $out/dist/
'';
```

##### Vue/Vite
```nix
# Additional dependencies
buildInputs = with pkgs; [
  nodejs
  nodePackages.npm
];

# Build output directory
installPhase = ''
  mkdir -p $out/dist
  cp -r dist/* $out/dist/
'';
```

##### Angular
```nix
# Additional dependencies
buildInputs = with pkgs; [
  nodejs
  nodePackages.npm
];

# Build output directory
installPhase = ''
  mkdir -p $out/dist
  cp -r dist/{{PROJECT_NAME}}/* $out/dist/
'';
```

### 3. Nix Flake Support (Optional)

For projects using Nix flakes, the script can generate a `flake.nix` file:

```nix
{
  description = "{{PROJECT_NAME}} frontend";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = import ./frontend.nix { inherit pkgs; };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nodejs
            nodePackages.npm
          ];
        };
      }
    );
}
```

### 4. Multi-Stage Dockerfile with Nix

```dockerfile
# Stage 1: Build frontend with Nix
FROM nixos/nix:latest AS frontend-builder
WORKDIR /build

# Copy monorepo frontend directory
COPY {{MONOREPO_DIR}}/{{FRONTEND_DIR}} ./frontend

# Copy Nix configuration
COPY nix/frontend.nix .

# Build with Nix
RUN nix-build frontend.nix -o frontend-build

# Stage 2: Nginx web server
FROM nginx:alpine

# Copy built frontend from builder stage
COPY --from=frontend-builder /build/frontend-build/dist /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d

# Copy SSL certificates
COPY --chown=nginx:nginx certs/cert.pem /etc/ssl/certs/cert.pem
COPY --chown=nginx:nginx certs/cert-key.pem /etc/ssl/private/cert-key.pem

# Create required directories and set permissions
RUN mkdir -p /var/log/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### 5. Implementation Steps

1. **Detect Existing Nix Configuration**:
   ```bash
   if [[ -f "${MONOREPO_DIR}/flake.nix" || -f "${MONOREPO_DIR}/default.nix" ]]; then
     USE_EXISTING_NIX=true
     log "Using existing Nix configuration in monorepo"
   else
     USE_EXISTING_NIX=false
     log "No existing Nix configuration found, will generate new configuration"
   fi
   ```

2. **Detect Frontend Framework**:
   ```bash
   if [[ -f "${MONOREPO_DIR}/${FRONTEND_DIR}/package.json" ]]; then
     if grep -q "\"react-scripts\"" "${MONOREPO_DIR}/${FRONTEND_DIR}/package.json"; then
       FRONTEND_FRAMEWORK="react"
       BUILD_OUTPUT_DIR="build"
     elif grep -q "\"@angular/core\"" "${MONOREPO_DIR}/${FRONTEND_DIR}/package.json"; then
       FRONTEND_FRAMEWORK="angular"
       BUILD_OUTPUT_DIR="dist/${PROJECT_NAME}"
     elif grep -q "\"vue\"" "${MONOREPO_DIR}/${FRONTEND_DIR}/package.json"; then
       FRONTEND_FRAMEWORK="vue"
       BUILD_OUTPUT_DIR="dist"
     else
       FRONTEND_FRAMEWORK="generic"
       BUILD_OUTPUT_DIR="dist"
     fi
     log "Detected frontend framework: ${FRONTEND_FRAMEWORK}"
   fi
   ```

3. **Generate Nix Configuration**:
   ```bash
   generate_nix_config() {
     mkdir -p "${PROJECT_DIR}/nix"
     
     # Generate frontend.nix
     cat > "${PROJECT_DIR}/nix/frontend.nix" << EOF
     { pkgs ? import <nixpkgs> {} }:
     
     # ... (nix configuration based on detected framework)
     EOF
     
     log "Generated Nix configuration for ${FRONTEND_FRAMEWORK}"
   }
   ```

## Phase 2: Backend Nix Integration (Future)

### 1. Backend Framework Detection

The script will detect common backend frameworks and languages:

- Node.js (Express, Nest.js, etc.)
- Rust (with Cargo.toml)
- Go (with go.mod)
- Python (with requirements.txt or pyproject.toml)
- Java/Kotlin (with Maven or Gradle)

### 2. Backend Build Configuration

#### 2.1 Template for `backend.nix`

```nix
{ pkgs ? import <nixpkgs> {} }:

let
  # Language-specific setup will go here
in

pkgs.stdenv.mkDerivation {
  name = "{{PROJECT_NAME}}-backend";
  src = ./backend;
  
  buildInputs = with pkgs; [
    # Framework-specific dependencies will be added here
  ];
  
  buildPhase = ''
    # Build backend based on detected framework
  '';
  
  installPhase = ''
    # Create output directory
    mkdir -p $out/bin
    
    # Copy build artifacts
    cp -r {{BUILD_OUTPUT}} $out/bin/
  '';
}
```

#### 2.2 Framework-Specific Configurations

##### Node.js
```nix
buildInputs = with pkgs; [
  nodejs
  nodePackages.npm
];

buildPhase = ''
  export HOME=$TMPDIR
  npm ci --no-audit --no-fund
  npm run build
'';

installPhase = ''
  mkdir -p $out/bin
  cp -r . $out/bin/
'';
```

##### Rust
```nix
buildInputs = with pkgs; [
  rustc
  cargo
];

buildPhase = ''
  cargo build --release
'';

installPhase = ''
  mkdir -p $out/bin
  cp target/release/{{PROJECT_NAME}} $out/bin/
'';
```

##### Go
```nix
buildInputs = with pkgs; [
  go
];

buildPhase = ''
  export GOPATH=$TMPDIR/go
  export PATH=$GOPATH/bin:$PATH
  go build -o {{PROJECT_NAME}}
'';

installPhase = ''
  mkdir -p $out/bin
  cp {{PROJECT_NAME}} $out/bin/
'';
```

### 3. Extended Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build frontend with Nix
FROM nixos/nix:latest AS frontend-builder
# ... (frontend build steps)

# Stage 2: Build backend with Nix
FROM nixos/nix:latest AS backend-builder
WORKDIR /build

# Copy monorepo backend directory
COPY {{MONOREPO_DIR}}/{{BACKEND_DIR}} ./backend

# Copy Nix configuration
COPY nix/backend.nix .

# Build with Nix
RUN nix-build backend.nix -o backend-build

# Stage 3: Final image
FROM nginx:alpine

# Copy built frontend from builder stage
COPY --from=frontend-builder /build/frontend-build/dist /usr/share/nginx/html

# Copy built backend from builder stage
COPY --from=backend-builder /build/backend-build/bin /opt/{{PROJECT_NAME}}

# Install additional runtime dependencies based on backend
RUN apk add --no-cache curl {{RUNTIME_DEPENDENCIES}}

# Copy startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh

# Copy configuration files
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d

# Start both nginx and backend service
CMD ["/start.sh"]
```

### 4. Service Orchestration

Create a `start.sh` script to manage both services:

```bash
#!/bin/sh
set -e

# Start backend service
cd /opt/{{PROJECT_NAME}}
./{{BACKEND_BINARY}} &

# Start nginx
nginx -g "daemon off;"
```

## Implementation Workflow

### Phase 1 Implementation Steps

1. Update `args.sh` to support monorepo parameters
2. Create frontend framework detection in `project_functions.sh`
3. Implement Nix configuration generation in `project_files.sh`
4. Update Dockerfile generation for multi-stage builds
5. Test with sample monorepo project

### Phase 2 Implementation Steps (Future)

1. Add backend framework detection
2. Implement backend Nix configuration generation
3. Update Dockerfile for backend integration
4. Create service orchestration scripts
5. Update proxy configuration for API routing

## Testing Strategy

1. **Unit Testing**: Test individual script components
2. **Integration Testing**: Test end-to-end deployment workflow
3. **Framework Compatibility**: Test with various frontend frameworks
4. **Environment Compatibility**: Test in both DEV and PRO environments

## Conclusion

This Nix integration plan provides a comprehensive approach to incorporating Nix into the monorepo container setup, focusing first on frontend builds and later extending to backend services. The implementation prioritizes simplicity, reproducibility, and framework agnosticism while leveraging the power of Nix for deterministic builds. 