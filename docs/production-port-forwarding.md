# Production Port Configuration

> ⚠️ **CRITICAL**: If you're experiencing **Cloudflare Error 522** (Connection timed out), you likely need to set up port forwarding. This is the **#1 issue** with production/VPS deployments.

In a production environment, it's a security best practice to run containers as non-root users. This means the Nginx proxy container cannot bind directly to privileged ports like 80 (HTTP) and 443 (HTTPS) by default.

## 🔥 Quick Fix for Cloudflare Error 522

If you're getting Cloudflare Error 522, apply this fix immediately:

```bash
# Forward traffic from standard ports to container ports
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080
sudo iptables -t nat -A PREROUTING -p tcp --dport 443 -j REDIRECT --to-port 8443

# Make persistent (Ubuntu/Debian):
sudo apt install iptables-persistent && sudo netfilter-persistent save

# Verify it works:
curl -I http://YOUR_SERVER_IP:80
```

This fixes the issue where Cloudflare cannot reach your origin server because it's only listening on ports 8080/8443 instead of standard ports 80/443.

## Unprivileged Port Range Configuration (CURRENT APPROACH)

We now exclusively use the unprivileged ports approach, which modifies the range of unprivileged ports in the Linux kernel. This allows rootless containers to bind directly to ports 80 and 443 without any port forwarding.

### Setup

We provide a script to automatically configure this:

```bash
# Run with sudo privileges
sudo ./scripts/setup-unprivileged-ports.sh
```

This script:
1. Sets the unprivileged port start to 80 (making ports 80 and above available to non-root users)
2. Makes the change persistent by creating a sysctl configuration file
3. Verifies the configuration was applied correctly

### Manual Configuration

If you prefer to configure this manually:

```bash
# Set for current session
echo 80 | sudo tee /proc/sys/net/ipv4/ip_unprivileged_port_start

# Make persistent
echo "net.ipv4.ip_unprivileged_port_start = 80" | sudo tee /etc/sysctl.d/90-unprivileged_port_start.conf

# Apply settings
sudo sysctl -p /etc/sysctl.d/90-unprivileged_port_start.conf
```

### Verification

To verify the configuration:

```bash
cat /proc/sys/net/ipv4/ip_unprivileged_port_start
# Should output: 80
```

## DNS Configuration

When setting up your domain:

1. **DNS Configuration**: Point your domain (e.g., `mapakms.com`) to your server's IP address
2. **SSL/TLS**: Configure proper SSL certificates for secure connections
3. **Origin Server**: Your server with direct port 80/443 binding
4. **Firewall**: Configure appropriate firewall rules for security

## Troubleshooting

### Direct Port Binding Not Working

If direct port binding is not working:

1. Check if the unprivileged port start is configured correctly:
   ```bash
   cat /proc/sys/net/ipv4/ip_unprivileged_port_start
   ```

2. Verify that the Nginx proxy container is running:
   ```bash
   podman ps | grep nginx-proxy
   ```

3. Ensure ports 80/443 are not blocked by a firewall:
   ```bash
   sudo ufw status
   # or
   sudo firewall-cmd --list-all
   ```

4. Check if another process is already using ports 80/443:
   ```bash
   sudo ss -tulpn | grep -E ':80|:443'
   ```

## Security Considerations

1. **IP Restriction**: Configure firewall rules to restrict access to authorized sources
2. **Real IP Headers**: Configure Nginx to properly handle client IP forwarding
3. **Rate Limiting**: Implement rate limiting at the Nginx level
4. **SSL/TLS**: Use proper SSL certificates and secure cipher suites

## Legacy Approaches (DEPRECATED)

The following approaches are no longer supported or recommended:

- Port forwarding with `iptables` (removed)
- Custom systemd services for port forwarding (removed)
- Using privileged containers (security risk)

These methods have been replaced by the more secure and simpler unprivileged ports approach. 