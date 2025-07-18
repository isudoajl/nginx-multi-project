# Microservices Nginx Architecture - Deployment Guide

## Overview

This guide covers all deployment scenarios for the Microservices Nginx Architecture, including the revolutionary **Incremental Deployment System** that enables zero-downtime addition of new projects to existing ecosystems.

## 🚀 Deployment Scenarios

### 1. From-Scratch Deployment ✅
Complete infrastructure creation when no proxy exists
- Creates proxy infrastructure from ground up
- Sets up initial networking and security
- Deploys first project with full integration

### 2. Incremental Deployment ✅ **NEW**
Zero-downtime addition to existing ecosystems
- Detects existing proxy infrastructure
- Preserves running services during deployment
- Seamlessly integrates new projects
- Maintains complete network isolation

## Prerequisites

### Environment Setup
```bash
# 1. Enter Nix development environment (REQUIRED)
nix --extra-experimental-features "nix-command flakes" develop

# 2. Verify Nix environment is active
echo $IN_NIX_SHELL  # Should return 1

# 3. Verify container engine availability
podman --version  # or docker --version
```

### 🔐 SSL Certificate Requirements (CRITICAL)

**Before creating any project, you MUST place SSL certificates in the `certs/` directory:**

```bash
# Required certificate files (names are hardcoded):
certs/cert.pem        # SSL certificate
certs/cert-key.pem    # SSL private key

# These certificates will be used for ALL projects
# Make sure they are valid for your domains
```

### System Requirements
- **Container Engine**: Podman
- **Nix Package Manager**: With flakes support
- **Network Ports**: 8080 (HTTP), 8443 (HTTPS), project-specific ports
- **Disk Space**: ~100MB per project
- **Memory**: ~50MB per project container

## From-Scratch Deployment

### Creating Your First Project

> 🌐 **IMPORTANT**: Before deployment, ensure your domain's DNS records (A/CNAME) are pointing to your server.

> 🔥 **CRITICAL FOR PRODUCTION/VPS**: After deployment, you **MUST** set up port forwarding to avoid Cloudflare Error 522:
> ```bash
> # Forward standard ports to container ports (run AFTER deployment)
> sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
> sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
> 
> # Make persistent (Ubuntu/Debian):
> sudo apt install iptables-persistent && sudo netfilter-persistent save
> ```

**Production Environment**
```bash
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name my-first-app \
  --port 8090 \
  --domain my-first-app.com \
  --env PRO
```

### What Happens During From-Scratch Deployment

1. **Proxy Infrastructure Creation**
   - Creates nginx-proxy container with SSL termination
   - Sets up nginx-proxy-network for inter-container communication
   - Configures SSL certificates from `certs/` directory and security headers

2. **Project Container Deployment**
   - Builds custom nginx image with project configuration
   - Creates isolated project network
   - Connects to shared proxy network

3. **Integration & Verification**
   - Updates proxy configuration with new domain routing
   - Performs health checks on all components
   - Validates end-to-end connectivity

### Expected Results
```bash
# Containers after from-scratch deployment
CONTAINER ID  IMAGE                 COMMAND  CREATED  STATUS   PORTS                   NAMES
abc123def456  nginx-proxy:latest    nginx    1m ago   Up       0.0.0.0:8080->80/tcp   nginx-proxy
                                                      0.0.0.0:8443->443/tcp
def456ghi789  my-first-app:latest   nginx    1m ago   Up       8090/tcp               my-first-app

# Networks created
NETWORK ID    NAME                DRIVER
net1234567    nginx-proxy-network bridge
net2345678    my-first-app-net    bridge
```

## Incremental Deployment

### Adding Projects to Existing Infrastructure

The incremental deployment system intelligently detects your existing proxy and seamlessly adds new projects without disrupting running services.

```bash
# Add second project to existing ecosystem
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name second-app \
  --port 8091 \
  --domain second-app.com \
  --env PRO
```

### Incremental Deployment Intelligence

The system performs automatic detection and decision-making:

```bash
# Proxy Detection Logic (Automatic)
if proxy_exists && proxy_running; then
  log "Proxy detected and running - performing incremental deployment"
  deploy_project_incrementally
elif proxy_exists && proxy_stopped; then
  log "Proxy detected but stopped - starting proxy and deploying"
  start_proxy && deploy_project_incrementally
else
  log "No proxy detected - creating complete infrastructure"
  create_proxy_infrastructure && deploy_project
fi
```

### What Happens During Incremental Deployment

