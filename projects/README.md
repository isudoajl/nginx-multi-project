# Projects Directory

This directory contains **runtime project deployments** that are created dynamically by the deployment scripts.

## 🚨 Important Security Notice

**This directory is ignored by git** and should **NEVER** contain committed files. All contents are generated during deployment and contain:

- SSL certificates and private keys
- Runtime configurations
- Log files
- Container-specific data

## How Projects Are Created

Projects are deployed using:
```bash
./scripts/create-project-modular.sh --name PROJECT_NAME --domain DOMAIN --port PORT --env ENV
```

Each deployment creates a complete project structure with:
- Custom nginx configuration
- SSL certificates (domain-specific)
- Docker Compose configuration
- Static HTML files
- Log directories
- Health check endpoints

## Project Structure (Runtime)

When deployed, each project creates:
```
projects/{project-name}/
├── docker-compose.yml          # Container orchestration
├── Dockerfile                  # Custom nginx image
├── nginx.conf                  # Project-specific nginx config
├── conf.d/                     # Additional configurations
│   ├── security.conf          # Security headers
│   ├── compression.conf       # Compression settings
│   └── dev/                   # Development configs (DEV env only)
├── html/                       # Static files
│   ├── index.html
│   ├── 404.html
│   ├── 50x.html
│   └── health/index.html      # Health check endpoint
├── certs/                      # SSL certificates (NEVER COMMITTED)
├── logs/                       # Runtime logs (NEVER COMMITTED)
```

## Environment Isolation

- **Development (DEV)**: Self-signed certificates, local DNS
- **Production (PRO)**: Production certificates, Cloudflare integration

All deployments are managed by the main deployment script and integrate seamlessly with the central nginx proxy.

## Security

⚠️ **CRITICAL**: This directory contains sensitive SSL certificates and should never be committed to version control. The .gitignore ensures all project contents are excluded from git tracking. 