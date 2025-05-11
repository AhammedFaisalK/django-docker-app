pipeline {
    agent any

    environment {
        FLY_API_TOKEN = credentials('fly-api-token')
        DJANGO_SECRET_KEY = credentials('django-secret-key')
        DJANGO_ADMIN_PASSWORD = credentials('django-admin-password')
        PATH = "$HOME/.local/bin:$PATH"
        LC_ALL = "C.UTF-8"
        LANG = "C.UTF-8"
        // Add a build version for better traceability
        BUILD_VERSION = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "ahammedfaisal/django-docker-app"
        APP_NAME = "django-docker-app"
    }

    options {
        // Add timeouts to prevent pipeline from hanging
        timeout(time: 60, unit: 'MINUTES')
        // Keep build logs and artifacts for last 10 builds
        buildDiscarder(logRotator(numToKeepStr: '10'))
        // Don't run concurrent builds of the same branch
        disableConcurrentBuilds()
    }

    stages {
        stage('Clone Repo') {
            steps {
                echo "Cloning repository..."
                git branch: 'main', url: 'https://github.com/AhammedFaisalK/django-docker-app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo "Building Docker image..."
                sh """
                    docker build -t ${DOCKER_IMAGE}:${BUILD_VERSION} .
                    docker tag ${DOCKER_IMAGE}:${BUILD_VERSION} ${DOCKER_IMAGE}:latest
                """
            }
        }

        stage('Push to Docker Hub') {
            steps {
                echo "Pushing to Docker Hub..."
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh '''
                        echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin
                        docker push ${DOCKER_IMAGE}:${BUILD_VERSION}
                        docker push ${DOCKER_IMAGE}:latest
                    '''
                }
            }
        }
        
        stage('Install Ansible') {
            steps {
                echo "Installing Ansible..."
                sh '''
                    # Set UTF-8 locale
                    export LC_ALL=C.UTF-8
                    export LANG=C.UTF-8
                    
                    # Install ansible
                    pip install --user ansible
                    
                    # Update PATH
                    export PATH=$HOME/.local/bin:$PATH
                    
                    # Verify installation
                    ansible --version
                '''
            }
        }
        
        stage('Install Terraform') {
            steps {
                echo "Installing Terraform..."
                sh '''
                    # Check if terraform is already installed
                    if [ -f "$HOME/.local/bin/terraform" ]; then
                        echo "Terraform already installed, removing it first"
                        rm -f $HOME/.local/bin/terraform
                    fi
                    
                    # Download and install Terraform directly without requiring sudo
                    wget -q https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
                    
                    # Use -o flag to overwrite without prompting
                    unzip -o terraform_1.7.5_linux_amd64.zip
                    
                    mkdir -p $HOME/.local/bin
                    mv terraform $HOME/.local/bin/
                    
                    # Clean up zip file
                    rm terraform_1.7.5_linux_amd64.zip
                    
                    # Export PATH and verify installation
                    export PATH="$HOME/.local/bin:$PATH"
                    terraform --version
                '''
            }
        }
        
        stage('Setup Infrastructure') {
            steps {
                echo "Setting up infrastructure..."
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
app_name         = "${env.APP_NAME}"
fly_region       = "sjc"
django_secret_key = "${env.DJANGO_SECRET_KEY}"
                """
            }
        }
        
        stage('Create fly.toml') {
            steps {
                echo "Creating fly.toml configuration..."
                writeFile file: 'fly.toml', text: """
app = "${env.APP_NAME}"
primary_region = "sjc"

[build]
  image = "${DOCKER_IMAGE}:${BUILD_VERSION}"

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
                """
            }
        }
        
        stage('Terraform Init and Plan') {
            steps {
                echo "Initializing and planning Terraform configuration..."
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/.local/bin:$PATH
                        terraform init
                        terraform validate
                        terraform plan -out=tfplan
                    '''
                }
            }
        }
        
        stage('Terraform Apply') {
            steps {
                echo "Applying Terraform configuration..."
                dir('terraform') {
                    sh '''
                        export PATH=$HOME/.local/bin:$PATH
                        terraform apply -auto-approve tfplan
                    '''
                }
            }
        }
        
        stage('Install flyctl') {
            steps {
                echo "Installing Fly.io CLI..."
                sh '''
                    # Check if flyctl is already installed
                    if [ -d "$HOME/.fly" ]; then
                        echo "flyctl already installed, updating it"
                    else
                        curl -L https://fly.io/install.sh | FLYCTL_INSTALL=$HOME/.fly sh
                    fi
                    
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    fly version
                '''
            }
        }
        
        stage('Deploy to Fly.io') {
            steps {
                echo "Deploying application to Fly.io..."
                sh """
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    fly auth token \$FLY_API_TOKEN
                    fly deploy --app ${env.APP_NAME} --image ${DOCKER_IMAGE}:${BUILD_VERSION} --strategy immediate
                """
            }
        }
        
        stage('Run Migrations') {
            steps {
                echo "Running Django migrations..."
                sh """
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    # Add a retry mechanism for migrations
                    for i in {1..3}; do
                        fly ssh console --app ${env.APP_NAME} -C "python manage.py migrate" && break || sleep 15
                    done
                """
            }
        }
        
        stage('Create Superuser') {
            steps {
                echo "Creating Django superuser..."
                sh """
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    # The || true ensures this step doesn't fail if the user already exists
                    DJANGO_SUPERUSER_PASSWORD=\$DJANGO_ADMIN_PASSWORD fly ssh console --app ${env.APP_NAME} -C "python manage.py createsuperuser --noinput --username admin --email admin@example.com" || true
                """
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "Verifying deployment..."
                sh """
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    # Check if the application is responding
                    fly status --app ${env.APP_NAME}
                    
                    # Wait for app to be ready (simple check)
                    for i in {1..6}; do
                        curl -fs --head https://${env.APP_NAME}.fly.dev && echo "App is responding!" && exit 0 || echo "Waiting for app to be ready..."
                        sleep 10
                    done
                    
                    # If we reach here, the verification failed
                    echo "WARNING: Could not verify that the app is responding. Please check the deployment manually."
                """
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully! Application has been deployed to https://${env.APP_NAME}.fly.dev"
        }
        
        failure {
            echo "Pipeline failed. Please check the logs for details."
        }
        
        always {
            echo "Cleaning workspace..."
            cleanWs()
        }
    }
}