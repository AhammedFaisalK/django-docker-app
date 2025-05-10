variable "fly_api_token" {
  description = "Fly.io API token"
  type        = string
  sensitive   = true
}

variable "fly_org" {
  description = "Fly.io organization name"
  type        = string
}

variable "app_name" {
  description = "Name of the Fly.io application"
  type        = string
  default     = "django-docker-app"
}

variable "fly_region" {
  description = "Fly.io region to deploy in"
  type        = string
  default     = "sjc" # San Jose, California
}

variable "django_secret_key" {
  description = "Django SECRET_KEY"
  type        = string
  sensitive   = true
}