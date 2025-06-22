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