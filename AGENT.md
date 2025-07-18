# AGENT.md - Nginx Multi-Project Architecture

## Project Overview

**Status**: PRODUCTION READY with comprehensive documentation suite
**Key Features**: Zero-downtime incremental deployment, self-healing infrastructure, multi-environment support, internal container networking

## Build/Test/Lint Commands

**Enter Nix Environment (REQUIRED for all commands):**
```bash
nix --extra-experimental-features "nix-command flakes" develop
```

**Test Commands:**
- Run all tests: `./tests/test-proxy-container.sh`
- Test network connectivity: `./tests/integration/test-network-connectivity.sh`
- Test project creation: `./tests/scripts/test-create-project.sh`
- Test environment setup: `./tests/scripts/test-dev-environment.sh`

**Build/Deploy Commands:**
- Create project: `./scripts/create-project-modular.sh --name <name> --domain <domain> --port <port> --env <PRO|DEV>`
- Manage proxy: `./scripts/manage-proxy.sh --action <start|stop|restart|status>`
- Development environment: `./scripts/dev-environment.sh --project <name> --action <setup|start|stop>`
- Restart project safely: `./scripts/restart-project.sh --name <project>`

**Cleanup Commands:**
- Fresh restart: `./scripts/fresh-restart.sh`
- Podman cleanup: `./scripts/cleanup-podman.sh`

## Architecture Overview

**Core Components:**
- **nginx-proxy** (ports 8080/8443): Central reverse proxy container
- **Project containers** (custom ports): Isolated nginx containers per project
- **Network isolation**: Each project on separate network + shared proxy network
- **SSL termination**: Centralized at proxy level with domain-based routing

**Key Directories:**
- `proxy/`: Central proxy configuration and certificates
- `projects/`: Individual project containers and configurations
- `scripts/`: Automation scripts for deployment and management
- `tests/`: Comprehensive test suite for validation
- `certs/`: Global SSL certificates (required before deployment)

## Code Style & Conventions

**Shell Scripts:**
- Use `#!/bin/bash` shebang
- Check Nix environment: `[ -z "$IN_NIX_SHELL" ]` before operations
- Function naming: `snake_case` with descriptive names
- Error handling: Exit codes and colored output (GREEN/RED/NC)
- Log to `logs/` directories with timestamped entries

**Container Operations:**
- Always use `podman` through Nix environment
- Network management: Connect containers to `nginx-proxy-network`
- Certificate management: Copy to both `certs/` and `proxy/certs/` locations
- Configuration validation: `nginx -t` before reload
- Incremental deployment: Preserve existing project configurations

**Critical Security Rules:**
- SSL certificates REQUIRED in `certs/` before project creation
- Ports 8080/8443 reserved for proxy (use 809x for projects)
- Domain-based routing with HTTPS redirect enforcement
- Network isolation between projects maintained

## Documentation Structure

**Quick Start:**
- [README.md](README.md) - Project overview and quick start guide
- [docs/deployment-guide.md](docs/deployment-guide.md) - Step-by-step deployment instructions
- [docs/project-container-guide.md](docs/project-container-guide.md) - Guide for creating and managing project containers

**For System Administrators:**
- [docs/project-overview.md](docs/project-overview.md) - Complete project summary and capabilities
- [docs/deployment-guide.md](docs/deployment-guide.md) - From-scratch and incremental deployment scenarios
- [docs/production-port-forwarding.md](docs/production-port-forwarding.md) - Setting up port forwarding for production
- [docs/troubleshooting-guide.md](docs/troubleshooting-guide.md) - Common issues and debugging
- [docs/unprivileged-ports-setup.md](docs/unprivileged-ports-setup.md) - Setting up unprivileged ports

**For Developers:**
- [docs/project-container-guide.md](docs/project-container-guide.md) - User guide for project creation
- [docs/project-container-architecture.md](docs/project-container-architecture.md) - Technical implementation details
- [docs/how-it-works.md](docs/how-it-works.md) - Technical architecture explanation
- [docs/podman-integration.md](docs/podman-integration.md) - Podman setup and configuration
- [docs/git-workflow.md](docs/git-workflow.md) - Git workflow for the project

**For DevOps Engineers:**
- [docs/script-api-reference.md](docs/script-api-reference.md) - Automation script documentation
- [docs/deployment-guide.md](docs/deployment-guide.md) - From-scratch and incremental deployment scenarios
- [docs/podman-integration.md](docs/podman-integration.md) - Podman setup and configuration
- [docs/production-port-forwarding.md](docs/production-port-forwarding.md) - Setting up port forwarding for production

**Technical Specifications:**
- [specs/SPECS.md](specs/SPECS.md) - Complete technical specifications overview
- [specs/nginx-proxy-spec.md](specs/nginx-proxy-spec.md) - Central proxy specification
- [specs/project-container-spec.md](specs/project-container-spec.md) - Project container specification
- [specs/architecture-spec.md](specs/architecture-spec.md) - Network architecture specification
- [specs/script-spec.md](specs/script-spec.md) - Automation script specification
- [specs/environment-spec.md](specs/environment-spec.md) - Environment management specification
- [specs/podman-specs.md](specs/podman-specs.md) - Podman integration specification
- [specs/testing-spec.md](specs/testing-spec.md) - Testing framework specification
- [specs/cloudflare-spec.md](specs/cloudflare-spec.md) - Cloudflare integration specification

## Key Technical Features

**Zero-Downtime Incremental Deployment:**
- Add new projects to running ecosystem without disrupting existing services
- Incremental deployment preserves existing project configurations
- Self-healing proxy creation and recovery from failure states
- Comprehensive health verification and integration testing

**Self-Healing Infrastructure:**
- Automatic proxy detection (running/stopped/missing)
- Self-healing proxy creation from scratch
- Network orchestration and SSL certificate management
- Automatic recovery from failure states

**Multi-Environment Support:**
- Development environment with local DNS and self-signed certificates
- Production environment with Cloudflare integration
- Environment-specific configurations
- Seamless switching between environments

**Internal Container Networking:**
- Container name-based communication without exposed ports
- No port conflicts between projects
- Enhanced security through port isolation
- Simplified container management
- Container name-based DNS resolution

**Podman Integration:**
- Rootless container operation without root privileges
- Container networking with reliable communication
- Docker compatibility layer for seamless transition
- Network connectivity testing

## Performance & Security Requirements

**Performance:**
- Support for 20+ concurrent projects
- 1000+ requests/second throughput
- <2ms SSL certificate negotiation
- <2 minute deployment time per project

**Security:**
- Modern SSL/TLS configuration
- Comprehensive security headers
- Rate limiting and DDoS protection
- Bad bot blocking
- Network isolation between projects
- No exposed ports for project containers
