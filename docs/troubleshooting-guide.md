# Project Container Troubleshooting Guide

This guide provides solutions for common issues encountered when working with project containers in the Microservices Nginx Architecture.

## Table of Contents

1. [Environment Setup Issues](#environment-setup-issues)
2. [Project Creation Issues](#project-creation-issues)
3. [Certificate Issues](#certificate-issues)
4. [Local Host Configuration Issues](#local-host-configuration-issues)
5. [Development Environment Issues](#development-environment-issues)
6. [Proxy Integration Issues](#proxy-integration-issues)
7. [Container Issues](#container-issues)
8. [Nginx Configuration Issues](#nginx-configuration-issues)
9. [Handling Privileged Ports (80/443) for Nginx Proxy](#handling-privileged-ports-80443-for-nginx-proxy)
10. [Managing the Nginx Proxy](#managing-the-nginx-proxy)

---

## Environment Setup Issues

### Nix Environment Not Active

**Symptoms:**
- Scripts fail with "Please enter Nix environment" error
- Commands not found
- Unexpected behavior in scripts

**Solutions:**
1. Enter the Nix environment:
   ```bash
   nix develop
   ```
2. Check if the environment is active:
   ```bash
   echo $IN_NIX_SHELL
   ```
   Should return `1` if active.
3. If the problem persists, try restarting your terminal and entering the Nix environment again.

### Docker/Podman Not Available

**Symptoms:**
- "Docker/Podman not found" errors
- Container operations fail

**Solutions:**
1. Verify Docker/Podman is installed:
   ```bash
   docker --version
   # or
   podman --version
   ```
2. Ensure the service is running:
   ```bash
   systemctl status docker
   # or
   systemctl status podman
   ```
3. If using Docker, ensure your user is in the docker group:
   ```bash
   sudo usermod -aG docker $USER
   # Then log out and back in
   ```

---

## Project Creation Issues

### Invalid Project Name

**Symptoms:**
- "Invalid project name" error during project creation
- Project creation fails with validation error

**Solutions:**
1. Use only alphanumeric characters and hyphens in the project name
2. Avoid spaces, underscores, and special characters
3. Example of valid project name: `my-project-123`

### Port Already in Use

**Symptoms:**
- "Port already in use" error during project creation or startup
- Container fails to start

**Solutions:**
1. Check if the port is already in use:
   ```bash
   sudo lsof -i :PORT_NUMBER
   ```
2. Choose a different port number
3. Stop the service using the port or use a different port for your project

### Domain Validation Failure

**Symptoms:**
- "Invalid domain format" error
- Domain registration fails

**Solutions:**
1. Ensure the domain follows valid FQDN format (e.g., example.com, sub.example.com)
2. Avoid using localhost or IP addresses as domains
3. Check for typos in the domain name

---

## Certificate Issues

### Certificate Generation Fails

**Symptoms:**
- "OpenSSL error" during certificate generation
- Missing or invalid certificates

**Solutions:**
1. Ensure OpenSSL is installed and available in the Nix environment
2. Check if the output directory exists and is writable
3. For detailed error information, check the logs:
   ```bash
   cat ./scripts/logs/generate-certs.log
   ```

### Certificate Not Trusted by Browser

**Symptoms:**
- Browser security warnings
- "Connection not private" errors

**Solutions:**
1. For development certificates, add an exception in your browser
2. Import the self-signed CA certificate into your browser's trust store:
   ```bash
   # For Chrome/Chromium on Linux
   certutil -d sql:$HOME/.pki/nssdb -A -t "P,," -n "Local Dev CA" -i ./certs/ca.pem
   ```
3. For production, ensure you're using properly signed certificates from a trusted CA

### Certificate Path Issues

**Symptoms:**
- "Certificate not found" errors
- SSL handshake failures

**Solutions:**
1. Verify certificate paths are correct
2. Ensure certificates are readable by the container
3. Check if the certificate and key files exist:
   ```bash
   ls -la /path/to/certificate/file
   ```

---

## Local Host Configuration Issues

### Permission Denied

**Symptoms:**
- "Permission denied" when updating hosts file
- Hosts file update fails

**Solutions:**
1. Run the update-hosts.sh script with sudo:
   ```bash
   sudo ./scripts/update-hosts.sh --domain example.com --action add
   ```
2. Check if the hosts file is writable:
   ```bash
   sudo ls -la /etc/hosts
   ```

### Domain Not Resolving

**Symptoms:**
- Cannot access the project domain in browser
- Domain resolves to wrong IP

**Solutions:**
1. Verify the domain is in the hosts file:
   ```bash
   grep example.com /etc/hosts
   ```
2. Flush DNS cache:
   ```bash
   # For systemd-based systems
   sudo systemd-resolve --flush-caches
   
   # For nscd
   sudo service nscd restart
   
   # For dnsmasq
   sudo systemctl restart dnsmasq
   ```
3. Try clearing browser cache or using a different browser

### Multiple Entries for Same Domain

**Symptoms:**
- Inconsistent domain resolution
- Multiple entries in hosts file

**Solutions:**
1. Remove all entries for the domain and add it again:
   ```bash
   sudo ./scripts/update-hosts.sh --domain example.com --action remove
   sudo ./scripts/update-hosts.sh --domain example.com --action add
   ```
2. Manually edit the hosts file to remove duplicate entries:
   ```bash
   sudo nano /etc/hosts
   ```

---

## Development Environment Issues

### Docker Compose Override Not Generated

**Symptoms:**
- Missing docker-compose.override.yml
- Development-specific settings not applied

**Solutions:**
1. Run the setup action for the development environment:
   ```bash
   ./scripts/dev-environment.sh --project my-project --action setup
   ```
2. Check if the template file exists:
   ```bash
   ls -la ./conf/docker-compose.override.dev.yml
   ```
3. Manually copy and modify the template if needed

### Hot Reload Not Working

**Symptoms:**
- Changes to files not reflected in browser
- Need to restart container to see changes

**Solutions:**
1. Ensure volume mounts are correctly configured in docker-compose.override.yml
2. Check if the files are being modified in the correct location
3. Reload the Nginx configuration:
   ```bash
   ./scripts/dev-environment.sh --project my-project --action reload
   ```

### Container Not Starting

**Symptoms:**
- "Failed to start development environment" error
- Container exits immediately

**Solutions:**
1. Check container logs:
   ```bash
   docker logs my-project
   # or
   podman logs my-project
   ```
2. Verify the Docker Compose configuration
3. Check for port conflicts or resource issues
4. Try stopping and starting the container:
   ```bash
   ./scripts/dev-environment.sh --project my-project --action stop
   ./scripts/dev-environment.sh --project my-project --action start
   ```

---

## Proxy Integration Issues

### Project Not Accessible Through Proxy

**Symptoms:**
- Can access project directly but not through proxy
- 502 Bad Gateway or 503 Service Unavailable errors

**Solutions:**
1. Verify the project is registered with the proxy:
   ```bash
   grep -r your-domain.com ./proxy/conf.d/domains/
   ```
2. Check if the proxy and project containers are on the same network
3. Ensure the proxy configuration is reloaded after changes
4. Check proxy logs for errors:
   ```bash
   docker logs nginx-proxy
   ```

### SSL Certificate Issues with Proxy

**Symptoms:**
- SSL errors when accessing through proxy
- Certificate mismatch warnings

**Solutions:**
1. Ensure the correct certificates are configured in the proxy
2. Verify the domain name in the certificate matches the requested domain
3. Check if the certificate is properly formatted and not expired
4. For development, use the same self-signed CA for all certificates

### Domain Routing Issues

**Symptoms:**
- Requests going to wrong project
- 404 Not Found errors

**Solutions:**
1. Check the domain configuration in the proxy
2. Ensure there are no duplicate domain entries
3. Verify the server_name directive in Nginx configuration
4. Check for default_server settings that might catch requests

---

## Container Issues

### Container Health Check Failures

**Symptoms:**
- Container restarts repeatedly
- "unhealthy" status in Docker/Podman

**Solutions:**
1. Check if the health check endpoint is accessible:
   ```bash
   curl http://localhost:PORT/health
   ```
2. Verify the health check configuration in docker-compose.yml
3. Check container logs for errors
4. Ensure the Nginx configuration includes the health check location

### Network Connectivity Issues

**Symptoms:**
- Containers cannot communicate
- "Network not found" errors

**Solutions:**
1. List networks and verify they exist:
   ```bash
   docker network ls
   # or
   podman network ls
   ```
2. Check if containers are connected to the correct networks
3. Verify network configuration in docker-compose.yml
4. Try recreating the networks:
   ```bash
   docker-compose down
   docker-compose up -d
   ```

### Resource Constraints

**Symptoms:**
- Container performance issues
- Container crashes under load

**Solutions:**
1. Check resource usage:
   ```bash
   docker stats
   # or
   podman stats
   ```
2. Increase resource limits in docker-compose.yml if needed
3. Monitor system resources to ensure sufficient capacity
4. Consider optimizing Nginx configuration for better performance

---

## Nginx Configuration Issues

### Syntax Errors

**Symptoms:**
- "Nginx configuration test failed" errors
- Container fails to start

**Solutions:**
1. Test the Nginx configuration:
   ```bash
   docker exec my-project nginx -t
   # or
   podman exec my-project nginx -t
   ```
2. Check syntax in configuration files
3. Look for missing semicolons, braces, or directives
4. Verify included files exist and are correctly formatted

### 404 Not Found Errors

**Symptoms:**
- Pages or assets not found
- 404 errors in browser

**Solutions:**
1. Check if files exist in the expected location
2. Verify root directive points to the correct directory
3. Check location blocks and try_files directives
4. Look for case sensitivity issues in file paths

### Permission Issues

**Symptoms:**
- 403 Forbidden errors
- "Permission denied" in Nginx error logs

**Solutions:**
1. Check file permissions:
   ```bash
   ls -la /path/to/files
   ```
2. Ensure Nginx user has read access to files
3. Check SELinux contexts if applicable
4. Verify directory permissions allow traversal 

---

## Handling Privileged Ports (80/443) for Nginx Proxy

The Nginx proxy container needs to bind to ports 80 (HTTP) and 443 (HTTPS), which are privileged ports requiring root access on Linux systems. Here are several approaches to handle this issue:

### Option 1: Use Linux Capabilities (Recommended for Local Development)

Docker/Podman can grant specific capabilities to containers without giving them full root access. The `NET_BIND_SERVICE` capability allows binding to privileged ports:

```yaml
# In docker-compose.yml
services:
  nginx-proxy:
    # ...other settings...
    cap_add:
      - NET_BIND_SERVICE
```

This approach has been implemented in the proxy's docker-compose.yml file.

### Option 2: Use Non-Privileged Ports (Default Approach)

Map container's internal ports to non-privileged ports (>1024) on the host:

```yaml
ports:
  - "8080:80"  # Map container's port 80 to host's port 8080
  - "8443:443" # Map container's port 443 to host's port 8443
```

Use the `--non-root` flag with the manage-proxy.sh script:

```bash
./scripts/manage-proxy.sh --action start --non-root
```

### Option 3: Run with Elevated Privileges

Run the container with sudo/root privileges:

```bash
sudo ./scripts/manage-proxy.sh --action start
```

### Option 4: Use Port Forwarding (Recommended for Production)

For production environments, we provide scripts to set up port forwarding from privileged ports to non-privileged ports:

#### Using the Setup Script

```bash
# Run the dedicated port forwarding setup script
sudo ./scripts/setup-port-forwarding.sh
```

This script will:
1. Configure iptables rules to forward traffic from ports 80/443 to 8080/8443
2. Make the rules persistent across reboots
3. Create a systemd service if needed

#### Using the Production Deployment Script

```bash
# Set up port forwarding as part of production deployment
sudo ./nginx/scripts/prod/prod-deployment.sh --port-forward
```

#### Manual Systemd Service Installation

```bash
# Copy the service file
sudo cp ./scripts/nginx-port-forward.service /etc/systemd/system/

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable nginx-port-forward
sudo systemctl start nginx-port-forward
```

#### Verifying Port Forwarding

To verify that port forwarding is working:

```bash
# Check iptables rules
sudo iptables -t nat -L PREROUTING

# Test HTTP connection
curl -I http://localhost
# Should show a connection to port 8080

# Test HTTPS connection
curl -k -I https://localhost
# Should show a connection to port 8443
```

## Managing the Nginx Proxy

Use the `manage-proxy.sh` script to control the Nginx proxy container:

```bash
# Start the proxy (requires root for privileged ports)
sudo ./scripts/manage-proxy.sh --action start

# Start the proxy with non-privileged ports (no root required)
./scripts/manage-proxy.sh --action start --non-root

# Stop the proxy
./scripts/manage-proxy.sh --action stop

# Restart the proxy
./scripts/manage-proxy.sh --action restart

# Check proxy status
./scripts/manage-proxy.sh --action status
```

## Other Common Issues

// ... existing code ... 