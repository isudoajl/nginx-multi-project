# Production Environment Documentation

This document provides comprehensive information about the production environment setup, deployment procedures, maintenance tasks, and disaster recovery processes.

## Table of Contents

1. [Production Environment Overview](#production-environment-overview)
2. [Deployment Process](#deployment-process)
3. [Certificate Management](#certificate-management)
4. [Maintenance Procedures](#maintenance-procedures)
5. [Monitoring and Logging](#monitoring-and-logging)
6. [Security Measures](#security-measures)
7. [Disaster Recovery](#disaster-recovery)
8. [Troubleshooting](#troubleshooting)

## Production Environment Overview

The production environment is designed for high availability, security, and performance. It includes the following components:

- **Nginx**: Serves as the primary web server and reverse proxy
- **Cloudflare**: Provides CDN, WAF, and DDoS protection
- **SSL/TLS**: Ensures secure communication with end-users
- **Monitoring**: Tracks system health and performance metrics
- **Logging**: Captures detailed information for troubleshooting and analysis
- **Port Forwarding**: Handles privileged ports (80/443) redirection to non-privileged ports

### Environment-Specific Configuration

The production environment uses specific configurations optimized for security and performance:

- Enhanced security headers
- Strict SSL/TLS settings
- Production-grade compression settings
- Optimized caching rules
- Rate limiting and bot protection

## Deployment Process

### Prerequisites

Before deploying to production, ensure the following:

1. All tests pass in the development environment
2. Configuration has been validated
3. SSL certificates are valid and properly configured
4. Backup of the current production configuration exists

### Deployment Steps

1. **Prepare Deployment**:
   ```bash
   # Enter the Nix environment
   nix develop
   
   # Validate the production configuration
   ./nginx/scripts/prod/prod-deployment.sh --validate
   ```

2. **Backup Current Configuration**:
   ```bash
   # Backup the current production configuration
   ./nginx/scripts/prod/prod-deployment.sh --backup
   ```

3. **Deploy to Production**:
   ```bash
   # Deploy the configuration to production
   ./nginx/scripts/prod/prod-deployment.sh --deploy
   ```

4. **Verify Deployment**:
   - Check that the Nginx service is running correctly
   - Verify that SSL certificates are working properly
   - Test key functionality to ensure everything works as expected

### Rollback Procedure

If issues are encountered after deployment:

```bash
# Restore from the most recent backup
./nginx/scripts/prod/prod-deployment.sh --restore /path/to/backup
```

## Port Forwarding in Production

In production environments, the Nginx proxy container listens on non-privileged ports (8080/8443) to avoid requiring root privileges. However, external users need to access the standard HTTP/HTTPS ports (80/443). To handle this, we use port forwarding.

### Setting Up Port Forwarding

```bash
# Enter the Nix environment
nix develop

# Set up port forwarding (requires root privileges)
sudo ./nginx/scripts/prod/prod-deployment.sh --port-forward
```

Alternatively, you can use the dedicated port forwarding script:

```bash
sudo ./scripts/setup-port-forwarding.sh
```

### How Port Forwarding Works

The port forwarding setup:

1. Creates iptables rules to redirect traffic from ports 80/443 to 8080/8443
2. Makes these rules persistent across system reboots
3. Creates a systemd service if needed for automatic startup

### Traffic Flow with Port Forwarding

```
External Users → Port 80/443 → iptables Redirect → Ports 8080/8443 → Nginx Proxy Container
```

When combined with Cloudflare:

```
Users → Cloudflare Edge (Port 80/443) → Your Server (Port 80/443) → iptables Redirect → Ports 8080/8443 → Nginx Proxy
```

### Verifying Port Forwarding

To verify that port forwarding is working correctly:

```bash
# Check the iptables rules
sudo iptables -t nat -L PREROUTING

# Test HTTP access
curl -I http://your-domain.com

# Test HTTPS access
curl -k -I https://your-domain.com
```

## Certificate Management

SSL/TLS certificates are critical for secure communication. The following procedures ensure proper certificate management.

### Certificate Acquisition

To acquire new SSL certificates:

```bash
# Acquire a new certificate for a domain
./nginx/scripts/prod/cert-management.sh --acquire example.com
```

### Certificate Renewal

Certificates should be renewed before they expire:

```bash
# Manually renew certificates
./nginx/scripts/prod/cert-management.sh --renew

# Setup automatic renewal cron job
./nginx/scripts/prod/cert-management.sh --setup-cron
```

### Certificate Validation

To validate certificates:

```bash
# Check certificate status
./nginx/scripts/prod/cert-management.sh --status

# Validate certificates
./nginx/scripts/prod/cert-management.sh --validate
```

## Maintenance Procedures

Regular maintenance ensures the production environment remains secure, stable, and performant.

### Routine Maintenance Tasks

1. **Weekly Tasks**:
   - Check for Nginx and dependency updates
   - Review logs for errors or unusual patterns
   - Verify certificate expiration dates

2. **Monthly Tasks**:
   - Apply security updates
   - Review and optimize configuration
   - Check for performance bottlenecks

3. **Quarterly Tasks**:
   - Conduct security audits
   - Review and update security policies
   - Test disaster recovery procedures

### Configuration Updates

When updating the production configuration:

1. Test changes in the development environment first
2. Create a backup before applying changes
3. Apply changes during a maintenance window
4. Validate the configuration after changes
5. Monitor the system closely after updates

## Monitoring and Logging

### Log Locations

- Access logs: `/var/log/nginx/access.log`
- Error logs: `/var/log/nginx/error.log`
- Certificate logs: `/var/log/cert-renewal.log`

### Monitoring Metrics

Key metrics to monitor:

- Request rate and response time
- Error rate (4xx and 5xx responses)
- CPU and memory usage
- Disk I/O and network traffic
- SSL certificate expiration

### Log Rotation

Logs are automatically rotated to prevent disk space issues:

```bash
# Log rotation configuration
/etc/logrotate.d/nginx
```

## Security Measures

The production environment implements several security measures:

### HTTP Security Headers

- `X-Frame-Options`: Prevents clickjacking attacks
- `X-Content-Type-Options`: Prevents MIME type sniffing
- `X-XSS-Protection`: Provides XSS protection
- `Content-Security-Policy`: Restricts resource loading
- `Strict-Transport-Security`: Enforces HTTPS connections

### Cloudflare Security Features

- Web Application Firewall (WAF)
- DDoS protection
- Rate limiting
- Bot management
- SSL/TLS encryption

### Access Control

- IP-based access restrictions for administrative interfaces
- Strong authentication for management endpoints
- Principle of least privilege for service accounts

## Disaster Recovery

### Backup Strategy

1. **Configuration Backups**:
   - Automated daily backups
   - Manual backups before major changes
   - Backups stored in multiple locations

2. **Certificate Backups**:
   - Backed up with configuration
   - Stored securely with restricted access

### Recovery Procedures

#### Complete System Failure

1. Provision new server infrastructure
2. Install Nginx and dependencies
3. Restore configuration from backup
4. Restore certificates
5. Validate the restored system
6. Update DNS if necessary

#### Configuration Corruption

1. Identify the issue
2. Restore configuration from the most recent backup
3. Validate the restored configuration
4. Reload or restart services as needed

#### Certificate Issues

1. Check certificate status
2. Renew or reissue certificates if needed
3. Verify certificate installation
4. Restart Nginx to apply changes

## Troubleshooting

### Common Issues and Solutions

#### SSL Certificate Problems

**Issue**: SSL certificate errors or warnings

**Solution**:
```bash
# Check certificate status
./nginx/scripts/prod/cert-management.sh --status

# Renew certificate if needed
./nginx/scripts/prod/cert-management.sh --renew
```

#### Configuration Errors

**Issue**: Nginx fails to start or reload

**Solution**:
```bash
# Validate configuration
./nginx/scripts/prod/prod-deployment.sh --validate

# Check Nginx error logs
tail -f /var/log/nginx/error.log
```

#### Performance Issues

**Issue**: Slow response times

**Solution**:
- Check for high CPU or memory usage
- Review access logs for unusual traffic patterns
- Verify Cloudflare optimization settings
- Check for network bottlenecks

### Support Resources

- Internal documentation: `/nginx/docs/`
- Nginx official documentation: [https://nginx.org/en/docs/](https://nginx.org/en/docs/)
- Cloudflare documentation: [https://developers.cloudflare.com/](https://developers.cloudflare.com/) 