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

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "enable_image_optimization" {
  description = "Enable Cloudflare Image Optimization (Polish)"
  type        = bool
  default     = true
}

variable "enable_argo_smart_routing" {
  description = "Enable Cloudflare Argo Smart Routing (requires Argo subscription)"
  type        = bool
  default     = false
}

variable "enable_mobile_optimization" {
  description = "Enable Cloudflare Mobile Optimization"
  type        = bool
  default     = true
}

variable "enable_mobile_redirect" {
  description = "Enable Cloudflare Mobile Redirect to mobile subdomain"
  type        = bool
  default     = false
}

variable "mobile_subdomain" {
  description = "Subdomain for mobile-specific site version (e.g., 'm' for m.example.com)"
  type        = string
  default     = "m"
}

variable "enable_rocket_loader" {
  description = "Enable Cloudflare Rocket Loader for faster JavaScript loading"
  type        = bool
  default     = true
} 