1. **Proxy State Assessment**
   - Detects existing proxy container status
   - Validates proxy configuration integrity
   - Checks network connectivity

2. **Ecosystem Preservation**
   - Verifies existing projects remain untouched
   - Maintains existing network connections
   - Preserves running service availability

3. **Seamless Integration**
   - Creates new project container with isolated network
   - Connects to shared proxy network
   - Updates proxy configuration with hot reload

4. **Zero-Downtime Verification**
   - Tests new project connectivity
   - Validates existing project functionality
   - Confirms proxy routing accuracy

### Expected Results
```bash
# Containers after incremental deployment
CONTAINER ID  IMAGE                 COMMAND  CREATED  STATUS   PORTS                   NAMES
abc123def456  nginx-proxy:latest    nginx    5m ago   Up       0.0.0.0:8080->80/tcp   nginx-proxy
                                                      0.0.0.0:8443->443/tcp
def456ghi789  my-first-app:latest   nginx    5m ago   Up       8090/tcp               my-first-app
ghi789jkl012  second-app:latest     nginx    1m ago   Up       8091/tcp               second-app

# Networks after incremental deployment
NETWORK ID    NAME                DRIVER
net1234567    nginx-proxy-network bridge
net2345678    my-first-app-net    bridge
net3456789    second-app-net      bridge
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

This avoids having to delete and re-clone the repository for fresh testing! 🎯

## Advanced Deployment Scenarios

### Multi-Project Batch Deployment

Deploy multiple projects efficiently:

```bash
# Deploy multiple projects in sequence
for project in app1 app2 app3; do
  nix --extra-experimental-features "nix-command flakes" develop --command \
  ./scripts/create-project-modular.sh \
    --name $project \
    --port $((8090 + $RANDOM % 100)) \
    --domain $project.com \
    --env PRO
done
```

### Production Deployment

```bash
# Production deployment
nix --extra-experimental-features "nix-command flakes" develop --command \
./scripts/create-project-modular.sh \
  --name production-app \
  --port 8092 \
  --domain myapp.com \
  --env PRO
```

## Deployment Verification

### Automated Health Checks

The deployment system includes comprehensive health verification:

```bash
# Proxy Health Verification
curl -I http://localhost:8080  # Should return 301 redirect to HTTPS
curl -I -k https://localhost:8443  # Should return 200 OK

# Project Health Verification
curl -I -H "Host: my-app.local" http://localhost:8080  # Should return 301
curl -I -k -H "Host: my-app.local" https://localhost:8443  # Should return 200

