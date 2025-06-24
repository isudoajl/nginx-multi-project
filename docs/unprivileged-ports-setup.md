# Unprivileged Ports Setup Guide

## Overview

This guide explains how to configure your Linux system to allow non-root users (including rootless containers) to bind to privileged ports (ports below 1024, like 80 and 443). This is a key security enhancement that allows our Nginx proxy container to bind directly to standard HTTP/HTTPS ports without requiring root privileges.

## Why This Matters

By default, Linux systems only allow processes running as root to bind to ports below 1024. This is a security measure, but it creates challenges when running containerized applications that need to use standard ports like 80 (HTTP) and 443 (HTTPS).

Our solution modifies the Linux kernel's unprivileged port range to allow non-root processes to bind to ports 80 and above, eliminating the need for port forwarding or running containers as root.

## Setup Instructions

### Automated Setup (Recommended)

We provide a script that automates the entire setup process:

```bash
# Run with sudo privileges
sudo ./scripts/setup-unprivileged-ports.sh
```

This script:
1. Sets the unprivileged port start to 80 (making ports 80 and above available to non-root users)
2. Makes the change persistent by creating a sysctl configuration file
3. Verifies the configuration was applied correctly

### Manual Setup

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

## Security Considerations

This change allows any non-root process on the system to bind to ports 80 and above. While this is generally acceptable for most systems, consider these security implications:

1. **Multi-tenant Systems**: If your server hosts multiple users, they will all be able to bind to these ports
2. **Service Conflicts**: Multiple services could attempt to bind to the same port
3. **Principle of Least Privilege**: This slightly increases the attack surface by allowing non-root processes more capabilities

For most deployments, the security benefits of running containers as non-root outweigh these considerations.

## Troubleshooting

### Permission Denied When Binding to Port 80/443

If you still get "permission denied" when trying to bind to ports 80/443:

1. Verify the configuration was applied:
   ```bash
   cat /proc/sys/net/ipv4/ip_unprivileged_port_start
   ```

2. Check if another process is already using these ports:
   ```bash
   sudo lsof -i :80
   sudo lsof -i :443
   ```

3. Ensure your firewall allows these ports:
   ```bash
   sudo ufw status
   # or
   sudo firewall-cmd --list-all
   ```

### Configuration Not Persisting After Reboot

If the setting doesn't persist after reboot:

1. Check if the sysctl file was created:
   ```bash
   cat /etc/sysctl.d/90-unprivileged_port_start.conf
   ```

2. Manually apply the setting after reboot:
   ```bash
   sudo sysctl -p /etc/sysctl.d/90-unprivileged_port_start.conf
   ```

## System Compatibility

This configuration works on:

- Most modern Linux distributions (Ubuntu, Debian, CentOS, Fedora, etc.)
- Kernel version 4.11 and newer
- Both physical servers and virtual machines

## Related Documentation

- [Production Port Configuration](./production-port-forwarding.md)
- [Project Overview](./project-overview.md)
- [Deployment Guide](./deployment-guide.md) 