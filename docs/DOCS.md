# Microservices Nginx Architecture - Documentation

**Status: PRODUCTION READY BETA** - Full-stack deployment with frontend-backend communication working as expected!

This document provides a comprehensive overview of the documentation available for the Microservices Nginx Architecture project. The documentation is organized by user role and use case to help you find the information you need quickly.

## 🎉 Latest Beta Release (2025-07-23)

**Frontend-Backend Communication Now Working!**
- ✅ **API Routing Fixed**: nginx proxy now correctly routes `/api/*` requests to backend services
- ✅ **Automated Configuration**: Templates automatically fix hardcoded API URLs during build
- ✅ **Production Tested**: Real-world deployment verified with Rust backend + React frontend
- ✅ **Zero-Downtime Updates**: Incremental deployment working without service disruption

## Quick Start

- [README.md](../README.md) - Project overview and quick start guide
- [Deployment Guide](deployment-guide.md) - Step-by-step deployment instructions
- [Project Container Guide](project-container-guide.md) - Guide for creating and managing project containers

## User Guides

### For System Administrators

- [Project Overview](project-overview.md) - Complete project summary and capabilities
- [Deployment Guide](deployment-guide.md) - From-scratch and incremental deployment scenarios
- [Production Port Forwarding](production-port-forwarding.md) - Setting up port forwarding for production
- [Troubleshooting Guide](troubleshooting-guide.md) - Common issues and debugging
- [Unprivileged Ports Setup](unprivileged-ports-setup.md) - Setting up unprivileged ports

### For Developers

- [Project Container Guide](project-container-guide.md) - User guide for project creation
- [Project Container Architecture](project-container-architecture.md) - Technical implementation details
- [How It Works](how-it-works.md) - Technical architecture explanation
- [Podman Integration](podman-integration.md) - Podman setup and configuration
- [Git Workflow](git-workflow.md) - Git workflow for the project

### For DevOps Engineers

- [Script API Reference](script-api-reference.md) - Automation script documentation
- [Deployment Guide](deployment-guide.md) - From-scratch and incremental deployment scenarios
- [Podman Integration](podman-integration.md) - Podman setup and configuration
- [Production Port Forwarding](production-port-forwarding.md) - Setting up port forwarding for production

## Technical Documentation

- [Project Container Architecture](project-container-architecture.md) - Technical implementation details
- [How It Works](how-it-works.md) - Technical architecture explanation
- [Script API Reference](script-api-reference.md) - Automation script documentation

## Environment-Specific Documentation

### Development Environment

- [Unprivileged Ports Setup](unprivileged-ports-setup.md) - Setting up unprivileged ports
- [Project Container Guide](project-container-guide.md) - User guide for project creation

### Production Environment

- [Production Port Forwarding](production-port-forwarding.md) - Setting up port forwarding for production
- [Deployment Guide](deployment-guide.md) - From-scratch and incremental deployment scenarios

## Troubleshooting

- [Troubleshooting Guide](troubleshooting-guide.md) - Common issues and debugging

## Technical Specifications

For detailed technical specifications, please refer to the [specs](../specs/SPECS.md) directory.

## Key Features Documentation

### Zero-Downtime Incremental Deployment

The system supports adding new projects to a running ecosystem without disrupting existing services:

```bash
# Frontend-only incremental deployment
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name second-app \
  --domain second-app.com \
  --env PRO

# Full-stack incremental deployment
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name fullstack-app \
  --domain fullstack-app.com \
  --monorepo /path/to/monorepo \
  --frontend-dir frontend \
  --backend-dir backend \
  --env PRO
```

For more details, see the [Deployment Guide](deployment-guide.md).

### Self-Healing Infrastructure

The system includes self-healing capabilities that automatically recover from failure states:

- Automatic proxy detection (running/stopped/missing)
- Self-healing proxy creation from scratch
- Network orchestration and SSL certificate management
- Comprehensive health verification and integration testing

For more details, see the [How It Works](how-it-works.md) document.

### Multi-Environment Support

The system supports both development and production environments:

- Development environment with local DNS and self-signed certificates
- Production environment with Cloudflare integration
- Environment-specific configurations
- Seamless switching between environments

For more details, see the [Deployment Guide](deployment-guide.md).

### Podman Integration

The system includes complete podman integration for rootless container operation:

- Rootless container operation without root privileges
- Container networking with reliable communication
- Docker compatibility layer for seamless transition
- Network connectivity testing

For more details, see the [Podman Integration](podman-integration.md) document.

### Internal Container Networking

The system uses container name-based communication without exposed ports:

- No port conflicts between projects
- Enhanced security through port isolation
- Simplified container management
- Container name-based DNS resolution
- Internal communication without host port exposure

For more details, see the [Project Container Architecture](project-container-architecture.md) document.

### Full-Stack Deployment Support ✅ WORKING

The system now supports comprehensive full-stack deployments with integrated frontend and backend services:

- **✅ Multi-Framework Backend Support**: Rust, Node.js, Go, Python
- **✅ Multi-Service Containers**: nginx + backend application server
- **✅ API Routing**: Automatic `/api/*` → backend proxy configuration **[FIXED]**
- **✅ Framework Detection**: Automatic build system detection and configuration
- **✅ Process Management**: Coordinated startup and health monitoring
- **✅ Monorepo Integration**: Support for existing Nix flake configurations
- **✅ Frontend-Backend Communication**: Automatic API URL configuration **[NEW]**

**Latest Fixes in Beta Release:**
- **Fixed nginx proxy routing**: `/api/*` requests now correctly reach backend services
- **Automated API configuration**: Templates automatically convert hardcoded URLs to relative paths
- **Production verified**: Real-world testing with mapa-kms project (Rust + React)

Example full-stack deployment:
```bash
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name my-rust-app \
  --domain my-rust-app.com \
  --monorepo /opt/my-rust-app \
  --frontend-dir frontend \
  --backend-dir backend \
  --backend-port 3000 \
  --env PRO
```

For more details, see the [Deployment Guide](deployment-guide.md) and [Project Container Guide](project-container-guide.md). 