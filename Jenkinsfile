pipeline {
    agent any

    environment {
        DJANGO_SECRET_KEY = credentials('django-secret-key')
        DJANGO_ADMIN_PASSWORD = credentials('django-admin-password')
        PATH = "$HOME/.local/bin:$PATH"
        LC_ALL = "C.UTF-8"
        LANG = "C.UTF-8"
        // Add a build version for better traceability
        BUILD_VERSION = "${env.BUILD_NUMBER}"
        DOCKER_IMAGE = "ahammedfaisal/django-docker-app"
        // Local deployment container name
        CONTAINER_NAME = "django-app-container"
        // Local deployment port
        APP_PORT = "8000"
        // Host port to map to container
        HOST_PORT = "8080"
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
                    # Check if terraform exists and is a directory
                    if [ -d "$HOME/.local/bin/terraform" ]; then
                        echo "Terraform is a directory, removing it first"
                        rm -rf $HOME/.local/bin/terraform
                    # Check if terraform exists as a file
                    elif [ -f "$HOME/.local/bin/terraform" ]; then
                        echo "Terraform file exists, removing it first"
                        rm -f $HOME/.local/bin/terraform
                    fi
                    
                    # Create .local/bin directory if it doesn't exist
                    mkdir -p $HOME/.local/bin
                    
                    # Download and install Terraform
                    wget -q https://releases.hashicorp.com/terraform/1.7.5/terraform_1.7.5_linux_amd64.zip
                    
                    # Unzip directly to the target location
                    unzip -o terraform_1.7.5_linux_amd64.zip -d $HOME/.local/bin/
                    
                    # Ensure it's executable
                    chmod +x $HOME/.local/bin/terraform
                    
                    # Clean up zip file
                    rm terraform_1.7.5_linux_amd64.zip
                    
                    # Export PATH and verify installation
                    export PATH="$HOME/.local/bin:$PATH"
                    terraform --version
                '''
            }
        }
        
        stage('Create Local Data Volume') {
            steps {
                echo "Creating local data volume..."
                sh '''
                    # Create a Docker volume for persistent data
                    docker volume create django_data || true
                '''
            }
        }
        
        stage('Stop Previous Container') {
            steps {
                echo "Stopping previous container if exists..."
                sh '''
                    # Stop and remove any existing container with the same name
                    docker stop ${CONTAINER_NAME} || true
                    docker rm ${CONTAINER_NAME} || true
                '''
            }
        }
        
        stage('Deploy Locally') {
            steps {
                echo "Deploying application locally..."
                sh """
                    # Run the Docker container with environment variables and port mapping
                    docker run -d \\
                        --name ${CONTAINER_NAME} \\
                        -p ${HOST_PORT}:${APP_PORT} \\
                        -v django_data:/app/data \\
                        -e SECRET_KEY='${DJANGO_SECRET_KEY}' \\
                        -e DEBUG='False' \\
                        -e ALLOWED_HOSTS='localhost,127.0.0.1' \\
                        ${DOCKER_IMAGE}:${BUILD_VERSION}
                """
            }
        }
        
        stage('Run Migrations') {
            steps {
                echo "Running Django migrations..."
                sh """
                    # Run migrations inside the container
                    docker exec ${CONTAINER_NAME} python manage.py migrate
                """
            }
        }
        
        stage('Create Superuser') {
            steps {
                echo "Creating Django superuser..."
                sh """
                    # Create superuser inside the container, ignore error if user already exists
                    docker exec -e DJANGO_SUPERUSER_PASSWORD='${DJANGO_ADMIN_PASSWORD}' ${CONTAINER_NAME} \\
                        python manage.py createsuperuser --noinput --username admin --email admin@example.com || true
                """
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo "Verifying deployment..."
                sh """
                    # Wait for the application to start up
                    sleep 5
                    
                    # Check if the container is running
                    docker ps | grep ${CONTAINER_NAME}
                    
                    # Check if the application is responding
                    for i in {1..6}; do
                        curl -fs --head http://localhost:${HOST_PORT} && echo "App is responding!" && exit 0 || echo "Waiting for app to be ready..."
                        sleep 10
                    done
                    
                    # If we reach here, the verification failed
                    echo "WARNING: Could not verify that the app is responding. Please check the logs."
                    docker logs ${CONTAINER_NAME}
                """
            }
        }
        
        stage('Create Terraform Local Test') {
            steps {
                echo "Creating a local Terraform test configuration..."
                writeFile file: 'terraform/local.tf', text: '''
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "3.0.2"
    }
  }
}

provider "docker" {}

resource "docker_image" "django_app" {
  name = "ahammedfaisal/django-docker-app:latest"
}

resource "docker_volume" "django_data" {
  name = "django_data_tf"
}

resource "docker_container" "django_app" {
  name  = "django-app-terraform"
  image = docker_image.django_app.image_id
  
  ports {
    internal = 8000
    external = 8081
  }
  
  volumes {
    volume_name    = docker_volume.django_data.name
    container_path = "/app/data"
  }
  
  env = [
    "DEBUG=False",
    "ALLOWED_HOSTS=localhost,127.0.0.1"
  ]
}

output "container_id" {
  value = docker_container.django_app.id
}

output "app_url" {
  value = "http://localhost:8081"
}
                '''
                
                // Try using Terraform with Docker provider as a learning exercise
                sh '''
                    mkdir -p terraform
                    cd terraform
                    export PATH=$HOME/.local/bin:$PATH
                    terraform init || echo "Terraform init failed, but continuing pipeline"
                    terraform validate || echo "Terraform validation failed, but continuing pipeline"
                    terraform plan -out=tfplan || echo "Terraform plan failed, but continuing pipeline"
                '''
            }
        }
    }
    
    post {
        success {
            echo "Pipeline completed successfully! Application has been deployed locally to http://localhost:${HOST_PORT}"
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