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
  count     = var.create_zone ? 1 : 0
  zone      = var.domain_name
  plan      = var.zone_plan
  account_id = var.account_id
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
    
    # Performance optimization settings
    brotli = "on"
    early_hints = "on"
    http2 = "on"
    http3 = "on"
    zero_rtt = "on"
    
    # Minification settings
    minify {
      css = "on"
      html = "on"
      js = "on"
    }
    
    # Browser cache TTL
    browser_cache_ttl = 14400 # 4 hours
    
    # Response buffering
    response_buffering = "on"
    
    # Image optimization
    polish = var.enable_image_optimization ? "lossless" : "off"
    webp = var.enable_image_optimization ? "on" : "off"
  }
}

# WAF Configuration
# Using WAF rules instead of deprecated waf_package
resource "cloudflare_ruleset" "project_waf" {
  zone_id     = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name        = "Project WAF Rules"
  description = "WAF rules for project protection"
  kind        = "zone"
  phase       = "http_request_firewall_managed"

  rules {
    action = "challenge"
    expression = "(http.request.uri.path contains \"wp-login.php\")"
    description = "Challenge WordPress login attempts"
    enabled = true
  }
}

# Rate Limiting
resource "cloudflare_ruleset" "rate_limiting" {
  zone_id     = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name        = "Rate Limiting Rules"
  description = "Rate limiting for all endpoints"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    action = "challenge"
    ratelimit {
      characteristics = ["ip"]
      period          = 60
      requests_per_period = 100
      mitigation_timeout  = 60
    }
    expression  = "true"
    description = "Rate limiting for all endpoints"
    enabled     = true
  }
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

# Additional page rule for browser caching
resource "cloudflare_page_rule" "browser_cache" {
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  target = "*.${var.domain_name}/static/*"
  priority = 2

  actions {
    browser_cache_ttl = 14400 # 4 hours
    cache_level = "cache_everything"
    edge_cache_ttl = 86400 # 1 day
  }
}

# Cache Configuration
# Using cache rules via ruleset instead of deprecated cache_rules
resource "cloudflare_ruleset" "cache_rules" {
  zone_id     = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name        = "Cache Rules"
  description = "Cache rules for static assets"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  rules {
    action = "set_cache_settings"
    action_parameters {
      edge_ttl {
        mode    = "override_origin"
        default = 2592000 # 30 days
        status_code_ttl {
          status_code = 200
          value       = 2592000 # 30 days
        }
      }
      cache = true
    }
    expression  = "(http.request.uri.path matches \"^/assets/.*\")"
    description = "Cache static assets"
    enabled     = true
  }
  
  # Additional rule for caching API responses
  rules {
    action = "set_cache_settings"
    action_parameters {
      edge_ttl {
        mode    = "override_origin"
        default = 300 # 5 minutes
        status_code_ttl {
          status_code = 200
          value       = 300 # 5 minutes
        }
      }
      cache = true
      cache_key {
        ignore_query_strings_order = false
        custom_key {
          query_string {
            include = ["*"]
          }
        }
      }
    }
    expression  = "(http.request.uri.path matches \"^/api/.*\") and (http.request.method eq \"GET\")"
    description = "Cache GET API responses"
    enabled     = true
  }
}

# Firewall Rules
resource "cloudflare_ruleset" "security_rules" {
  zone_id     = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  name        = "Security Rules"
  description = "Security rules for blocking malicious traffic"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "block"
    expression  = "(http.user_agent contains \"nmap\") or (http.user_agent contains \"sqlmap\") or (http.user_agent contains \"nikto\")"
    description = "Block bad bots"
    enabled     = true
  }
}

# Argo Smart Routing (if enabled)
resource "cloudflare_argo" "smart_routing" {
  count   = var.enable_argo_smart_routing ? 1 : 0
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  smart_routing  = "on"
}

# Tiered Cache (replaces deprecated tiered_caching parameter)
resource "cloudflare_tiered_cache" "tiered_caching" {
  count   = var.enable_argo_smart_routing ? 1 : 0
  zone_id = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
  cache_type = "smart"
} 