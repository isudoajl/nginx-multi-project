# Cloudflare Terraform Configuration

This directory contains Terraform configurations for managing Cloudflare resources for the Nginx microservices architecture.

## Files

- `main.tf` - Main Terraform configuration file containing resource definitions
- `variables.tf` - Variable definitions for the Terraform configuration
- `outputs.tf` - Output definitions for the Terraform configuration
- `terraform.tfvars.example` - Example variables file (copy to terraform.tfvars for use)

## Usage

### Prerequisites

- Terraform installed (v1.0.0 or later)
- Cloudflare API token with appropriate permissions
- Domain registered and accessible in your Cloudflare account (if using existing zone)

### Setup

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:
   - `cloudflare_api_token` - Your Cloudflare API token
   - `domain_name` - The domain name for your project
   - `origin_ip` - The IP address of your origin server
   - `zone_id` - The ID of your existing Cloudflare zone (if `create_zone = false`)
   - `create_zone` - Whether to create a new zone or use an existing one
   - `zone_plan` - The Cloudflare plan to use (free, pro, business, enterprise)
   - `enable_image_optimization` - Whether to enable Cloudflare Polish for image optimization
   - `enable_argo_smart_routing` - Whether to enable Argo Smart Routing (requires Argo subscription)

### Initialization

Initialize the Terraform configuration:

```bash
terraform init
```

### Planning

Create a Terraform execution plan:

```bash
terraform plan -out=tfplan
```

### Application

Apply the Terraform execution plan:

```bash
terraform apply tfplan
```

### Destruction

If needed, destroy the created resources:

```bash
terraform destroy
```

## Resources Created

This Terraform configuration creates and manages the following Cloudflare resources:

- Zone (optional)
- DNS records (www and root domain)
- SSL/TLS settings
- WAF configuration
- Rate limiting rules
- Page rules for caching
- Cache configuration
- Firewall rules

## Performance Optimization Features

This configuration includes several performance optimization features:

### Compression and Protocol Optimization
- Brotli compression for faster content delivery
- HTTP/2 and HTTP/3 support for improved connection efficiency
- Early Hints for faster page loads
- Zero Round Trip Time (0-RTT) for returning visitors

### Caching Optimization
- Browser cache TTL settings (4 hours default)
- Edge cache configuration for static assets (30 days)
- API response caching for GET requests (5 minutes)
- Custom cache key configuration for query parameters

### Content Optimization
- Automatic minification of HTML, CSS, and JavaScript
- Image optimization with Cloudflare Polish (lossless by default)
- WebP conversion for supported browsers
- Response buffering for smoother content delivery

### Routing Optimization
- Argo Smart Routing for optimized network paths (optional)
- Tiered caching for improved cache hit rates

## Testing

To test the performance optimization configuration:

```bash
../tests/test-performance-optimization.sh
```

This script verifies that all performance optimization settings are correctly configured.

## Integration with Nginx

The Cloudflare configuration works in conjunction with the Nginx proxy and project containers. The proxy should be configured to:

1. Accept connections only from Cloudflare IP ranges
2. Use proper SSL/TLS certificates
3. Handle Cloudflare-specific headers (CF-Connecting-IP, etc.)

For more details on the integration, see the main project documentation. 