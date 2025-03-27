pipeline {
    agent any
    
    environment {
        DOCKER_HUB = credentials('docker-hub-creds')
        AWS_SSH_KEY = credentials('aws-key.pem')
        DOCKER_IMAGE = "yassine112/mon-app-web"
        VERSION = env.BUILD_NUMBER ?: "latest"
        REVIEW_IP = "51.21.180.149"
        STAGING_IP = "51.20.56.9"
        PROD_IP = "13.60.156.76"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', credentialsId: 'github-credentials', url: 'https://github.com/YassineDev32/Tp_Jenkins_Docker_AWS.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    echo "Building Docker image: ${DOCKER_IMAGE}:${VERSION}"
                    bat """
                        docker build -t ${DOCKER_IMAGE}:${VERSION} .
                    """
                }
            }
        }

        stage('Test Image') {
            steps {
                script {
                    echo "Testing Docker image..."
                    bat """
                        docker run -d -p 8080:80 --name test-container ${DOCKER_IMAGE}:${VERSION}
                        timeout /t 10 /nobreak
                        curl -I http://localhost:8080 || exit 1
                        docker stop test-container
                        docker rm test-container
                    """
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    echo "Pushing image to Docker Hub..."
                    bat """
                        echo ${DOCKER_HUB_PSW} | docker login -u ${DOCKER_HUB_USR} --password-stdin
                        docker push ${DOCKER_IMAGE}:${VERSION}
                    """
                }
            }
        }

        stage('Deploy to Review') {
            steps {
                script {
                    echo "Deploying to Review server..."
                    bat """
                        echo "${AWS_SSH_KEY}" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${REVIEW_IP} ^
                        "docker pull ${DOCKER_IMAGE}:${VERSION} &&
                        docker stop review-app || true &&
                        docker rm review-app || true &&
                        docker run -d -p 80:80 --name review-app ${DOCKER_IMAGE}:${VERSION}"
                        del aws-key.pem
                    """
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                script {
                    echo "Deploying to Staging server..."
                    bat """
                        echo "${AWS_SSH_KEY}" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${STAGING_IP} ^
                        "docker pull ${DOCKER_IMAGE}:${VERSION} &&
                        docker stop staging-app || true &&
                        docker rm staging-app || true &&
                        docker run -d -p 80:80 --name staging-app ${DOCKER_IMAGE}:${VERSION}"
                        del aws-key.pem
                    """
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    echo "Deploying to Production server..."
                    bat """
                        echo "${AWS_SSH_KEY}" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${PROD_IP} ^
                        "docker pull ${DOCKER_IMAGE}:${VERSION} &&
                        docker stop production-app || true &&
                        docker rm production-app || true &&
                        docker run -d -p 80:80 --restart unless-stopped --name production-app ${DOCKER_IMAGE}:${VERSION}"
                        del aws-key.pem
                    """
                }
            }
        }
    }
}
