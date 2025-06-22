# Cloudflare Integration Specification

## Overview
This document specifies the integration between the Nginx microservices architecture and Cloudflare's CDN and security services. The integration is designed for production environments to enhance security, performance, and reliability.

## Core Functionality

1. **DNS Management**
   - Domain registration and management
   - DNS record configuration
   - CNAME flattening

2. **Security Features**
   - Web Application Firewall (WAF)
   - DDoS protection
   - Bot management
   - Rate limiting
   - IP reputation filtering

3. **Performance Optimization**
   - Content caching
   - Argo smart routing
   - Image optimization (Polish)
   - Minification

4. **SSL/TLS Management**
   - Edge certificates
   - Origin certificates
   - TLS configuration

## Integration Components

### Terraform Configuration

The Cloudflare integration is managed through Terraform for infrastructure as code. Each project has its own Terraform configuration for Cloudflare resources.

```
projects/
└── {project-name}/
    └── cloudflare/
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

### Main Terraform Configuration (main.tf)

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Zone resource (if not already existing)
resource "cloudflare_zone" "project_zone" {
  count = var.create_zone ? 1 : 0
  zone  = var.domain_name
  plan  = var.zone_plan
}

# DNS Records
resource "cloudflare_record" "www" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "www"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1 # Auto
  proxied = true
}

resource "cloudflare_record" "root" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name    = "@"
  value   = var.origin_ip
  type    = "A"
  ttl     = 1 # Auto
  proxied = true
}

# SSL/TLS Configuration
resource "cloudflare_zone_settings_override" "ssl_settings" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  settings {
    ssl = "strict"
    always_use_https = "on"
    min_tls_version = "1.2"
    tls_1_3 = "on"
    automatic_https_rewrites = "on"
    universal_ssl = "on"
  }
}

# WAF Configuration
resource "cloudflare_waf_package" "project_waf" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  sensitivity = "high"
  action_mode = "challenge"
}

# Rate Limiting
resource "cloudflare_rate_limit" "project_rate_limit" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  threshold = 100
  period = 1
  match {
    request {
      url_pattern = "/*"
      schemes = ["HTTP", "HTTPS"]
      methods = ["GET", "POST", "PUT", "DELETE", "PATCH", "HEAD"]
    }
  }
  action {
    mode = "challenge"
    timeout = 60
    response {
      content_type = "text/plain"
      body = "Rate limit exceeded"
    }
  }
  disabled = false
  description = "Rate limiting for all endpoints"
}

# Page Rules
resource "cloudflare_page_rule" "cache_everything" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  target = "*.${var.domain_name}/assets/*"
  priority = 1

  actions {
    cache_level = "cache_everything"
    edge_cache_ttl = 2592000 # 30 days
  }
}

# Cache Configuration
resource "cloudflare_cache_rules" "static_cache" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name = "Static Assets Cache"
  expression = "(http.request.uri.path matches \"^/assets/.*\")"
  settings {
    cache = true
    edge_ttl {
      mode = "override_origin"
      default = 2592000 # 30 days
      status_code_ttl {
        status_code = 200
        value = 2592000 # 30 days
      }
    }
  }
}

# Firewall Rules
resource "cloudflare_firewall_rule" "block_bad_bots" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  description = "Block bad bots"
  filter_id = cloudflare_filter.bad_bots.id
  action = "block"
}

resource "cloudflare_filter" "bad_bots" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  description = "Bad bot filter"
  expression = "(http.user_agent contains \"nmap\") or (http.user_agent contains \"sqlmap\") or (http.user_agent contains \"nikto\")"
}
```

### Variables Configuration (variables.tf)

```hcl
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "domain_name" {
  description = "Domain name for the project"
  type        = string
}

variable "origin_ip" {
  description = "Origin server IP address"
  type        = string
}

variable "zone_id" {
  description = "Cloudflare Zone ID (if zone already exists)"
  type        = string
  default     = ""
}

variable "create_zone" {
  description = "Whether to create a new zone or use an existing one"
  type        = bool
  default     = false
}

variable "zone_plan" {
  description = "Cloudflare plan (free, pro, business, enterprise)"
  type        = string
  default     = "free"
}
```

### Example Variables File (terraform.tfvars.example)

```hcl
cloudflare_api_token = "your-api-token"
domain_name = "example.com"
origin_ip = "203.0.113.10"
zone_id = "existing-zone-id" # Only if create_zone = false
create_zone = false
zone_plan = "free"
```

## Nginx Configuration for Cloudflare

### Proxy Configuration

The central Nginx proxy should be configured to accept connections only from Cloudflare's IP ranges:

```nginx
# Include Cloudflare IP ranges
include /etc/nginx/conf.d/cloudflare.conf;
```

### Project Container Configuration

Project containers should be configured to work with Cloudflare:

1. **Real IP Configuration**
   - Trust X-Forwarded-For headers from the proxy
   - Use CF-Connecting-IP header for client IP

2. **SSL/TLS Configuration**
   - Set to "Full (Strict)" in Cloudflare
   - Use valid certificates on the origin server

## Terraform Workflow

1. **Initialization**
   ```bash
   cd projects/{project-name}/cloudflare
   terraform init
   ```

2. **Configuration**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with actual values
   ```

3. **Planning**
   ```bash
   terraform plan -out=tfplan
   ```

4. **Application**
   ```bash
   terraform apply tfplan
   ```

5. **Destruction (if needed)**
   ```bash
   terraform destroy
   ```

## Testing and Validation

### DNS Propagation Check
```bash
dig {domain} @1.1.1.1
```

### SSL/TLS Verification
```bash
curl -vI https://{domain}
```

### Cloudflare Cache Test
```bash
curl -I https://{domain}/assets/image.jpg
# Check for CF-Cache-Status header
```

### WAF Testing
```bash
# Test with known malicious patterns
curl -I "https://{domain}/?id=1' OR 1=1"
```

## Performance Optimization

1. **Cloudflare Cache Settings**
   - Browser Cache TTL: 4 hours
   - Edge Cache TTL: Custom based on content type

2. **Cloudflare Performance Features**
   - Enable Auto Minify (HTML, CSS, JS)
   - Enable Brotli compression
   - Enable HTTP/2 and HTTP/3
   - Enable Early Hints

3. **Image Optimization**
   - Enable Polish (lossless or lossy)
   - Enable WebP conversion

This specification provides a comprehensive guide for integrating Cloudflare with the Nginx microservices architecture. It ensures secure, efficient, and optimized delivery of content through Cloudflare's global network. 