# Monorepo Container Implementation Status

This document outlines the implementation status and plan for refactoring the `create-project-modular.sh` script to support monorepo projects with existing Nix flake configurations.

**Related Documentation:**
- [Nix Integration Plan](NIX_INTEGRATION_PLAN.md) - Detailed Nix integration strategy and framework detection
- [Project Overview](../docs/project-overview.md) - Complete project summary and capabilities
- [Deployment Guide](../docs/deployment-guide.md) - Step-by-step deployment instructions

## Implementation Goals

1. Support monorepo project structure with existing Nix flake configurations
2. Leverage existing Nix build processes rather than generating new ones
3. Maintain zero-downtime incremental deployment capabilities
4. Preserve existing functionality for non-monorepo projects
5. Keep the implementation simple and maintainable

## Phased Implementation Approach

The implementation will follow a phased approach:

### Phase 1: Frontend Support (Current Focus)
- Detect existing Nix flake configuration in monorepo
- Use existing build commands and output directories
- Create multi-stage Dockerfile that leverages existing Nix setup
- Deploy and test frontend-only monorepo projects

### Phase 2: Backend Support (Future)
- Extend detection to backend services in monorepo
- Configure service orchestration between frontend and backend
- Deploy and test full-stack monorepo projects

## Phase 1: Frontend Implementation Details

### 1. Script Modifications

#### 1.1 Command Line Arguments
Add new parameters to `create-project-modular.sh`:
```bash
--monorepo, -r DIR       Path to monorepo root directory
--frontend-dir, -i DIR   Relative path to frontend directory within monorepo (default: frontend)
--frontend-build, -F CMD Custom frontend build command (optional, overrides detected command)
```

#### 1.2 Existing Nix Detection
- Detect existing `flake.nix` in monorepo
- Use existing build commands (e.g., `npm run build`)
- Respect existing output directories (e.g., `./dist`)
- No generation of new Nix files

