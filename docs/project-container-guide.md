# Project Container User Guide

## Overview

This guide provides comprehensive documentation for working with project containers in the Microservices Nginx Architecture. Project containers are isolated environments that host individual websites or applications, managed through a set of automation scripts.

## Getting Started

### Prerequisites

Before working with project containers, ensure you have:

1. A properly configured Nix development environment
2. Podman (automatically provided via Nix)
3. Access to the project repository

### 🔐 SSL Certificate Requirements (CRITICAL)

**Before creating any project, you MUST place SSL certificates in the `certs/` directory:**

```bash
# Required certificate files (names are hardcoded):
certs/cert.pem        # SSL certificate
certs/cert-key.pem    # SSL private key

# These certificates will be used for ALL projects
# Make sure they are valid for your domains
```

### Quick Start

To create a new project container:

```bash
# Enter Nix environment
nix --extra-experimental-features "nix-command flakes" develop

# Create a new project
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh --name my-project --domain my-project.com --env PRO
```

## Project Container Architecture

Each project container supports both frontend-only and full-stack architectures:

### Frontend-Only Containers
1. **Nginx Configuration**: Custom settings for the specific project
2. **Container Setup**: Container definition and networking
3. **Static Content**: Website files and assets
4. **Health Checks**: Monitoring endpoints

### Full-Stack Containers
1. **Multi-Service Architecture**: nginx + backend application server
2. **API Routing**: nginx proxy configuration for backend services
3. **Framework Support**: Rust, Node.js, Go, Python backend services
4. **Process Management**: Coordinated startup and health monitoring
5. **Internal Networking**: Container-internal communication between services

## Creating a New Project

### Basic Usage

```bash
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh --name PROJECT_NAME --domain DOMAIN_NAME --env PRO
```

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--name`, `-n` | Project name (alphanumeric with hyphens) | `--name my-project` |
| `--domain`, `-d` | Domain name for the project | `--domain example.com` |
| `--env`, `-e` | Environment (PRO only) | `--env PRO` |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--frontend`, `-f` | Path to static files | `./projects/{project_name}/html` | `--frontend /path/to/files` |
| `--frontend-mount`, `-m` | Path to mount as frontend in container | `./html` | `--frontend-mount /path/to/frontend` |
| `--cert`, `-c` | SSL certificate path | `/etc/ssl/certs/cert.pem` | `--cert /path/to/cert.pem` |
| `--key`, `-k` | SSL private key path | `/etc/ssl/certs/private/cert-key.pem` | `--key /path/to/key.pem` |

### Full-Stack Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--monorepo` | Path to monorepo root (enables full-stack) | N/A | `--monorepo /opt/my-app` |
| `--frontend-dir` | Frontend subdirectory in monorepo | `frontend` | `--frontend-dir client` |
| `--backend-dir` | Backend subdirectory in monorepo | N/A | `--backend-dir server` |
| `--backend-port` | Backend service port | `3000` | `--backend-port 8080` |
| `--backend-build` | Custom backend build command | Auto-detected | `--backend-build "cargo build --release"` |

### Examples

#### Frontend-Only Projects

```bash
# Create a basic production project
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh --name blog --domain blog.example.com --env PRO

# Create a production project with custom frontend
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh --name shop --domain shop.example.com --env PRO --frontend /path/to/shop/dist
```

#### Full-Stack Projects

```bash
# Rust + React full-stack deployment
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name my-rust-app \
  --domain my-rust-app.com \
  --monorepo /opt/my-rust-app \
  --frontend-dir frontend \
  --backend-dir backend \
  --backend-port 3000 \
  --env PRO

# Node.js + Vue full-stack deployment
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name my-node-app \
  --domain my-node-app.com \
  --monorepo /home/user/my-node-app \
  --frontend-dir client \
  --backend-dir server \
  --backend-port 8080 \
  --backend-build "npm run build:server" \
  --env PRO

# Go + React with custom build
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name my-go-app \
  --domain my-go-app.com \
  --monorepo /opt/go-project \
  --frontend-dir web \
  --backend-dir api \
  --backend-build "go build -o ./bin/server ./cmd/server" \
  --env PRO
```

