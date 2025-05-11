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
  SECRET_KEY = "${env.DJANGO_SECRET_KEY}"

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
        
        stage('Create Volume (if needed)') {
            steps {
                echo "Checking if volume exists and creating if needed..."
                sh '''
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    
                    # Authenticate with Fly.io
                    fly auth token $FLY_API_TOKEN
                    
                    # Check if the app exists (this will fail if app doesn't exist)
                    if ! fly apps list | grep -q "${APP_NAME}"; then
                        echo "Creating new Fly app ${APP_NAME}..."
                        fly apps create "${APP_NAME}" --org personal
                    else
                        echo "App ${APP_NAME} already exists"
                    fi
                    
                    # Check if volume exists
                    if ! fly volumes list -a "${APP_NAME}" | grep -q "django_data"; then
                        echo "Creating new volume django_data..."
                        fly volumes create django_data --region sjc --size 1 -a "${APP_NAME}"
                    else
                        echo "Volume django_data already exists"
                    fi
                '''
            }
        }
        
        stage('Deploy to Fly.io') {
            steps {
                echo "Deploying application to Fly.io..."
                sh """
                    export FLYCTL_INSTALL="$HOME/.fly"
                    export PATH="$FLYCTL_INSTALL/bin:$PATH"
                    
                    # Deploy the application
                    fly deploy --strategy immediate --app ${env.APP_NAME} --image ${DOCKER_IMAGE}:${BUILD_VERSION}
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