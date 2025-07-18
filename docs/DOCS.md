# Microservices Nginx Architecture - Documentation

This document provides a comprehensive overview of the documentation available for the Microservices Nginx Architecture project. The documentation is organized by user role and use case to help you find the information you need quickly.

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
# Incremental deployment - existing projects remain untouched
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name second-app \
  --port 8091 \
  --domain second-app.com \
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