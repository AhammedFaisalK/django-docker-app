terraform {
  required_providers {
    fly = {
      source  = "fly-apps/fly"
      version = "0.0.21"
    }
  }
}

provider "fly" {
  fly_api_token = var.fly_api_token
}

resource "fly_app" "django_app" {
  name = var.app_name
  org  = var.fly_org
}

resource "fly_ip" "django_app_ip" {
  app        = fly_app.django_app.name
  type       = "v4"
  depends_on = [fly_app.django_app]
}

resource "fly_ip" "django_app_ip_v6" {
  app        = fly_app.django_app.name
  type       = "v6"
  depends_on = [fly_app.django_app]
}

resource "fly_volume" "django_data" {
  name       = "django_data"
  app        = fly_app.django_app.name
  region     = var.fly_region
  size       = 1
  depends_on = [fly_app.django_app]
}

resource "fly_machine" "django_web" {
  app        = fly_app.django_app.name
  region     = var.fly_region
  name       = "django-web"
  image      = "ahammedfaisal/django-docker-app:latest"
  env        = {
    SECRET_KEY      = var.django_secret_key
    DEBUG           = "False"
    ALLOWED_HOSTS   = "${fly_app.django_app.name}.fly.dev,${fly_ip.django_app_ip.address}"
  }
  
  services = [{
    ports = [{
      port     = 443
      handlers = ["tls", "http"]
    }, {
      port     = 80
      handlers = ["http"]
    }]
    internal_port = 8000
    protocol      = "tcp"
  }]

  mounts = [{
    path   = "/app/data"
    volume = fly_volume.django_data.id
  }]

  depends_on = [fly_app.django_app, fly_volume.django_data]
}