# Internal Connectivity Verification
podman exec nginx-proxy curl -I http://my-app:80  # Should return 200
```

### Manual Verification Steps

1. **Container Status Check**
   ```bash
   podman ps  # All containers should show "Up" status
   ```

2. **Network Connectivity**
   ```bash
   podman network ls  # Should show proxy network + project networks
   podman inspect nginx-proxy | grep -A 10 "Networks"
   ```

3. **Proxy Configuration**
   ```bash
   podman exec nginx-proxy nginx -t  # Should return "syntax is ok"
   podman exec nginx-proxy cat /etc/nginx/conf.d/domains/*.conf
   ```

4. **Log Verification**
   ```bash
   podman logs nginx-proxy --tail 10  # Should show no errors
   podman logs my-app --tail 10  # Should show successful startup
   ```

## Troubleshooting Deployment Issues

### CRITICAL BUG FIXES RESOLVED (December 2024)

**These issues have been fixed in the current version - documented for reference:**

#### 1. IP Address Detection Malformation ✅ FIXED
- **Problem**: Script concatenated ALL container IP addresses instead of getting specific proxy network IP
- **Symptom**: Malformed IPs like `10.89.6.2010.89.1.106` in proxy_pass directives
- **Root Cause**: `podman inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'` concatenates all IPs
- **Solution**: Implemented grep-based extraction: `podman inspect container | grep -A 10 "nginx-proxy-network" | grep IPAddress`

#### 2. Network Template Parsing with Hyphens ✅ FIXED  
- **Problem**: Podman inspect template parsing failed with network names containing hyphens
- **Symptom**: `template: inspect:1: bad character U+002D '-'` errors with `nginx-proxy-network`
- **Root Cause**: Go template parser cannot handle hyphens in network names
- **Solution**: Replaced template-based approach with grep-based IP extraction

#### 3. Missing HTTP Directive Wrapper ✅ FIXED
- **Problem**: Generated project nginx.conf files missing required `http` directive wrapper  
- **Symptom**: `nginx: [emerg] "server" directive is not allowed here in /etc/nginx/nginx.conf:1`
- **Root Cause**: Configuration generated only server blocks without required http context
- **Solution**: Added proper nginx.conf structure with user, events, and http directives

#### 4. SSL Certificate Security Vulnerability ✅ FIXED
- **Problem**: SSL certificates and private keys being committed to git repository
- **Risk**: Exposure of sensitive cryptographic material in version control
- **Solution**: Added comprehensive .gitignore patterns and removed certificates from git history

### Common Deployment Problems

1. **Proxy Detection Failures**
   ```bash
   # Check proxy container status
   podman ps -a | grep nginx-proxy
   
   # If proxy exists but stopped, restart it
   podman start nginx-proxy
   ```

2. **Network Connection Issues**
   ```bash
   # Verify network connectivity
   podman exec nginx-proxy ping project-name
   
   # Check network configuration
   podman network inspect nginx-proxy-network
   ```

3. **Port Conflicts**
   ```bash
   # Check for port conflicts
   ss -tlnp | grep 8080
   
   # Use different port for project
   ./scripts/create-project-modular.sh --name my-app --port 8095 --domain my-app.local
   ```

4. **SSL Certificate Issues**
   ```bash
   # Check certificate generation logs
   cat ./scripts/logs/generate-certs.log
   
   # Verify certificate files
   ls -la ./projects/my-app/certs/
   ```

### Recovery Procedures

1. **Clean Deployment Recovery**
   ```bash
   # Remove failed deployment
   podman stop my-app && podman rm my-app
   
   # Clean up domain configuration
   rm ./proxy/conf.d/domains/my-app.local.conf
   
   # Restart proxy
   podman restart nginx-proxy
   
   # Retry deployment
   ./scripts/create-project-modular.sh --name my-app --port 8090 --domain my-app.local
   ```

2. **Complete Infrastructure Reset**
   ```bash
   # Stop all containers
   podman stop $(podman ps -q)
   
   # Remove all containers
   podman rm $(podman ps -aq)
   
   # Remove networks
   podman network rm nginx-proxy-network
   
   # Fresh deployment
   ./scripts/create-project-modular.sh --name my-app --port 8090 --domain my-app.local
   ```

## Performance Optimization

### Deployment Performance Metrics

- **From-Scratch Deployment**: 90-120 seconds
- **Incremental Deployment**: 30-60 seconds
- **Network Creation**: 5-10 seconds
- **SSL Certificate Generation**: 10-15 seconds
- **Proxy Configuration Update**: 2-5 seconds

### Optimization Tips

1. **Pre-build Images**
   ```bash
   # Build base images in advance
   podman build -t nginx-proxy:latest ./proxy/
   ```

2. **Parallel Deployments**
   ```bash
   # Deploy multiple projects in parallel (with different ports)
   ./scripts/create-project-modular.sh --name app1 --port 8090 --domain app1.local &
   ./scripts/create-project-modular.sh --name app2 --port 8091 --domain app2.local &
   wait
   ```

3. **Resource Allocation**
   ```bash
   # Set resource limits for containers
   podman run --memory=128m --cpus=0.5 nginx-proxy:latest
   ```

## Security Considerations

### Deployment Security

1. **Network Isolation**: Each project runs in isolated network
2. **SSL/TLS**: Automatic certificate generation and management
3. **Security Headers**: Comprehensive security header configuration
4. **Access Control**: Proxy-controlled access to all projects

### Production Security Checklist

- [ ] Valid SSL certificates installed
- [ ] Security headers enabled
- [ ] Firewall rules configured
- [ ] Access logs enabled
- [ ] Monitoring configured

## Deployment Logs and Monitoring

### Log Locations
```bash
# Deployment logs
./scripts/logs/create-project.log

# Container logs
podman logs nginx-proxy
podman logs project-name

# Nginx access/error logs
./proxy/logs/access.log
./proxy/logs/error.log
./projects/project-name/logs/access.log
./projects/project-name/logs/error.log
```

### Monitoring Commands
```bash
# Real-time log monitoring
tail -f ./scripts/logs/create-project.log

# Container resource usage
podman stats

# Network monitoring
podman network ls
podman port nginx-proxy
```

## Best Practices

### Deployment Best Practices

1. **Always Use Nix Environment**: Ensure consistent tool versions
2. **Verify Before Deploy**: Check system requirements and port availability
3. **Use Meaningful Names**: Project names should be descriptive and unique
4. **Monitor Deployments**: Watch logs during deployment process
5. **Test After Deploy**: Verify all functionality post-deployment

### Naming Conventions

- **Project Names**: `my-app`, `api-service`, `web-frontend`
- **Domains**: `my-app.local` (dev), `my-app.com` (production)
- **Ports**: Sequential starting from 8090, avoid conflicts

### Environment Management

- **Development**: Use `.local` domains with self-signed certificates
- **Production**: Use real domains with production-grade certificates
- **Testing**: Use temporary project names and clean up after testing

The Microservices Nginx Architecture deployment system provides enterprise-grade deployment capabilities with the simplicity of single-command execution, supporting both greenfield deployments and seamless integration with existing infrastructure! 🚀 

## Cloudflare Integration

### Setting Up Cloudflare with SSL

For production deployments with Cloudflare, proper SSL configuration is critical to avoid handshake failures.

#### 1. Cloudflare SSL/TLS Settings

In your Cloudflare dashboard:

1. Go to **SSL/TLS** tab
2. Set SSL/TLS encryption mode to **Full** (not Flexible)
3. Under **Edge Certificates**, ensure **Always Use HTTPS** is enabled
4. Under **Edge Certificates**, set **Minimum TLS Version** to TLS 1.2

#### 2. Verify Domain Configuration

Ensure your domain configuration in the proxy includes all required components for successful SSL handshakes:

```bash
# Check existing domain configuration
cat proxy/conf.d/domains/<your-domain>.conf
```

The configuration must include:
- SSL certificate paths
- SSL settings include
- Security headers include
- Security rules for bot protection
- Rate limiting directives
- Proper HTTP to HTTPS redirect

#### 3. Complete Domain Configuration Example

If your domain configuration is missing any components, update it to match this structure:

```nginx
# Domain configuration for example.com
# Generated automatically for project: example-project

# HTTPS server block
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    http2 on;
    server_name example.com www.example.com;
    
    # SSL certificates
    ssl_certificate /etc/nginx/certs/example.com/cert.pem;
    ssl_certificate_key /etc/nginx/certs/example.com/cert-key.pem;
    
    # Include SSL settings
    include /etc/nginx/conf.d/ssl-settings.conf;
    
    # Include security headers
    include /etc/nginx/conf.d/security-headers.conf;
    
    # Security rules from variables defined in security-headers.conf
    if ($bad_bot = 1) {
        return 444;
    }

    if ($method_allowed = 0) {
        return 444;
    }
    
    # Apply rate limiting
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    # Proxy to project container
    location / {
        proxy_pass http://example-project:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Port $server_port;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 4k;
        proxy_buffers 8 4k;
        proxy_busy_buffers_size 8k;
    }
    
    # Health check endpoint
    location /health {
        proxy_pass http://example-project:80/health;
        access_log off;
    }
    
    # Custom error handling
    error_page 502 504 /50x.html;
    location = /50x.html {
        root /usr/share/nginx/html;
        internal;
    }
}

# HTTP redirect to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name example.com www.example.com;
    
    # Apply rate limiting to HTTP as well
    limit_req zone=securitylimit burst=20 nodelay;
    limit_conn securityconn 20;
    
    return 301 https://$server_name$request_uri;
}
```

#### 4. Reload Proxy Configuration

After updating the domain configuration:

```bash
# Test configuration
nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t

# Reload if test passes
nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -s reload
```

#### 5. Verify SSL Handshake

Test the SSL handshake between Cloudflare and your origin server:

```bash
# Test direct connection (should work)
curl -I -k https://<your-server-ip>:8443 -H "Host: <your-domain>"

# Test through Cloudflare (should also work)
curl -I https://<your-domain>
```

If you see SSL handshake failures in Cloudflare (Error 525), review your domain configuration to ensure it includes all the required components.

### Common Cloudflare SSL Issues

1. **SSL Handshake Failures (Error 525)**
   - **Cause**: Incomplete domain configuration missing critical SSL components
   - **Solution**: Update domain configuration with complete SSL settings

2. **Connection Timeout (Error 522)**
   - **Cause**: Missing port forwarding from standard ports to container ports
   - **Solution**: Set up port forwarding as described in the prerequisites

3. **SSL Certificate Issues (Error 526)**
   - **Cause**: Invalid or expired SSL certificate
   - **Solution**: Update certificates and ensure proper paths in configuration 