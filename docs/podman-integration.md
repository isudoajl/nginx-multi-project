# Podman Integration for Nginx Multi-Project

This document describes the podman integration for the Nginx Multi-Project architecture.

## Overview

The project uses podman as a container engine for running nginx proxy and project containers. The podman integration is implemented in the Nix development environment and provides:

1. Rootless podman operation
2. Container networking with proper DNS resolution
3. Volume mounting for configuration and certificates
4. Automatic network creation and container connectivity
5. Docker compatibility layer

## Key Components

### Nix Development Environment

The Nix development environment is configured in `flake.nix` and provides:

- Podman and its dependencies (conmon, runc, slirp4netns)
- Custom scripts for podman setup and management
- Automatic setup of rootless podman capabilities
- Docker compatibility layer for tools that expect docker

### Podman Scripts

Several scripts have been created to manage podman:

1. `scripts/setup-podman.sh`: Sets up podman for rootless operation
2. `scripts/cleanup-podman.sh`: Cleans up podman resources (containers, images, networks)
3. `scripts/test-podman-network.sh`: Tests podman network connectivity
4. `scripts/update-proxy-container.sh`: Updates the proxy container with proper configuration

### Project Creation and Deployment

The project creation and deployment process is handled by `scripts/create-project-modular.sh`, which:

1. Creates project structure
2. Generates nginx configuration
3. Sets up SSL certificates
4. Creates and starts containers
5. Configures networking
6. Updates proxy configuration

## Usage

### Setting Up the Environment

To set up the environment, run:

```bash
nix --extra-experimental-features "nix-command flakes" develop
```

This will:
- Enter the Nix development environment
- Set up podman for rootless operation
- Create the nginx-proxy network if it doesn't exist

### Creating a New Project

To create a new project, run:

```bash
./scripts/create-project-modular.sh --name <project-name> --domain <domain-name> --port <port> --env <DEV|PRO>
```

Example:
```bash
./scripts/create-project-modular.sh --name mapa-kms --domain mapakms.com --port 8090 --env PRO
```

### Testing Podman Networking

To test podman networking, run:

```bash
./scripts/test-podman-network.sh
```

### Cleaning Up Podman Resources

To clean up podman resources, run:

```bash
./scripts/cleanup-podman.sh
```

## Technical Details

### Rootless Podman

The implementation uses rootless podman, which:
- Runs containers as a non-root user
- Sets required capabilities for user namespace mapping
- Creates appropriate configuration files in `~/.config/containers/`

### Container Networking

Container networking is implemented using:
- A shared `nginx-proxy-network` for communication between containers
- IP address-based proxy_pass directives to avoid DNS resolution issues
- Network connectivity verification before updating proxy configuration

### Volume Mounting

Configuration files and certificates are mounted into containers using:
- Read-only mounts for configuration files and certificates
- Read-write mounts for logs

## Troubleshooting

### Common Issues

1. **Container connectivity issues**: Use `./scripts/test-podman-network.sh` to verify network connectivity.
2. **Certificate errors**: Ensure certificates exist in the correct location and are properly mounted.
3. **Proxy configuration errors**: Check nginx configuration with `podman exec nginx-proxy nginx -t`.
4. **Permission issues**: Ensure rootless podman is properly set up with `./scripts/setup-podman.sh`.

### Logs

To check container logs:

```bash
podman logs nginx-proxy
podman logs <project-name>
```

## References

- [Podman Documentation](https://docs.podman.io/)
- [Nginx Documentation](https://nginx.org/en/docs/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes) 