## 🧹 Fresh Environment Reset

For testing purposes or when you need a completely clean environment:

```bash
# Clean all containers, networks, and configurations
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/fresh-restart.sh

# This script will:
# • Stop and remove ALL podman containers
# • Remove ALL custom images (keeps base nginx:alpine)
# • Prune ALL networks
# • Delete ALL project directories
# • Clean ALL configuration files
# • Preserve master SSL certificates in certs/
```

This allows you to test fresh deployments without deleting the repository! 🎯

## Project Structure

After creation, your project will have the following structure:

```
projects/
└── {project-name}/
    ├── docker-compose.yml          # Container configuration
    ├── Dockerfile                  # Custom nginx image
    ├── nginx.conf                  # Project nginx config
    ├── conf.d/                     # Additional configurations
    │   ├── security.conf
    │   └── compression.conf
    ├── html/                       # Frontend files
    │   └── index.html
    └── certs/                      # SSL certificates
        ├── cert.pem
        └── cert-key.pem
```

## Configuration Options

### Nginx Configuration

The project's `nginx.conf` can be customized for specific needs:

- **Security Settings**: Located in `conf.d/security.conf`
- **Compression Settings**: Located in `conf.d/compression.conf`
- **Static File Handling**: Configured in the main `nginx.conf`

### Container Configuration

The `docker-compose.yml` file defines:

- Container settings
- Volume mounts
- Network configuration
- Environment variables

## Development Environment

### Setting Up Development Environment

```bash
./scripts/dev-environment.sh --project PROJECT_NAME --action setup --port DEV_PORT
```

This command:
1. Creates development-specific configuration
2. Sets up a health check endpoint
3. Configures Docker Compose override for development

### Starting Development Environment

```bash
./scripts/dev-environment.sh --project PROJECT_NAME --action start
```

### Stopping Development Environment

```bash
./scripts/dev-environment.sh --project PROJECT_NAME --action stop
```

### Reloading Configuration

```bash
./scripts/dev-environment.sh --project PROJECT_NAME --action reload
```

## Local Host Configuration

To configure your local hosts file for development:

```bash
sudo ./scripts/update-hosts.sh --domain PROJECT_DOMAIN --action add
```

To remove a domain from your hosts file:

```bash
sudo ./scripts/update-hosts.sh --domain PROJECT_DOMAIN --action remove
```

## Certificate Generation

### Development Certificates

```bash
./scripts/generate-certs.sh --domain PROJECT_DOMAIN --output ./projects/PROJECT_NAME/certs
```

### Production Certificates

```bash
./scripts/generate-certs.sh --domain PROJECT_DOMAIN --output ./projects/PROJECT_NAME/certs --env PRO
```

## Troubleshooting

### Common Issues

1. **Certificate Problems**
   - Ensure certificates are properly generated
   - Check file permissions

2. **Network Issues**
   - Verify Docker networks are correctly configured
   - Check local hosts file configuration

3. **Permission Errors**
   - Run scripts with appropriate permissions
   - Ensure Nix environment is active

### Logs

Access logs for troubleshooting:

```bash
# View project logs
docker logs {project-name}

# View script logs
cat ./scripts/logs/{script-name}.log
```

## Advanced Usage

### Custom Nginx Configuration

To add custom Nginx directives:

1. Create a new configuration file in `projects/{project-name}/conf.d/`
2. Include the file in `nginx.conf`

### Health Check Customization

The default health check endpoint can be customized by editing:
`projects/{project-name}/html/health/index.html`

## Integration with Proxy

Project containers integrate with the central nginx proxy through:

1. **Container Name Resolution**: Uses container names for DNS resolution
2. **Internal Networking**: No exposed ports required
3. **Domain Routing**: Proxy routes requests based on domain names
4. **SSL Termination**: Handled at the proxy level

## Security Features

### Network Isolation

- Project containers are isolated from each other
- No direct external access to project containers
- All traffic routed through the central proxy

### Internal Communication

- Container-to-container communication via internal networks
- No port conflicts between projects
- Enhanced security through port isolation 