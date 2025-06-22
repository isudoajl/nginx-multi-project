# Script API Reference

This document provides detailed API documentation for all automation scripts in the Microservices Nginx Architecture. It covers all available parameters, return values, and usage examples.

## Table of Contents

1. [create-project.sh](#create-projectsh)
2. [update-hosts.sh](#update-hostssh)
3. [dev-environment.sh](#dev-environmentsh)
4. [generate-certs.sh](#generate-certssh)
5. [update-proxy.sh](#update-proxysh)

---

## create-project.sh

Creates a new project container with all necessary configuration files.

### Synopsis

```bash
./scripts/create-project.sh [OPTIONS]
```

### Options

| Parameter | Short | Type | Required | Default | Description |
|----------|-------|------|----------|---------|-------------|
| `--name` | `-n` | string | Yes | - | Project name (alphanumeric with hyphens) |
| `--port` | `-p` | integer | Yes | - | Internal container port (1024-65535) |
| `--domain` | `-d` | string | Yes | - | Domain name (valid FQDN format) |
| `--frontend` | `-f` | string | No | `./projects/{project_name}/html` | Path to static files |
| `--cert` | `-c` | string | No | `/etc/ssl/certs/cert.pem` | SSL certificate path |
| `--key` | `-k` | string | No | `/etc/ssl/certs/private/cert-key.pem` | SSL private key path |
| `--env` | `-e` | string | No | `DEV` | Environment type (`DEV` or `PRO`) |
| `--cf-token` | - | string | No* | - | Cloudflare API token (required for PRO environment) |
| `--cf-account` | - | string | No* | - | Cloudflare account ID (required for PRO environment) |
| `--cf-zone` | - | string | No* | - | Cloudflare zone ID (required for PRO environment) |
| `--help` | `-h` | - | No | - | Display help message |

\* Required only for PRO environment with Cloudflare integration

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Environment error |
| 4 | Project creation error |
| 5 | Deployment error |

### Examples

```bash
# Create a basic development project
./scripts/create-project.sh --name blog --domain blog.example.com --port 8080

# Create a production project with custom frontend
./scripts/create-project.sh --name shop --domain shop.example.com --port 8081 --env PRO --frontend /path/to/shop/dist

# Create a production project with Cloudflare integration
./scripts/create-project.sh --name api --domain api.example.com --port 8082 --env PRO --cf-token YOUR_CF_TOKEN --cf-account YOUR_CF_ACCOUNT --cf-zone YOUR_CF_ZONE
```

---

## update-hosts.sh

Updates the local hosts file with project domain entries.

### Synopsis

```bash
sudo ./scripts/update-hosts.sh [OPTIONS]
```

### Options

| Parameter | Short | Type | Required | Default | Description |
|----------|-------|------|----------|---------|-------------|
| `--domain` | `-d` | string | Yes | - | Domain name to add/remove |
| `--action` | `-a` | string | Yes | - | Action to perform (`add` or `remove`) |
| `--ip` | `-i` | string | No | `127.0.0.1` | IP address to use |
| `--help` | `-h` | - | No | - | Display help message |

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Permission error (not run as root) |
| 3 | Invalid arguments |
| 4 | Hosts file error |

### Examples

```bash
# Add a domain to hosts file
sudo ./scripts/update-hosts.sh --domain example.com --action add

# Add a domain with custom IP
sudo ./scripts/update-hosts.sh --domain example.com --action add --ip 192.168.1.100

# Remove a domain from hosts file
sudo ./scripts/update-hosts.sh --domain example.com --action remove
```

---

## dev-environment.sh

Manages development environment for projects.

### Synopsis

```bash
./scripts/dev-environment.sh [OPTIONS]
```

### Options

| Parameter | Short | Type | Required | Default | Description |
|----------|-------|------|----------|---------|-------------|
| `--project` | `-p` | string | Yes | - | Project name to manage |
| `--action` | `-a` | string | Yes | - | Action to perform (`setup`, `start`, `stop`, or `reload`) |
| `--port` | `-port` | integer | No | `8080` | Development port to use |
| `--subnet` | `-s` | integer | No | Random (1-254) | Subnet ID for development network |
| `--help` | `-h` | - | No | - | Display help message |

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Environment error |
| 4 | Project not found |
| 5 | Action execution error |

### Examples

```bash
# Setup development environment
./scripts/dev-environment.sh --project my-project --action setup --port 9000

# Start development environment
./scripts/dev-environment.sh --project my-project --action start

# Reload development environment
./scripts/dev-environment.sh --project my-project --action reload

# Stop development environment
./scripts/dev-environment.sh --project my-project --action stop
```

---

## generate-certs.sh

Generates SSL certificates for development or production environments.

### Synopsis

```bash
./scripts/generate-certs.sh [OPTIONS]
```

### Options

| Parameter | Short | Type | Required | Default | Description |
|----------|-------|------|----------|---------|-------------|
| `--domain` | `-d` | string | Yes | - | Domain name for the certificate |
| `--output` | `-o` | string | Yes | - | Output directory for certificates |
| `--env` | `-e` | string | No | `DEV` | Environment type (`DEV` or `PRO`) |
| `--days` | - | integer | No | `365` | Validity period in days (DEV only) |
| `--country` | `-c` | string | No | `US` | Country code for certificate |
| `--state` | `-s` | string | No | `State` | State/Province for certificate |
| `--locality` | `-l` | string | No | `City` | City/Locality for certificate |
| `--org` | - | string | No | `Organization` | Organization name for certificate |
| `--help` | `-h` | - | No | - | Display help message |

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | OpenSSL error |
| 4 | Output directory error |

### Examples

```bash
# Generate development certificate
./scripts/generate-certs.sh --domain example.com --output ./projects/my-project/certs

# Generate development certificate with custom validity
./scripts/generate-certs.sh --domain example.com --output ./projects/my-project/certs --days 730

# Generate production certificate request
./scripts/generate-certs.sh --domain example.com --output ./projects/my-project/certs --env PRO --org "My Company"
```

---

## update-proxy.sh

Updates the central proxy configuration when a project is added, removed, or modified.

### Synopsis

```bash
./scripts/update-proxy.sh [OPTIONS]
```

### Options

| Parameter | Short | Type | Required | Default | Description |
|----------|-------|------|----------|---------|-------------|
| `--action` | `-a` | string | Yes | - | Action to perform (`add`, `remove`, or `update`) |
| `--name` | `-n` | string | Yes | - | Project name |
| `--domain` | `-d` | string | No* | - | Domain name (required for `add` and `update`) |
| `--port` | `-p` | integer | No* | - | Container port (required for `add`) |
| `--ssl` | `-s` | boolean | No | `false` | Enable SSL for the domain |
| `--help` | `-h` | - | No | - | Display help message |

\* Required depending on the action

### Exit Codes

| Code | Description |
|------|-------------|
| 0 | Success |
| 1 | General error |
| 2 | Invalid arguments |
| 3 | Proxy configuration error |
| 4 | Reload error |

### Examples

```bash
# Add project to proxy
./scripts/update-proxy.sh --action add --name my-project --domain example.com --port 8080

# Add project with SSL
./scripts/update-proxy.sh --action add --name my-project --domain example.com --port 8080 --ssl

# Update project in proxy
./scripts/update-proxy.sh --action update --name my-project --domain new-domain.com

# Remove project from proxy
./scripts/update-proxy.sh --action remove --name my-project
``` 