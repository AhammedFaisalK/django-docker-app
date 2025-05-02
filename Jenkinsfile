pipeline {
    agent any

    stages {
        stage('Clone Repo') {
            steps {
                git 'https://github.com/your-username/django-docker-app.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t yourusername/django-docker-app .'
            }
        }

        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker tag yourusername/django-docker-app yourusername/django-docker-app:latest'
                    sh 'docker push yourusername/django-docker-app:latest'
                }
            }
        }
    }
}
