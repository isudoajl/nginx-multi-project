# Microservices Nginx Architecture - Technical Specifications

This document provides an overview of the technical specifications for the Microservices Nginx Architecture project. Each component has its own detailed specification document linked below.

## Architecture Overview

The Microservices Nginx Architecture is designed to provide a scalable, secure, and maintainable infrastructure for hosting multiple isolated web applications using Nginx and container technology. The system consists of:

1. **Central Nginx Proxy**: A reverse proxy that handles SSL termination, domain routing, and security features
2. **Project Containers**: Isolated containers for each project with their own Nginx instances
3. **Internal Container Networking**: Container-to-container communication without exposed ports
4. **Automation Scripts**: Comprehensive tooling for deployment and management
5. **Multi-Environment Support**: Development and production environment configurations
6. **Zero-Downtime Operations**: Incremental deployment without service disruption

## Key Components

### 1. Central Nginx Proxy

The central proxy is responsible for:
- SSL/TLS termination
- Domain-based routing
- Security headers and rate limiting
- Bad bot blocking
- HTTP to HTTPS redirection
- Container name-based DNS resolution

[Detailed Proxy Specification](nginx-proxy-spec.md)

### 2. Project Containers

Each project container supports both frontend-only and full-stack architectures:

**Frontend-Only Containers:**
- Isolated Nginx instance
- Project-specific configuration
- Static file serving
- Health check endpoints
- Security hardening

**Full-Stack Containers:**
- Multi-service architecture (nginx + backend)
- Framework-agnostic backend support (Rust, Node.js, Go, Python)
- API routing with `/api/*` → backend proxy
- Process management and health monitoring
- Internal port 80 (no host port exposure)

[Detailed Project Container Specification](project-container-spec.md)

### 3. Network Architecture

The network architecture provides:
- Shared proxy network for routing
- Isolated project networks
- Controlled communication paths
- Container name-based DNS resolution
- Internal container communication without port exposure

[Detailed Architecture Specification](architecture-spec.md)

### 4. Automation Scripts

The automation scripts provide:
- Project creation and deployment (frontend-only and full-stack)
- Framework detection and multi-stage container builds
- Certificate management
- Environment configuration
- Proxy integration with API routing
- Deployment verification and health monitoring
- Zero-downtime incremental deployment
- Internal networking setup

[Detailed Script Specification](script-spec.md)

### 5. Environment Management

The environment management system supports:
- Development environment with local DNS and self-signed certificates
- Production environment with Cloudflare integration
- Environment-specific configurations
- Seamless switching between environments

[Detailed Environment Specification](environment-spec.md)

### 6. Podman Integration

The Podman integration provides:
- Rootless container operation
- Reliable container networking
- Docker compatibility layer
- Network connectivity testing
- Internal container communication

[Detailed Podman Specification](podman-specs.md)

### 7. Testing Framework

The testing framework includes:
- Functional testing
- Integration testing
- Security testing
- Performance testing
- Deployment verification

[Detailed Testing Specification](testing-spec.md)

### 8. Cloudflare Integration (Production)

The Cloudflare integration provides:
- CDN capabilities
- Additional security layer
- DNS management
- SSL/TLS configuration

[Detailed Cloudflare Specification](cloudflare-spec.md)

## Technical Requirements

### System Requirements

- Linux-based operating system
- Nix package manager
- Podman or Docker
- Nginx
- OpenSSL
- Bash 4.0+

### Performance Requirements

- Support for 20+ concurrent projects
- 1000+ requests/second throughput
- <2ms SSL certificate negotiation
- <2 minute deployment time per project

### Security Requirements

- Modern SSL/TLS configuration
- Comprehensive security headers
- Rate limiting and DDoS protection
- Bad bot blocking
- Network isolation between projects
- No exposed ports for project containers

### Reliability Requirements

- Zero-downtime incremental deployment
- Self-healing infrastructure
- Automatic recovery from failure states
- Comprehensive health checks
- Detailed logging and error handling
- Container name-based DNS resolution

## Implementation Status

The project is currently in **PRODUCTION READY BETA** state with all core features implemented and tested. Recent major achievements include:

1. **✅ Full-Stack Deployment Support**: Complete backend framework integration (Rust, Node.js, Go, Python)
2. **✅ Multi-Service Container Architecture**: nginx + backend service coordination with health monitoring
3. **✅ Podman Integration**: Complete podman integration for rootless container operation with robust networking
4. **✅ Enterprise Documentation**: Comprehensive documentation and specification suite
5. **✅ Script Architecture Fixes**: Fixed critical script architecture issues in the modular project creation system
6. **✅ Incremental Deployment System**: Zero-downtime project addition to a running ecosystem
7. **✅ Internal Container Networking**: Refactored architecture to use container name-based communication without exposed ports
8. **✅ API Routing & Frontend-Backend Communication**: Fixed nginx proxy routing and automatic frontend API configuration
9. **✅ Template Automation**: Automated fixes for hardcoded API URLs in deployment templates

### Latest Beta Fixes (2025-07-23):

**Frontend-Backend Communication Resolution:**
- **Fixed nginx proxy routing**: Corrected `proxy_pass` configuration to preserve `/api/` paths
- **Automated API URL configuration**: Templates now automatically convert hardcoded `localhost` URLs to relative paths
- **Production-tested deployment**: Full-stack deployment verified with real-world monorepo (mapa-kms project)
- **Template consistency**: All Dockerfile templates (Nix, npm, monorepo) include automatic API configuration fixes

**Beta Status Verification:**
- ✅ Backend APIs responding correctly through nginx proxy
- ✅ Frontend successfully communicating with backend via `/api/*` routes
- ✅ Zero-downtime incremental deployment working
- ✅ Container networking and SSL termination operational
- ✅ Multi-framework support tested (Rust + React frontend)

For detailed implementation status, see the [Implementation Status](../IMPLEMENTATION_STATUS.md) document.