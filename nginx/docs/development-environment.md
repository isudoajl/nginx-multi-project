# Development Environment Setup Guide

This guide provides instructions for setting up and using the development environment for the Nginx multi-project architecture.

## Prerequisites

- Nix development environment
- Nginx
- OpenSSL (for certificate generation)
- dnsmasq (for local DNS resolution)
- inotify-tools (for hot reload functionality)

## Quick Start

1. Enter the Nix development environment:
   ```bash
   nix develop
   ```

2. Set up the development environment:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --setup-dns
   ./nginx/scripts/dev/dev-workflow.sh --setup-certs
   ```

3. Start the development server:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --start
   ```

4. Enable hot reload:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --watch
   ```

## Development Workflow

### Starting the Development Environment

```bash
./nginx/scripts/dev/dev-workflow.sh --start
```

This command will:
- Validate the Nginx configuration
- Start Nginx with the development configuration

### Stopping the Development Environment

```bash
./nginx/scripts/dev/dev-workflow.sh --stop
```

### Reloading Configuration

```bash
./nginx/scripts/dev/dev-workflow.sh --reload
```

### Hot Reload

The hot reload feature automatically detects changes to configuration files and reloads Nginx:

```bash
./nginx/scripts/dev/dev-workflow.sh --watch
```

## Local DNS Resolution

The development environment includes local DNS resolution for `.local.dev` domains:

1. Set up local DNS:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --setup-dns
   ```

2. Start the dnsmasq service:
   ```bash
   sudo dnsmasq -C ./nginx/scripts/dev/dnsmasq.conf --no-daemon
   ```

3. Available domains:
   - `local.dev` - Main development domain
   - `api.local.dev` - API development domain
   - `admin.local.dev` - Admin development domain

## Local Certificates

For HTTPS development, the environment includes a local certificate authority:

1. Set up certificates:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --setup-certs
   ```

2. Trust the root CA in your browser:
   - Import `./nginx/certs/rootCA.pem` into your browser's certificate store

## Directory Structure

- `nginx/config/environments/development/` - Development environment configuration
- `nginx/scripts/dev/` - Development workflow scripts
- `nginx/certs/` - Local certificates and CA
- `nginx/tests/` - Test scripts

## Troubleshooting

### Nginx Configuration Errors

If you encounter Nginx configuration errors, run:

```bash
nginx -t -c ./nginx/config/environments/development/nginx.conf
```

### DNS Resolution Issues

If local domains are not resolving:

1. Check if dnsmasq is running:
   ```bash
   ps aux | grep dnsmasq
   ```

2. Verify the configuration:
   ```bash
   cat ./nginx/scripts/dev/dnsmasq.conf
   ```

3. Test resolution:
   ```bash
   dig @127.0.0.1 local.dev
   ```

### Certificate Issues

If you encounter certificate errors:

1. Verify the certificates exist:
   ```bash
   ls -la ./nginx/certs/
   ```

2. Regenerate certificates:
   ```bash
   ./nginx/scripts/dev/dev-workflow.sh --setup-certs
   ```

3. Make sure you've imported the root CA into your browser 