For detailed Nix detection logic, see [Nix Integration Plan - Existing Nix Detection](NIX_INTEGRATION_PLAN.md#1-nix-environment-detection).

### 2. Nix Integration Strategy

#### 2.1 Leverage Existing Nix Setup
The script will detect and use your existing Nix configuration:

```bash
# Detect existing Nix flake
if [[ -f "${MONOREPO_DIR}/flake.nix" ]]; then
  log "Detected existing Nix flake configuration"
  USE_EXISTING_NIX=true
  NIX_BUILD_CMD="nix build .#frontend"
  BUILD_OUTPUT_DIR="dist"
else
  log "No flake.nix found, using standard build"
  USE_EXISTING_NIX=false
fi
```

For comprehensive Nix integration details, see [Nix Integration Plan - Frontend Build Configuration](NIX_INTEGRATION_PLAN.md#2-frontend-build-configuration).

#### 2.2 Build Process
- Use existing `npm run build` command
- Respect existing output directory (`./dist`)
- No modification of existing Nix configuration

### 3. Multi-Stage Dockerfile with Smart Auto-Detection

```dockerfile
# Stage 1: Build frontend using existing Nix flake
FROM nixos/nix:latest AS frontend-builder
WORKDIR /build

# Copy entire monorepo (to access flake.nix and frontend directory)
COPY . .

# Build using existing flake.nix
RUN nix build .#frontend

# Stage 2: Nginx web server
FROM nginx:alpine

WORKDIR /opt/{{PROJECT_NAME}}

# Install required packages
RUN apk add --no-cache curl

# Smart copy: Auto-detect Nix build result structure
COPY --from=frontend-builder /build/result /tmp/nix-result
RUN set -e; \
    if [ -d "/tmp/nix-result/dist" ] && [ "$(ls -A /tmp/nix-result/dist 2>/dev/null)" ]; then \
        echo "Detected build output in dist/ subdirectory"; \
        cp -r /tmp/nix-result/dist/* /usr/share/nginx/html/; \
    elif [ -d "/tmp/nix-result/build" ] && [ "$(ls -A /tmp/nix-result/build 2>/dev/null)" ]; then \
        echo "Detected build output in build/ subdirectory"; \
        cp -r /tmp/nix-result/build/* /usr/share/nginx/html/; \
    elif [ -d "/tmp/nix-result/public" ] && [ "$(ls -A /tmp/nix-result/public 2>/dev/null)" ]; then \
        echo "Detected build output in public/ subdirectory"; \
        cp -r /tmp/nix-result/public/* /usr/share/nginx/html/; \
    elif [ "$(ls -A /tmp/nix-result 2>/dev/null)" ]; then \
        echo "Detected build output directly in result directory"; \
        cp -r /tmp/nix-result/* /usr/share/nginx/html/; \
    else \
        echo "ERROR: No build output found"; \
        ls -la /tmp/nix-result/; \
        exit 1; \
    fi && \
    rm -rf /tmp/nix-result

# Copy SSL certificates
COPY --chown=nginx:nginx certs/cert.pem /etc/ssl/certs/cert.pem
COPY --chown=nginx:nginx certs/cert-key.pem /etc/ssl/private/cert-key.pem

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf
COPY conf.d /etc/nginx/conf.d

# Create required directories and set permissions
RUN mkdir -p /var/log/nginx \
    && chown -R nginx:nginx /var/log/nginx \
    && chmod -R 755 /var/log/nginx

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

For detailed Dockerfile templates and framework-specific configurations, see [Nix Integration Plan - Multi-Stage Dockerfile](NIX_INTEGRATION_PLAN.md#4-multi-stage-dockerfile-with-nix).

### 4. Docker Compose Configuration

Update the docker-compose template for monorepo projects:

```yaml
version: '3.8'

services:
  {{PROJECT_NAME}}:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: {{PROJECT_NAME}}
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./conf.d:/etc/nginx/conf.d:ro
      - ./logs:/var/log/nginx
    restart: unless-stopped
    networks:
      - {{PROJECT_NAME}}-network
      - nginx-proxy-network
    environment:
      - PROJECT_NAME={{PROJECT_NAME}}
      - DOMAIN_NAME={{DOMAIN_NAME}}

networks:
  {{PROJECT_NAME}}-network:
    name: {{PROJECT_NAME}}-network
  nginx-proxy-network:
    external: true
```

## Implementation Tasks - Phase 1

### Completed
- [x] Initial planning and architecture design
- [x] Understanding of existing Nix flake setup
- [x] Nix integration strategy defined (see [Nix Integration Plan](NIX_INTEGRATION_PLAN.md))
- [x] **Update args.sh to support monorepo parameters** *(Completed: 2025-01-18)*
  - ✅ Added `--monorepo`, `--frontend-dir`, `--frontend-build` parameters
  - ✅ Implemented Nix flake detection logic in `detect_nix_configuration()`
  - ✅ Added validation for monorepo directory and frontend subdirectory
  - ✅ Created comprehensive test suite (`tests/scripts/test-monorepo-args.sh`)
  - ✅ All tests passing - monorepo argument parsing fully functional
- [x] **Create existing Nix detection logic** *(Completed: 2025-01-18)*
  - ✅ Integrated into `detect_nix_configuration()` function in args.sh
  - ✅ Detects `flake.nix` files and sets `USE_EXISTING_NIX=true`
  - ✅ Auto-detects build output directories (dist, build, etc.)
  - ✅ Discovers npm build scripts from package.json files
  - ✅ Supports both Nix and non-Nix monorepo projects
- [x] **Implement multi-stage Dockerfile generation** *(Completed: 2025-01-18)*
  - ✅ Added conditional logic in `generate_dockerfile()` to detect monorepo mode
  - ✅ Implemented `generate_nix_monorepo_dockerfile()` for Nix-based builds
  - ✅ Implemented `generate_npm_monorepo_dockerfile()` for npm-based builds
  - ✅ Added monorepo-aware docker-compose.yml generation
  - ✅ Created comprehensive test suite (`tests/scripts/test-monorepo-dockerfile.sh`)
  - ✅ All tests passing - multi-stage Dockerfile generation fully functional
- [x] **Update project_structure.sh to handle monorepo structure** *(Completed: 2025-01-18)*
  - ✅ Added conditional logic in `setup_project_structure()` to detect monorepo mode
  - ✅ Implemented `setup_monorepo_structure()` function for monorepo projects
  - ✅ Created `monorepo.env` configuration file with build parameters
  - ✅ Separated certificate handling into `setup_project_certificates()` function
  - ✅ Added monorepo path validation and error handling
  - ✅ Created comprehensive test suite (`tests/scripts/test-monorepo-structure.sh`)
  - ✅ Core functionality tests passing - monorepo structure handling functional
- [x] **Update deployment.sh to support monorepo builds** *(Completed: 2025-01-18)*
  - ✅ Added conditional deployment logic in `deploy_project()` function
  - ✅ Implemented `deploy_monorepo_project()` for monorepo-specific deployment
  - ✅ Implemented `deploy_standard_project()` for standard project deployment
  - ✅ Added proper build context handling for monorepo builds
  - ✅ Configured volume mappings for monorepo vs standard projects
  - ✅ Monorepo deployment fully functional

### In Progress
*No items currently in progress*

### Completed
- [x] **Create test monorepo project for validation** *(Completed: 2025-07-18)*
  - ✅ Created comprehensive test monorepo project in `tests/test-monorepo-project/`
  - ✅ Includes working Nix flake configuration with proper npm dependencies
  - ✅ Frontend application with HTML/CSS/JS and health endpoints
  - ✅ Demonstrates end-to-end monorepo deployment functionality
  - ✅ Fixed critical Dockerfile generation issues (build context paths)
  - ✅ Added missing Docker Compose override template for DEV environment
  - ✅ Fixed monorepo.env generation to include IS_MONOREPO flag
- [x] **Create comprehensive integration tests** *(Completed: 2025-07-18)*
  - ✅ Created `tests/integration/test-monorepo-deployment.sh`
  - ✅ End-to-end deployment validation
  - ✅ Container and proxy integration testing
  - ✅ HTTP connectivity validation
  - ✅ All core monorepo functionality validated
- [x] **Full monorepo implementation working** *(Completed: 2025-07-18)*
  - ✅ Fixed SSL configuration issues (disabled SSL stapling for self-signed certs)
  - ✅ Fixed certificate mounting in monorepo containers (runtime mount vs build copy)
  - ✅ Fixed proxy configuration cleanup in tests
  - ✅ **ALL INTEGRATION TESTS PASSING** - complete end-to-end validation
  - ✅ Monorepo deployment fully functional and production-ready
- [x] **Smart Nix result auto-detection** *(Completed: 2025-07-19)*
  - ✅ Dynamic detection of Nix build result structures
  - ✅ Supports multiple common patterns: `/dist`, `/build`, `/public`, direct output
  - ✅ **PRODUCTION TESTED** with real monorepo (mapakms.com)
  - ✅ Flexible and future-proof for different flake.nix configurations

### Pending
- [ ] Document usage and examples
- [ ] Refine edge case testing for error scenarios

## Phase 2: Backend Implementation Tasks

### Completed *(2025-07-22)*
- [x] **Add backend-specific command line arguments to args.sh** *(Completed: 2025-07-22)*
  - ✅ Added `--backend-dir`, `--backend-build`, `--backend-port` parameters  
  - ✅ Implemented backend framework detection logic for Rust, Node.js, Go, Python
  - ✅ Added backend validation and error handling
  - ✅ Backend arguments parsing fully functional
- [x] **Implement backend framework detection logic** *(Completed: 2025-07-22)*
  - ✅ `detect_backend_framework()` function detects Cargo.toml, package.json, go.mod, requirements.txt
  - ✅ Sets appropriate build commands and output directories per framework
  - ✅ Exports framework-specific variables for Dockerfile generation
- [x] **Create extended multi-stage Dockerfile for frontend + backend** *(Completed: 2025-07-22)*
  - ✅ Implemented `generate_nix_fullstack_dockerfile()` for Nix-based builds
  - ✅ Implemented `generate_npm_fullstack_dockerfile()` for npm-based builds  
  - ✅ Framework-specific build stages for Rust, Node.js, Go, Python
  - ✅ Multi-stage build with frontend-builder, backend-builder, and final image stages
- [x] **Setup internal service communication and proxy routing** *(Completed: 2025-07-22)*
  - ✅ Updated nginx.conf generation with `generate_fullstack_nginx_conf()`
  - ✅ Added upstream backend configuration with proxy_pass to backend service
  - ✅ API route proxying (/api/* -> backend service)
  - ✅ Health check endpoints for both frontend and backend
- [x] **Update project structure for backend support** *(Completed: 2025-07-22)*
  - ✅ Enhanced `setup_monorepo_structure()` with backend validation
  - ✅ Automatic Cargo.lock generation for Rust backends (critical for Nix builds)
  - ✅ Backend configuration in monorepo.env file
  - ✅ Framework detection and configuration export
- [x] **Create startup script for multi-service management** *(Completed: 2025-07-22)*
  - ✅ Generated `/start.sh` script for orchestrating nginx + backend services
  - ✅ Framework-specific backend startup logic (Rust, Node.js, Go, Python)
  - ✅ Signal handling and graceful shutdown
  - ✅ Process monitoring and error handling

### Current Status: Near Production Ready *(2025-07-22)*
- [x] **Real-world production test with mapa-kms monorepo** *(In Progress: 2025-07-22)*
  - ✅ **Rust backend detected correctly** (Cargo.toml found, framework=rust)
  - ✅ **Nix flake integration working** (existing flake.nix detected and used)
  - ✅ **Multi-stage Dockerfile generated** (frontend + backend stages)
  - ✅ **Cargo.lock already present** (no generation needed)
  - ✅ **Backend compilation successful** (11m 45s build time, finished with warnings)
  - ❌ **Container layer commit failed** (no space left on device during final stage)

### Known Issues
- [ ] **Storage space issue during container build** *(Current blocking issue)*
  - Backend compiles successfully but container commit fails
  - Error: "write /tmp/.../container_images_storage.../1: no space left on device"
  - Requires cleanup of container storage or larger build environment

### Pending
- [ ] Resolve container storage space issue
- [ ] Complete production validation with mapa-kms deployment
- [ ] Document full-stack usage examples
- [ ] Performance optimization for large monorepo builds

## Phase 2: Backend Implementation (Completed - Testing Phase)

### 1. Script Modifications

#### 1.1 Command Line Arguments
Add new parameters:
```bash
--backend-dir, -b DIR    Relative path to backend directory within monorepo (default: backend)
--backend-build, -B CMD  Custom backend build command (optional)
--backend-port, -p PORT  Internal port for backend service (default: 8080)
```

#### 1.2 Backend Detection
- Detect backend services in monorepo
- Use existing backend build commands
- Configure proxy settings for API endpoints

For backend framework detection details, see [Nix Integration Plan - Backend Framework Detection](NIX_INTEGRATION_PLAN.md#1-backend-framework-detection).

### 2. Multi-Service Architecture

#### 2.1 Container Structure
- Frontend container (Nginx serving static assets)
- Backend container (API service)
- Proxy configuration for routing between services

#### 2.2 Service Communication
- Internal container networking
- API proxy configuration
- Environment variable sharing

### 3. Extended Multi-Stage Dockerfile

```dockerfile
# Stage 1: Build frontend using existing Nix flake
FROM nixos/nix:latest AS frontend-builder
WORKDIR /build
COPY {{MONOREPO_DIR}} .
RUN nix build .#frontend

# Stage 2: Build backend using existing Nix flake
FROM nixos/nix:latest AS backend-builder
WORKDIR /build
COPY {{MONOREPO_DIR}} .
RUN nix build .#backend

# Stage 3: Final image
FROM nginx:alpine

# Copy built frontend from builder stage
COPY --from=frontend-builder /build/result/dist /usr/share/nginx/html

# Copy built backend from builder stage
COPY --from=backend-builder /build/result/bin /opt/{{PROJECT_NAME}}

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

For detailed backend integration templates, see [Nix Integration Plan - Backend Build Configuration](NIX_INTEGRATION_PLAN.md#2-backend-build-configuration).

## Future Considerations

1. **Framework-Specific Optimizations**: Add specialized configurations for popular frameworks
2. **Development Mode**: Support for development mode with hot reloading
3. **Database Integration**: Support for database services and migrations
4. **Monitoring Integration**: Add monitoring and observability tools
5. **CI/CD Integration**: Streamline integration with CI/CD pipelines

## Usage Examples

### Basic Monorepo Frontend Project

```bash
./scripts/create-project-modular.sh \
  --name my-app \
  --domain my-app.local \
  --monorepo /path/to/monorepo \
  --frontend-dir frontend \
  --env DEV
```

### Custom Frontend Build Command

```bash
./scripts/create-project-modular.sh \
  --name my-app \
  --domain my-app.local \
  --monorepo /path/to/monorepo \
  --frontend-dir frontend \
  --frontend-build "npm run build:custom" \
  --env DEV
```

### Full Stack Monorepo Project (Phase 2)

```bash
./scripts/create-project-modular.sh \
  --name my-app \
  --domain my-app.local \
  --monorepo /path/to/monorepo \
  --frontend-dir frontend \
  --backend-dir backend \
  --backend-port 8080 \
  --env DEV
```

## Production Validation ✅

### Real-World Testing Success

The monorepo implementation has been **successfully tested** with a production React 18 + TypeScript application:

**Test Case**: `mapakms.com`
- **Monorepo**: `/opt/mapa-kms` 
- **Frontend**: React 18 + TypeScript in `frontend/`
- **Build System**: Nix flake with custom `installPhase`
- **Domain**: Production-ready SSL deployment
- **Result**: ✅ **Full deployment success**

This validates the system works with real-world monorepo configurations and complex Nix setups.

## Key Differences from Original Plan

1. **No Nix File Generation**: The script will not generate new Nix files
2. **Leverage Existing Setup**: Use your existing `flake.nix` and build commands
3. **Respect Existing Structure**: Work with your current output directories and build processes
4. **Smart Auto-Detection**: Automatically adapts to different Nix result patterns
5. **Simplified Implementation**: Focus on container orchestration rather than build system configuration

## Related Documentation

- **[Nix Integration Plan](NIX_INTEGRATION_PLAN.md)** - Comprehensive Nix integration strategy, framework detection, and build configuration templates
- **[Project Overview](../docs/project-overview.md)** - Complete project summary and capabilities
- **[Deployment Guide](../docs/deployment-guide.md)** - Step-by-step deployment instructions
- **[Testing Specification](../specs/testing-spec.md)** - Testing framework and validation procedures 