# Microservices Nginx Architecture

This project implements a microservices architecture for Nginx, where each project runs in its own isolated container, orchestrated through a central Nginx proxy.

## Directory Structure

```
project-root/
├── proxy/                              # Nginx proxy (shared)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   ├── nginx.conf                      # Main proxy config
│   └── conf.d/
│       ├── ssl-settings.conf
│       ├── security-headers.conf
│       ├── cloudflare.conf
│       └── domains/                    # Domain-specific routing
│           ├── example.com.conf
│           └── another-domain.com.conf
├── projects/
│   └── {project-name}/
│       ├── docker-compose.yml          # Project-specific compose
│       ├── Dockerfile                  # Custom nginx image
│       ├── nginx.conf                  # Project nginx config
│       ├── conf.d/                     # Additional configurations
│       │   ├── security.conf
│       │   └── compression.conf
│       ├── html/                       # Frontend files
│       │   └── index.html
│       └── cloudflare/                 # Terraform (PRO only)
│           ├── main.tf
│           ├── variables.tf
│           ├── outputs.tf
│           └── terraform.tfvars.example
├── conf/                               # Template configurations
│   ├── nginx-proxy-template.conf
│   ├── nginx-server-template.conf
│   ├── domain-template.conf
│   ├── security-headers.conf
│   └── ssl-settings.conf
└── scripts/                            # Automation scripts
    ├── proxy-manage.sh
    └── domain-manage.sh
```

## Development Environment

This project uses Nix for development environment management. To set up the development environment:

1. Install Nix if you don't have it already:
   ```bash
   curl -L https://nixos.org/nix/install | sh
   ```

2. Enable flakes (if not already enabled):
   ```bash
   mkdir -p ~/.config/nix
   echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
   ```

3. Enter the development environment:
   ```bash
   nix develop --extra-experimental-features nix-command
   ```

## Infrastructure Setup

The infrastructure consists of a central Nginx proxy container that routes traffic to individual project containers. Each project container runs its own isolated Nginx server.

### Proxy Container

The proxy container is responsible for:
- Routing traffic to appropriate project containers
- SSL/TLS termination
- Security headers and policies
- Rate limiting and DDoS protection

To manage the proxy container:

```bash
# Start the proxy container
./scripts/proxy-manage.sh start

# Stop the proxy container
./scripts/proxy-manage.sh stop

# Restart the proxy container
./scripts/proxy-manage.sh restart

# Show the status of the proxy container
./scripts/proxy-manage.sh status

# Reload the Nginx configuration
./scripts/proxy-manage.sh reload

# Show the logs of the proxy container
./scripts/proxy-manage.sh logs
```

### Domain Management

To manage domain configurations in the proxy:

```bash
# Add a new domain configuration
./scripts/domain-manage.sh add -d example.com -p my-project

# Remove a domain configuration
./scripts/domain-manage.sh remove -d example.com

# List all domain configurations
./scripts/domain-manage.sh list
```

## Testing

The project includes several test scripts to validate the infrastructure:

```bash
# Validate directory structure
./tests/validate-structure.sh

# Validate template syntax
./tests/validate-templates.sh

# Validate development environment
./tests/validate-environment.sh
```

## License

This project is licensed under the MIT License - see the LICENSE file for details. 