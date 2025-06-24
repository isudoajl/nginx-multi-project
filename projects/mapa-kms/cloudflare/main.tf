terraform {
  required_providers {
    cloudflare = {
      source = "cloudflare/cloudflare"
      version = "~> 3.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

resource "cloudflare_record" "domain" {
  zone_id = var.cloudflare_zone_id
  name    = "mapakms.com"
  value   = var.server_ip
  type    = "A"
  ttl     = 1
  proxied = true
  allow_overwrite = true
}

resource "cloudflare_record" "www" {
  zone_id = var.cloudflare_zone_id
  name    = "www"
  value   = "mapakms.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
  allow_overwrite = true
}

# Page rule commented out due to API token permissions
# You can enable this manually in Cloudflare dashboard: SSL/TLS > Edge Certificates > Always Use HTTPS
# resource "cloudflare_page_rule" "https" {
#   zone_id = var.cloudflare_zone_id
#   target  = "http://mapakms.com/*"
#   actions {
#     always_use_https = true
#   }
# }
