# AGENT.md - Nginx Multi-Project Architecture

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
