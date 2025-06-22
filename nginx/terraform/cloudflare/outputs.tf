output "zone_id" {
  description = "The ID of the Cloudflare zone"
  value       = var.create_zone ? cloudflare_zone.project_zone[0].id : var.zone_id
}

output "name_servers" {
  description = "The name servers for the zone"
  value       = var.create_zone ? cloudflare_zone.project_zone[0].name_servers : []
}

output "www_record_id" {
  description = "The ID of the www DNS record"
  value       = cloudflare_record.www.id
}

output "root_record_id" {
  description = "The ID of the root DNS record"
  value       = cloudflare_record.root.id
} 