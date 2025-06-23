# Production Port Forwarding Guide

This guide explains how to handle privileged ports (80/443) in production environments for the Nginx Multi-Project Architecture.

## Overview

In production environments like your domain `mapakms.com`, users need to access your services via standard HTTP/HTTPS ports (80/443). However, running containers on privileged ports requires root access, which is not recommended for security reasons.

Our solution uses **port forwarding** to redirect traffic from privileged ports to non-privileged ports, allowing the Nginx proxy container to run safely as a non-root user.

## Port Forwarding Architecture

```
Internet Users → mapakms.com:80/443 → Server → iptables Redirect → Nginx Proxy:8080/8443
```

With Cloudflare integration:

```
Internet Users → Cloudflare Edge → Server:80/443 → iptables Redirect → Nginx Proxy:8080/8443
```

## Setup Options

### Option 1: Using the Dedicated Script (Recommended)

```bash
# Enter the Nix environment
nix --extra-experimental-features "nix-command flakes" develop

# Run the port forwarding script
sudo ./scripts/setup-port-forwarding.sh
```

### Option 2: Using the Production Deployment Script

```bash
# Enter the Nix environment
nix --extra-experimental-features "nix-command flakes" develop

# Set up port forwarding
sudo ./nginx/scripts/prod/prod-deployment.sh --port-forward
```

### Option 3: Manual Systemd Service Installation

```bash
# Copy the service file
sudo cp ./scripts/nginx-port-forward.service /etc/systemd/system/

# Enable and start the service
sudo systemctl daemon-reload
sudo systemctl enable nginx-port-forward
sudo systemctl start nginx-port-forward
```

## Verification

To verify that port forwarding is working correctly:

```bash
# Check iptables rules
sudo iptables -t nat -L PREROUTING

# Test HTTP connection
curl -I http://localhost
# Should connect to port 8080

# Test HTTPS connection
curl -k -I https://localhost
# Should connect to port 8443
```

## Cloudflare Integration

When using Cloudflare with port forwarding:

1. **DNS Configuration**: Point your domain (e.g., `mapakms.com`) to your server's IP address
2. **Proxy Status**: Enable Cloudflare proxying (orange cloud)
3. **SSL/TLS Mode**: Set to "Full (Strict)" for secure connections
4. **Origin Server**: Your server with port forwarding configured
5. **IP Restriction**: Only Cloudflare IPs can access your server directly

## Troubleshooting

### Port Forwarding Not Working

If port forwarding is not working:

1. Check if iptables rules are active:
   ```bash
   sudo iptables -t nat -L PREROUTING | grep REDIRECT
   ```

2. Verify that the Nginx proxy container is running:
   ```bash
   podman ps | grep nginx-proxy
   ```

3. Ensure ports 8080/8443 are not blocked by a firewall:
   ```bash
   sudo ufw status
   # or
   sudo firewall-cmd --list-all
   ```

### Persistent Rules Not Loading After Reboot

If port forwarding rules are not persisting after a reboot:

1. Check if the systemd service is enabled:
   ```bash
   systemctl status nginx-port-forward
   ```

2. Try reinstalling the service:
   ```bash
   sudo ./scripts/setup-port-forwarding.sh
   ```

3. For systems without systemd, verify the network scripts:
   ```bash
   ls -la /etc/network/if-pre-up.d/iptables-restore
   ```

## Security Considerations

1. **Cloudflare IP Restriction**: Only allow traffic from Cloudflare's IP ranges
2. **Real IP Headers**: Configure Nginx to use `CF-Connecting-IP` for client IP
3. **Rate Limiting**: Implement rate limiting at both Cloudflare and Nginx levels
4. **WAF Rules**: Use Cloudflare's Web Application Firewall for additional protection

## Advanced Configuration

For advanced port forwarding configurations, you can modify the scripts:

- `scripts/setup-port-forwarding.sh`: Main port forwarding setup script
- `scripts/nginx-port-forward.service`: Systemd service template
- `nginx/scripts/prod/prod-deployment.sh`: Production deployment script with port forwarding option 