# Project Container User Guide

## Overview

This guide provides comprehensive documentation for working with project containers in the Microservices Nginx Architecture. Project containers are isolated environments that host individual websites or applications, managed through a set of automation scripts.

## Getting Started

### Prerequisites

Before working with project containers, ensure you have:

1. A properly configured Nix development environment
2. Docker or Podman installed
3. Access to the project repository

### Quick Start

To create a new project container:

```bash
# Enter Nix environment
nix develop

# Create a new project
./scripts/create-project-modular.sh --name my-project --domain my-project.com --port 8080
```

## Project Container Architecture

Each project container consists of:

1. **Nginx Configuration**: Custom settings for the specific project
2. **Docker Setup**: Container definition and networking
3. **Static Content**: Website files and assets
4. **Health Checks**: Monitoring endpoints

## Creating a New Project

### Basic Usage

```bash
./scripts/create-project-modular.sh --name PROJECT_NAME --domain DOMAIN_NAME --port PORT
```

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `--name`, `-n` | Project name (alphanumeric with hyphens) | `--name my-project` |
| `--domain`, `-d` | Domain name for the project | `--domain example.com` |
| `--port`, `-p` | Internal container port | `--port 8080` |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `--frontend`, `-f` | Path to static files | `./projects/{project_name}/html` | `--frontend /path/to/files` |
| `--cert`, `-c` | SSL certificate path | `/etc/ssl/certs/cert.pem` | `--cert /path/to/cert.pem` |
| `--key`, `-k` | SSL private key path | `/etc/ssl/certs/private/cert-key.pem` | `--key /path/to/key.pem` |
| `--env`, `-e` | Environment (DEV or PRO) | `DEV` | `--env PRO` |

### Examples

```bash
# Create a basic development project
./scripts/create-project-modular.sh --name blog --domain blog.example.com --port 8080

# Create a production project with custom frontend
./scripts/create-project-modular.sh --name shop --domain shop.example.com --port 8081 --env PRO --frontend /path/to/shop/dist
```

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

## Project Structure

After creation, your project will have the following structure:

```
projects/
└── {project-name}/
    ├── docker-compose.yml          # Container configuration
    ├── docker-compose.override.yml # Development overrides (DEV only)
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

### Docker Configuration

The `docker-compose.yml` file defines:

- Container settings
- Volume mounts
- Network configuration
- Environment variables

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

Project containers are designed to work with the central Nginx proxy:

1. Projects register their domains with the proxy
2. The proxy routes traffic to the appropriate project container
3. SSL termination happens at the proxy level

For more details on proxy integration, see the Nginx Proxy documentation. 