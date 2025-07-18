# Troubleshooting Guide

This guide provides solutions for common issues encountered when working with the Microservices Nginx Architecture.

## Table of Contents

1. [Deployment Issues](#deployment-issues)
2. [Network Issues](#network-issues)
3. [Certificate Issues](#certificate-issues)
4. [Proxy Configuration Issues](#proxy-configuration-issues)
5. [Project Container Issues](#project-container-issues)
6. [Environment-Specific Issues](#environment-specific-issues)
7. [Cloudflare Integration Issues](#cloudflare-integration-issues)
8. [Critical Bug Fixes](#critical-bug-fixes)

## Deployment Issues

### Script Hangs at "Waiting for proxy to be ready..."

**Symptoms:**
- The `create-project-modular.sh` script hangs indefinitely at "Waiting for proxy to be ready..."
- No error message is displayed

**Causes:**
- Stale domain configuration files referencing non-existent containers
- Proxy container crash-loop due to invalid configuration
- Network connectivity issues between containers

**Solution:**
1. Check proxy container status:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a | grep nginx-proxy
   ```

2. If the container is in a crash-loop (restarting repeatedly), check the logs:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs nginx-proxy
   ```

3. Look for errors like `[emerg] host not found in upstream` which indicate stale domain configurations

4. Clean up stale domain configurations and restart:
   ```bash
   # Clean stale domain configs
   rm -f proxy/conf.d/domains/*.conf
   
   # Stop and remove crashed proxy container
   nix --extra-experimental-features "nix-command flakes" develop --command podman stop nginx-proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman rm nginx-proxy
   
   # Try deployment again
   nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/create-project-modular.sh --name <project> --domain <domain> --port <port> --env <env>
   ```

### Missing Environment Variables

**Symptoms:**
- Cloudflare integration fails
- Script shows errors related to missing environment variables

**Solution:**
1. For Cloudflare integration, ensure these environment variables are set:
   ```bash
   export CF_TOKEN=your_cloudflare_token
   export CF_ACCOUNT=your_cloudflare_account_id
   export CF_ZONE=your_cloudflare_zone_id
   ```

2. If you don't need Cloudflare integration, deploy without it:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/create-project-modular.sh --name <project> --domain <domain> --port <port> --env PRO
   ```

## Network Issues

### Container Connectivity Issues

**Symptoms:**
- Proxy can't reach project containers
- Errors like "host not found in upstream" in nginx-proxy logs
- 502 Bad Gateway errors when accessing projects

**Causes:**
- DNS resolution failures between containers
- Network connectivity issues
- Containers not on the same network

**Solution:**
1. Verify both containers are on the same network:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman network inspect nginx-proxy-network
   ```

2. Check connectivity from proxy to project container:
   ```bash
   # Get project container IP
   nix --extra-experimental-features "nix-command flakes" develop --command podman inspect <project-name> | grep -A 10 "nginx-proxy-network" | grep IPAddress
   
   # Test connectivity from proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy ping <container-ip>
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy curl -I http://<container-ip>:80
   ```

3. If connectivity fails, reconnect containers to the network:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman network connect nginx-proxy-network nginx-proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman network connect nginx-proxy-network <project-name>
   ```

4. If DNS resolution is failing, use IP addresses in proxy_pass directives:
   ```bash
   # Update domain configuration in proxy/conf.d/domains/<domain>.conf
   # Change: proxy_pass http://<project-name>:80;
   # To: proxy_pass http://<container-ip>:80;
   ```

### IP Address Detection Bug

**Symptoms:**
- Malformed IPs like `10.89.6.2010.89.1.106` in proxy_pass directives
- Proxy can't connect to project containers

**Cause:**
- Script concatenating ALL network IP addresses instead of getting specific proxy network IP

**Solution:**
This issue has been fixed in the latest version of the scripts. If you encounter it:

1. Get the correct IP address:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman inspect <project-name> | grep -A 10 "nginx-proxy-network" | grep IPAddress
   ```

2. Manually update the domain configuration:
   ```bash
   # Edit proxy/conf.d/domains/<domain>.conf
   # Fix the proxy_pass directive with the correct IP
   ```

3. Reload the proxy configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -s reload
   ```

## Certificate Issues

### SSL Certificate Issues

**Symptoms:**
- SSL handshake failures
- Browser warnings about invalid certificates
- Errors in nginx logs about missing certificates

**Causes:**
- Missing or invalid certificates
- Certificate paths not correctly configured
- Certificate permissions issues

**Solution:**
1. Verify master certificates exist:
   ```bash
   ls -la certs/cert.pem certs/cert-key.pem
   ```

2. Ensure domain-specific certificates are copied to proxy:
   ```bash
   ls -la proxy/certs/<domain>/cert.pem proxy/certs/<domain>/cert-key.pem
   ```

3. If certificates are missing, recreate them:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/generate-certs.sh --domain <domain>
   
   # Copy certificates to proxy
   mkdir -p proxy/certs/<domain>
   cp certs/<domain>/cert.pem proxy/certs/<domain>/cert.pem
   cp certs/<domain>/cert-key.pem proxy/certs/<domain>/cert-key.pem
   ```

4. Verify certificate paths in domain configuration:
   ```bash
   cat proxy/conf.d/domains/<domain>.conf
   # Ensure paths match: /etc/nginx/certs/<domain>/cert.pem
   ```

5. Reload proxy configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -s reload
   ```

## Proxy Configuration Issues

### "location" directive is not allowed here

**Symptoms:**
- Nginx fails with '"location" directive is not allowed here in /etc/nginx/conf.d/security.conf:25'
- Project container fails to start

**Cause:**
- "location" directive used in http context instead of server context

**Solution:**
1. Edit the security.conf file:
   ```bash
   # Edit projects/<project-name>/conf.d/security.conf
   # Remove or comment out any location blocks
   ```

2. Move location blocks to the server context in nginx.conf:
   ```bash
   # Edit projects/<project-name>/nginx.conf
   # Add location blocks inside the server { } block
   ```

### "host not found in upstream" Error

**Symptoms:**
- Nginx fails with '[emerg] host not found in upstream "project-name"'
- Proxy container crashes or restarts repeatedly

**Causes:**
- Referenced container not running or not reachable
- Network connectivity issues
- Stale domain configurations

**Solution:**
1. Check if the referenced container is running:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman ps | grep <project-name>
   ```

2. If not running, start it:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman start <project-name>
   ```

3. If the container doesn't exist or can't be started, remove the domain configuration:
   ```bash
   rm -f proxy/conf.d/domains/<domain>.conf
   ```

4. Reload proxy configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -s reload
   ```

5. Use IP-based routing instead of hostname-based:
   ```bash
   # Get container IP
   nix --extra-experimental-features "nix-command flakes" develop --command podman inspect <project-name> | grep -A 10 "nginx-proxy-network" | grep IPAddress
   
   # Update domain configuration to use IP instead of hostname
   # Change: proxy_pass http://<project-name>:80;
   # To: proxy_pass http://<container-ip>:80;
   ```

## Project Container Issues

### Container Fails to Start

**Symptoms:**
- Project container fails to start
- Errors in container logs

**Causes:**
- Configuration errors
- Port conflicts
- Resource constraints

**Solution:**
1. Check container logs:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs <project-name>
   ```

2. Check for port conflicts:
   ```bash
   ss -tlnp | grep <port>
   ```

3. Verify nginx configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec <project-name> nginx -t
   ```

4. Fix configuration issues and restart:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman restart <project-name>
   ```

### Nginx Configuration Structure Bug

**Symptoms:**
- Error: "server" directive is not allowed here in /etc/nginx/nginx.conf:1
- Project container fails to start

**Cause:**
- Missing `http` directive wrapper in nginx.conf

**Solution:**
1. Edit the nginx.conf file:
   ```bash
   # Edit projects/<project-name>/nginx.conf
   # Ensure it has the proper structure:
   # user nginx;
   # worker_processes auto;
   # events { ... }
   # http { ... server { ... } ... }
   ```

2. Restart the container:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman restart <project-name>
   ```

## Environment-Specific Issues

### Development Environment Issues

**Symptoms:**
- Local domain resolution fails
- Self-signed certificate warnings

**Solution:**
1. Verify hosts file entry:
   ```bash
   cat /etc/hosts | grep <domain>
   ```

2. If missing, update hosts file:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/update-hosts.sh --domain <domain>
   ```

3. Accept self-signed certificate in browser (expected in development)

### Production Environment Issues

**Symptoms:**
- Cloudflare Error 522 (Connection timed out)
- Site not accessible from the internet

**Cause:**
- Missing port forwarding from standard ports 80/443 to container ports 8080/8443

**Solution:**
1. Set up port forwarding:
   ```bash
   sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
   sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
   ```

2. Make port forwarding persistent (add to system startup):
   ```bash
   # Add to /etc/rc.local or equivalent
   iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
   iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443
   ```

3. Verify Cloudflare SSL/TLS settings:
   - Set SSL/TLS mode to "Full" in Cloudflare dashboard
   - Ensure DNS records point to your server IP

## Cloudflare Integration Issues

### Cloudflare SSL Handshake Failures

**Symptoms:**
- Cloudflare shows "Error 525: SSL handshake failed"
- Site works on direct IP but fails through Cloudflare
- SSL_ERROR_HANDSHAKE_FAILURE_ALERT in browser

**Root Cause:**
- Incomplete domain configurations generated by `create-project-modular.sh` missing critical SSL and security components required for Cloudflare SSL handshake

**Solution:**
1. Ensure domain configuration includes all required components:
   ```bash
   # Check existing domain configuration
   cat proxy/conf.d/domains/<domain>.conf
   ```

2. Update domain configuration with complete SSL and security settings:
   ```bash
   # Edit proxy/conf.d/domains/<domain>.conf to include:
   # - SSL settings include
   # - Security headers include
   # - Security rules for bot protection and method validation
   # - Rate limiting directives
   # - Enhanced proxy headers with timeout and buffer settings
   # - Both HTTPS server block and HTTP redirect block
   ```

3. Example of complete domain configuration:
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

4. Reload proxy configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -s reload
   ```

5. Verify Cloudflare SSL/TLS settings:
   - Set SSL/TLS mode to "Full" in Cloudflare dashboard
   - Ensure Origin Server SSL Certificates are valid

### Key Fixes for Cloudflare SSL Handshake Issues

1. **Container Name Resolution**:
   - Use `proxy_pass http://<project-name>:80;` for stable DNS resolution
   - Ensure project container is on the same network as the proxy

2. **Complete SSL Configuration**:
   - Include SSL settings: `include /etc/nginx/conf.d/ssl-settings.conf;`
   - Verify SSL certificate paths are correct

3. **Security Headers**:
   - Include security headers: `include /etc/nginx/conf.d/security-headers.conf;`
   - Add security rules for bot protection and method validation

4. **Rate Limiting**:
   - Add rate limiting directives: `limit_req zone=securitylimit burst=20 nodelay;`
   - Add connection limiting: `limit_conn securityconn 20;`

5. **Enhanced Proxy Headers**:
   - Set all required headers: Host, X-Real-IP, X-Forwarded-For, etc.
   - Configure timeouts and buffer settings

6. **Proper Structure**:
   - Include both HTTPS server block and HTTP redirect block
   - Ensure HTTP block redirects to HTTPS

## Critical Bug Fixes

The following critical bugs have been fixed in the latest version of the system:

### 1. IP Address Detection Bug (FIXED)

**Problem**: Script was concatenating ALL network IP addresses instead of getting specific proxy network IP
**Symptom**: Malformed IPs like `10.89.6.2010.89.1.106` in proxy_pass directives
**Root Cause**: `podman inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}'` returns all IPs concatenated
**Fix**: Use grep-based extraction: `podman inspect container | grep -A 10 "nginx-proxy-network" | grep IPAddress`

### 2. Network Name Template Parsing Bug (FIXED)

**Problem**: Podman inspect template parsing fails with network names containing hyphens
**Symptom**: `template: inspect:1: bad character U+002D '-'` errors with `nginx-proxy-network`
**Root Cause**: Go template parser cannot handle network names with hyphens in template syntax
**Fix**: Replaced template-based approach with grep-based IP extraction

### 3. Nginx Configuration Structure Bug (FIXED)

**Problem**: Generated project nginx.conf missing `http` directive wrapper
**Symptom**: `nginx: [emerg] "server" directive is not allowed here in /etc/nginx/nginx.conf:1`
**Root Cause**: Configuration generated only server block without required http context
**Fix**: Added proper nginx.conf structure with user, events, and http directives

### 4. SSL Certificate Security Vulnerability (FIXED)

**Problem**: SSL certificates and private keys were being committed to git repository
**Symptom**: Sensitive cryptographic material exposed in version control
**Root Cause**: Missing .gitignore patterns for certificate files
**Fix**: Added comprehensive .gitignore for *.pem, *.key, *.crt, certs/ directories

### 5. Critical Incremental Deployment Failures (FIXED)

**Problem**: Incremental deployments cause downtime to existing projects
**Symptoms**:
  - SSL handshake failures on existing projects during new project deployment
  - Certificate mounting failures (script copies to wrong directory)
  - Proxy configuration reload failures bringing down all projects
  - Network connectivity issues after container rebuilds
**Root Causes**:
  - Script fails to copy domain-specific certificates to proxy/certs/ directory (only copies to root certs/)
  - Inconsistent certificate paths between project containers and proxy container
  - IP address detection fails after container rebuilds, creating invalid proxy_pass directives
  - No verification of network connectivity before updating proxy configuration
  - Proxy reload can fail and bring down existing projects
**Fix**: Comprehensive improvements to deployment process:
  - Proper certificate copying to both locations
  - Reliable IP address detection
  - Network connectivity verification before configuration updates
  - Configuration testing before reload
  - Rollback capability if reload fails

### 6. Incomplete Domain Configuration for Cloudflare SSL (FIXED)

**Problem**: Domain configurations missing critical SSL and security components
**Symptom**: Cloudflare SSL handshake failures (Error 525)
**Root Cause**: `create-project-modular.sh` generating incomplete domain configs
**Fix**: Enhanced domain configuration generation with:
  - Complete SSL configuration with proper includes
  - Security headers and rules
  - Rate limiting directives
  - Enhanced proxy headers
  - Proper HTTPS and HTTP redirect structure 