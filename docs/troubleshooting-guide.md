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
11. [Script Architecture Issues](#script-architecture-issues)

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
   nix --extra-experimental-features "nix-command flakes" develop
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

If you can access the service on port 8080/8443 but not on 80/443, it's likely a port forwarding issue.

- **Check iptables Rules**: Ensure that the manual port forwarding rules are correctly set up. For external traffic, you should have `PREROUTING` rules:
  ```bash
  sudo iptables -t nat -L PREROUTING
  ```
  For local traffic, you might need `OUTPUT` rules:
  ```bash
  sudo iptables -t nat -L OUTPUT
  ```
- **Apply Port Forwarding**: If the rules are missing, you need to apply them manually. For example:
  ```bash
  # For external traffic
  sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
  
  # For local traffic
  sudo iptables -t nat -A OUTPUT -o lo -p tcp --dport 80 -j REDIRECT --to-port 8080
  ```
- **Firewall Issues**: Check if a firewall (like `ufw` or `firewalld`) is blocking the ports.

#### 5.3.4. DNS Resolution Issues

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

### Cloudflare Error 521 (Web Server Is Down)

**Symptoms:**
- "Web server is down" error with Error code 521 when accessing site through Cloudflare
- Site works locally but not through Cloudflare

**Causes:**
1. Cloudflare cannot establish a connection to your origin server
2. Your server's firewall is blocking Cloudflare IPs
3. Your server is not listening on the expected ports (80/443)
4. SSL/TLS configuration mismatch between Cloudflare and your server

**Solutions:**
1. Verify your server is accessible from the internet:
   ```bash
   # Check if your ports are open and accessible
   curl -I http://YOUR_SERVER_IP
   ```

2. Ensure your server accepts connections from Cloudflare IPs:
   ```bash
   # Check if Cloudflare IPs are allowed in your firewall
   sudo ufw status
   # or
   sudo firewall-cmd --list-all
   ```

3. Verify SSL configuration matches Cloudflare expectations:
   - If using "Full" or "Full (Strict)" SSL mode in Cloudflare, ensure your server has valid SSL certificates
   - Check certificate validity and expiration:
     ```bash
     nix --extra-experimental-features "nix-command flakes" develop --command \
     podman exec nginx-proxy openssl x509 -in /etc/nginx/certs/mapakms.com/cert.pem -text -noout
     ```

4. Test internal container connectivity:
   ```bash
   # Test if proxy can reach the project container
   nix --extra-experimental-features "nix-command flakes" develop --command \
   podman exec nginx-proxy curl -I http://PROJECT_CONTAINER_IP:80
   ```

5. Check for missing health endpoint:
   - Create a health endpoint in your project container:
     ```bash
     mkdir -p projects/YOUR_PROJECT/html/health
     echo "OK" > projects/YOUR_PROJECT/html/health/index.html
     ```
   - Restart the container to apply changes

6. Verify Cloudflare DNS settings:
   - Ensure DNS records point to the correct IP address
   - Check if the orange cloud (proxied) is enabled for your domain

7. Test with Cloudflare development mode:
   - Temporarily disable Cloudflare proxying (gray cloud) to test direct connection
   - Enable development mode in Cloudflare dashboard to bypass cache

# Troubleshooting Guide

This guide helps you diagnose and fix common issues with the Nginx Multi-Project Architecture.

## General Troubleshooting Steps

1. **Check container status**:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a
   ```

2. **View container logs**:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs nginx-proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs <project-name>
   ```

3. **Test Nginx configuration**:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy nginx -t
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec <project-name> nginx -t
   ```

4. **Check network connectivity**:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman network ls
   nix --extra-experimental-features "nix-command flakes" develop --command podman network inspect nginx-proxy-network
   ```

## Common Issues and Solutions

### Proxy Container Issues

#### Proxy container fails to start

**Symptoms**: The nginx-proxy container stops immediately after starting.

**Possible causes**:
- Invalid Nginx configuration
- Port conflicts (80/443 already in use)
- Missing or invalid certificates
- Domain configuration references non-existent containers

**Solutions**:
1. Check proxy logs:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs nginx-proxy
   ```

2. Clean up stale domain configurations:
   ```bash
   rm -f proxy/conf.d/domains/*.conf
   ```

3. Verify port availability:
   ```bash
   ss -tlnp | grep -E ":(80|443)"
   ```

4. Restart the proxy:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command ./scripts/manage-proxy.sh -a restart
   ```

#### "host not found in upstream" error

**Symptoms**: Proxy logs show "[emerg] host not found in upstream" errors.

**Possible causes**:
- Domain configuration references a container that doesn't exist
- Container exists but is not connected to the proxy network
- DNS resolution issues between containers

**Solutions**:
1. Remove domain configurations for non-existent containers:
   ```bash
   rm -f proxy/conf.d/domains/<non-existent-domain>.conf
   ```

2. Ensure the project container is running:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman ps | grep <project-name>
   ```

3. Connect the container to the proxy network:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman network connect nginx-proxy-network <project-name>
   ```

4. Use IP addresses instead of hostnames in proxy_pass directives:
   - Get container IP:
     ```bash
     nix --extra-experimental-features "nix-command flakes" develop --command podman inspect <project-name> --format '{{.NetworkSettings.Networks.nginx-proxy-network.IPAddress}}'
     ```
   - Update the domain configuration with the IP address

### Project Container Issues

#### Project container fails to start

**Symptoms**: The project container stops immediately after starting.

**Possible causes**:
- Invalid Nginx configuration
- Port conflicts
- Permission issues with mounted volumes

**Solutions**:
1. Check project logs:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs <project-name>
   ```

2. Test Nginx configuration:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec <project-name> nginx -t
   ```

3. Check for port conflicts:
   ```bash
   ss -tlnp | grep <port>
   ```

#### Cannot access project through proxy

**Symptoms**: Project container is running, but you get 502 Bad Gateway when accessing through the proxy.

**Possible causes**:
- Network connectivity issues between proxy and project
- Project container not listening on expected port
- Incorrect proxy configuration

**Solutions**:
1. Test direct connectivity:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy curl -I http://<project-name>
   ```

2. Verify project container IP:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman inspect <project-name> --format '{{range $k, $v := .NetworkSettings.Networks}}{{with $v}}{{.IPAddress}}{{end}}{{end}}'
   ```

3. Check if both containers are on the same network:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman network inspect nginx-proxy-network
   ```

### Script Issues

#### create-project-modular.sh script hangs

**Symptoms**: The script appears to hang at "Waiting for proxy to be ready..."

**Possible causes**:
- Proxy container is crash-looping
- Invalid domain configuration
- Network connectivity issues

**Solutions**:
1. Check proxy container status in another terminal:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman ps -a | grep nginx-proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman logs nginx-proxy
   ```

2. Clean up and restart:
   ```bash
   nix --extra-experimental-features "nix-command flakes" develop --command podman stop nginx-proxy
   nix --extra-experimental-features "nix-command flakes" develop --command podman rm nginx-proxy
   rm -f proxy/conf.d/domains/*.conf
   ```

#### Issues with the modular script structure

**Symptoms**: The `create-project-modular.sh` script fails with errors related to missing functions or modules.

**Possible causes**:
- Missing module files
- Incorrect paths to module files
- Permission issues with module files

**Solutions**:
1. Check if all module files exist:
   ```bash
   ls -la scripts/create-project/modules/
   ```

2. Ensure all module files have execute permissions:
   ```bash
   chmod +x scripts/create-project/main.sh
   chmod +x scripts/create-project/modules/*.sh
   ```

3. Verify the symlink for create-project-modular.sh:
   ```bash
   ls -la scripts/create-project-modular.sh
   ```

4. If issues persist, use the original script as a fallback:
   ```bash
   ./scripts/create-project-modular.sh --name <project-name> --domain <domain> --port <port>
   ```

### SSL Certificate Issues

#### SSL certificate errors

**Symptoms**: Browser shows SSL certificate warnings or errors.

**Possible causes**:
- Self-signed certificates in development environment
- Certificate mismatch with domain name
- Expired certificates

**Solutions**:
1. For development, add security exception in browser
2. Regenerate certificates with correct domain name:
   ```bash
   ./scripts/generate-certs.sh --domain <domain> --output ./projects/<project-name>/certs
   ```
3. Update proxy with new certificates:
   ```bash
   ./scripts/update-proxy.sh --action update --name <project-name> --domain <domain> --ssl
   ```

## Environment-Specific Issues

### Development Environment

#### Cannot access project by domain name

**Symptoms**: Cannot access the project using the domain name in browser.

**Possible causes**:
- Missing hosts file entry
- Proxy not running
- Project container not running

**Solutions**:
1. Update hosts file:
   ```bash
   sudo ./scripts/update-hosts.sh --domain <domain> --action add
   ```

2. Verify hosts file entry:
   ```bash
   grep <domain> /etc/hosts
   ```

### Production Environment

#### Cloudflare integration issues

**Symptoms**: Domain not working with Cloudflare, or SSL issues.

**Possible causes**:
- Missing or incorrect Cloudflare API credentials
- DNS not properly configured
- SSL certificate issues

**Solutions**:
1. Verify Cloudflare credentials:
   ```bash
   echo "CF_TOKEN: ${CF_TOKEN:+SET}"
   echo "CF_ACCOUNT: ${CF_ACCOUNT:+SET}"
   echo "CF_ZONE: ${CF_ZONE:+SET}"
   ```

2. Deploy without Cloudflare first to test:
   ```bash
   ./scripts/create-project-modular.sh --name <project-name> --domain <domain> --port <port> --env PRO
   ```

## Debugging Tips

### For the original monolithic script

1. Enable debug mode for more verbose output:
   ```bash
   DEBUG=1 ./scripts/create-project-modular.sh --name <project-name> --domain <domain> --port <port>
   ```

2. Check the log files:
   ```bash
   cat ./scripts/logs/create-project.log
   ```

### For the modular script structure

1. Enable debug mode for more verbose output:
   ```bash
   DEBUG=1 ./scripts/create-project-modular.sh --name <project-name> --domain <domain> --port <port>
   ```

2. Check the log files:
   ```bash
   cat ./scripts/logs/create-project.log
   ```

3. Debug individual modules:
   ```bash
   DEBUG=1 bash -x ./scripts/create-project/modules/proxy.sh
   ```

4. If you encounter issues with the modular script, you can always fall back to using the original script while troubleshooting.

## Advanced Troubleshooting

### Inspecting container networking

```bash
nix --extra-experimental-features "nix-command flakes" develop --command podman network inspect nginx-proxy-network
```

### Testing internal container connectivity

```bash
nix --extra-experimental-features "nix-command flakes" develop --command podman exec nginx-proxy curl -I http://<project-container-ip>
```

### Checking for stale configurations

```bash
find ./proxy/conf.d/domains -type f -name "*.conf" | xargs grep -l "upstream.*<non-existent-container>"
```

## Script Architecture Issues

### Module Not Found Errors

**Symptoms:**
- "No such file or directory" errors when running scripts
- "source: cannot read" errors
- Script fails immediately after starting

**Solutions:**
1. Verify the module path in the main script:
   ```bash
   grep MODULES_DIR scripts/create-project-modular.sh
   ```
   Should point to `scripts/create-project/modules`

2. Check if all required modules exist:
   ```bash
   ls -la scripts/create-project/modules/
   ```
   Should include: common.sh, args.sh, environment.sh, proxy.sh, project_structure.sh, project_files.sh, deployment.sh, verification.sh

3. If any modules are missing, they need to be created based on the script's requirements.

### Missing Functions

**Symptoms:**
- "function not found" errors
- Script fails during execution with reference to undefined function

**Solutions:**
1. Check if the function is defined in the appropriate module:
   ```bash
   grep -r "function function_name" scripts/
   ```

2. Ensure all required modules are sourced in the main script:
   ```bash
   grep "source" scripts/create-project-modular.sh
   ```

3. Add the missing function to the appropriate module or create a new module if needed.

### Incorrect Project Root Path

**Symptoms:**
- Files created in unexpected locations
- "No such file or directory" errors when accessing project files
- Relative path issues

**Solutions:**
1. Check the PROJECT_ROOT definition in the script:
   ```bash
   grep PROJECT_ROOT scripts/create-project-modular.sh
   ```
   Should be set to the correct root directory of the project

2. Verify the directory structure matches what the script expects:
   ```bash
   ls -la $(dirname $(readlink -f scripts/create-project-modular.sh))/..
   ```

3. Update the PROJECT_ROOT path in the script if necessary.

### Log File Access Issues

**Symptoms:**
- "Permission denied" when writing to log files
- Missing log entries
- Script fails with log-related errors

**Solutions:**
1. Check log directory permissions:
   ```bash
   ls -la scripts/logs/
   ```

2. Create the logs directory if it doesn't exist:
   ```bash
   mkdir -p scripts/logs/
   ```

3. Ensure the current user has write permissions:
   ```bash
   chmod 755 scripts/logs/
   touch scripts/logs/create-project.log
   chmod 644 scripts/logs/create-project.log
   ``` 