pipeline {
    agent any

    environment {
        FLY_API_TOKEN = credentials('fly-api-token')
        DJANGO_SECRET_KEY = credentials('django-secret-key')
        DJANGO_ADMIN_PASSWORD = credentials('django-admin-password')
    }

    stages {
        stage('Clone Repo') {
            steps {
                git branch: 'main', url: 'https://github.com/AhammedFaisalK/django-docker-app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ahammedfaisal/django-docker-app .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker tag ahammedfaisal/django-docker-app ahammedfaisal/django-docker-app:latest'
                    sh 'docker push ahammedfaisal/django-docker-app:latest'
                }
            }
        }
        
        stage('Install Ansible') {
            steps {
                sh 'pip install --user ansible'
            }
        }
        
        stage('Install Terraform') {
            steps {
                sh '''
                    wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
                    echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
                    sudo apt-get update && sudo apt-get install -y terraform
                '''
            }
        }
        
        stage('Setup Infrastructure') {
            steps {
                // Create terraform directory if it doesn't exist
                sh 'mkdir -p terraform'
                
                // Create main.tf
                writeFile file: 'terraform/main.tf', text: '''
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
                '''
                
                // Create variables.tf
                writeFile file: 'terraform/variables.tf', text: '''
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
                '''
                
                // Create outputs.tf
                writeFile file: 'terraform/outputs.tf', text: '''
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
                '''
                
                // Create terraform.tfvars
                writeFile file: 'terraform/terraform.tfvars', text: """
fly_api_token    = "${env.FLY_API_TOKEN}"
fly_org          = "personal"
app_name         = "django-docker-app"
fly_region       = "sjc"
django_secret_key = "${env.DJANGO_SECRET_KEY}"
                """
            }
        }
        
        stage('Create fly.toml') {
            steps {
                writeFile file: 'fly.toml', text: '''
app = "django-docker-app"
primary_region = "sjc"

[build]
  image = "ahammedfaisal/django-docker-app:latest"

[env]
  PORT = "8000"
  DEBUG = "False"

[http_service]
  internal_port = 8000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 1
  processes = ["app"]

[[vm]]
  cpu_kind = "shared"
  cpus = 1
  memory_mb = 1024

[mounts]
  source = "django_data"
  destination = "/app/data"
                '''
            }
        }
        
        stage('Terraform Init and Plan') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform plan -out=tfplan'
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve tfplan'
                }
            }
        }
        
        stage('Install flyctl') {
            steps {
                sh '''
                    curl -L https://fly.io/install.sh | sh
                    echo 'export FLYCTL_INSTALL="/var/lib/jenkins/.fly"' >> ~/.bashrc
                    echo 'export PATH="$FLYCTL_INSTALL/bin:$PATH"' >> ~/.bashrc
                    export FLYCTL_INSTALL="/var/lib/jenkins/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                '''
            }
        }
        
        stage('Deploy to Fly.io') {
            steps {
                sh '''
                    export FLYCTL_INSTALL="/var/lib/jenkins/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    flyctl auth token $FLY_API_TOKEN
                    flyctl deploy --app django-docker-app --image ahammedfaisal/django-docker-app:latest
                '''
            }
        }
        
        stage('Run Migrations') {
            steps {
                sh '''
                    export FLYCTL_INSTALL="/var/lib/jenkins/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    flyctl ssh console --app django-docker-app -C "python manage.py migrate"
                '''
            }
        }
        
        stage('Create Superuser') {
            steps {
                sh '''
                    export FLYCTL_INSTALL="/var/lib/jenkins/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    DJANGO_SUPERUSER_PASSWORD=$DJANGO_ADMIN_PASSWORD flyctl ssh console --app django-docker-app -C "python manage.py createsuperuser --noinput --username admin --email admin@example.com" || true
                '''
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}