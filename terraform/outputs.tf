output "app_url" {
  description = "URL of the deployed application"
  value       = "https://${fly_app.django_app.name}.fly.dev"
}

output "ipv4_address" {
  description = "IPv4 address of the application"
  value       = fly_ip.django_app_ip.address
}

output "ipv6_address" {
  description = "IPv6 address of the application"
  value       = fly_ip.django_app_ip_v6.address
}