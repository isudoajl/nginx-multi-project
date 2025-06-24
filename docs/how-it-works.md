# Nginx Multi-Project: How It Works

## Architecture Overview

The Nginx Multi-Project system is a container-based architecture designed to host multiple web applications with isolated environments while providing centralized SSL termination and routing. The system consists of two main components:

1. **Central Nginx Proxy Container**: Handles SSL termination, routing, and security
2. **Project Containers**: Individual isolated nginx containers for each project/website

## Network Topology

```
┌───────────────┐     ┌────────────────┐
│ External User │────▶│ Ports 80/443   │
└───────────────┘     │ (forwarded to  │
                      │ 8080/8443)     │
                      └────────┬───────┘
                               │
                               ▼
┌──────────────────────────────────────────────┐
│ nginx-proxy Container                        │
│ - SSL termination                            │
│ - Domain-based routing                       │
│ - Security headers                           │
│ - Rate limiting                              │
└─────────────────┬────────────────────────────┘
                  │
                  │ nginx-proxy-network (shared)
     ┌────────────┼────────────────┬────────────┐
     │            │                │            │
     ▼            ▼                ▼            ▼
┌──────────┐ ┌──────────┐    ┌──────────┐ ┌──────────┐
│ Project1 │ │ Project2 │... │ Project3 │ │ Project4 │
└────┬─────┘ └────┬─────┘    └────┬─────┘ └────┬─────┘
     │            │                │            │
     ▼            ▼                ▼            ▼
┌──────────┐ ┌──────────┐    ┌──────────┐ ┌──────────┐
│Project1- │ │Project2- │    │Project3- │ │Project4- │
│network   │ │network   │    │network   │ │network   │
│(isolated)│ │(isolated)│    │(isolated)│ │(isolated)│
└──────────┘ └──────────┘    └──────────┘ └──────────┘
```

## Key Components

### 1. Proxy Container

- **Container Name**: `nginx-proxy`
- **Ports**: 8080 (HTTP) and 8443 (HTTPS)
- **Networks**: Connected to `nginx-proxy-network` (shared with all projects)
- **Configuration**: 
  - `/proxy/nginx.conf`: Main configuration
  - `/proxy/conf.d/domains/*.conf`: Domain-specific routing
  - `/proxy/conf.d/security-headers.conf`: Security settings
  - `/proxy/conf.d/ssl-settings.conf`: SSL/TLS configuration

### 2. Project Containers

- **Container Name**: Project name (e.g., `mapa-kms`)
- **Ports**: Internal port 80 (exposed as configured port)
- **Networks**: Connected to both:
  - `nginx-proxy-network` (shared with proxy)
  - Project-specific network (isolated)
- **Configuration**:
  - Custom nginx configuration
  - Project-specific security settings
  - Health check endpoint at `/health`

### 3. Certificate Management

- **Certificates**: Generic certificates in `/certs/`, domain-specific copies in `/certs/{domain}/`
- **Integration**: Certificate workflow:
  1. Generic certificates stored in `/opt/nginx-multi-project/certs/`
  2. Script creates domain-specific directory `/opt/nginx-multi-project/certs/{domain}/`
  3. Copies generic certificates to domain-specific directory for new projects
  4. Both project containers and proxy use domain-specific certificates

## Deployment Process

### 1. Pre-deployment Cleanup

```bash
# Clean stale domain configs
rm -f proxy/conf.d/domains/*.conf

# Stop and remove any crashed proxy containers
podman stop nginx-proxy && podman rm nginx-proxy
```

### 2. Project Creation

The `create-project-modular.sh` script orchestrates the entire process:

1. **Parse Arguments**: Process command-line parameters
2. **Validate Environment**: Ensure Nix environment and container engine
3. **Check Proxy**: Detect existing proxy or create new one
4. **Setup Project Structure**: Create directories and copy certificates
5. **Generate Project Files**: Create Dockerfile, docker-compose.yml, nginx.conf
6. **Configure Environment**: Apply environment-specific settings
7. **Deploy Project**: Build container and connect to networks
8. **Verify Deployment**: Perform health checks

### 3. Proxy Integration

The key to the system's reliability is the proxy integration process:

1. **Container IP Resolution**: The script obtains the project container's IP address
2. **Domain Configuration**: Creates a domain-specific config file using the IP address (not hostname)
3. **Certificate Copying**: Copies certificates to the proxy's certificate directory
4. **Proxy Reload**: Performs a graceful reload of the proxy configuration

### 4. DNS Resolution Fix

A critical improvement in the system is using container IP addresses instead of hostnames in proxy_pass directives:

```nginx
# Using container IP (reliable)
proxy_pass http://10.89.1.2:80;

# Instead of container hostname (potential DNS issues)
proxy_pass http://container-name:80;
```

This prevents the "host not found in upstream" errors that would otherwise cause nginx to fail to start.

## Environment Types

### Development Environment (DEV)

- Self-signed certificates
- Local hosts file updates
- Development-optimized settings
- Hot reload capability

### Production Environment (PRO)

- Production-grade certificates
- Enhanced security settings
- Performance optimizations

## Security Features

- **SSL/TLS**: Modern protocols and ciphers
- **Security Headers**: CSP, X-Frame-Options, etc.
- **Rate Limiting**: Protection against abuse
- **Bad Bot Blocking**: Filter malicious traffic
- **Network Isolation**: Projects cannot communicate directly

## Incremental Deployment

The system supports adding new projects without disrupting existing ones:

1. **Proxy Detection**: Identifies existing proxy infrastructure
2. **Ecosystem Preservation**: Maintains running services
3. **Seamless Integration**: Adds new project without downtime
4. **Health Verification**: Validates new and existing projects

## Troubleshooting

Common issues and their solutions:

1. **Proxy Crash Loop**: Usually caused by stale domain configurations referencing non-existent containers
2. **Container Networking**: Ensure both proxy and project containers are on the shared network
3. **Certificate Issues**: Verify paths and permissions
4. **Port Conflicts**: Check for services using the same ports
5. **DNS Resolution**: Use container IPs instead of hostnames in proxy_pass directives

## Port Forwarding in Production

In production, the proxy runs on unprivileged ports (8080/8443) and requires port forwarding:

```bash
# Forward privileged ports to container ports
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
```

## Verification Commands

```bash
# Check containers
podman ps | grep -E "(nginx-proxy|project-name)"

# Check proxy logs
podman logs nginx-proxy --tail 20

# Test proxy configuration
podman exec nginx-proxy nginx -t

# Test connectivity
podman exec nginx-proxy curl -I http://project-name:80

# External test
curl -I -H "Host: domain.name" http://localhost:8080
curl -I -k -H "Host: domain.name" https://localhost:8443
``` 