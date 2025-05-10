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
        
        stage('Install Dependencies') {
            steps {
                sh 'pip install ansible terraform'
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
        
        stage('Ansible Deploy') {
            steps {
                ansiblePlaybook(
                    playbook: 'deploy.yml',
                    inventory: 'inventory',
                    extraVars: [
                        app_name: 'django-docker-app',
                        fly_org: 'personal',
                        docker_image: 'ahammedfaisal/django-docker-app',
                        docker_tag: 'latest'
                    ],
                    colorized: true
                )
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}