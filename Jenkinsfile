pipeline {
    agent any
    environment {
        DOCKER_HUB = credentials('docker-hub-creds')
        AWS_SSH_KEY = credentials('aws-key.pem')
        DOCKER_IMAGE = "yassine112/mon-app-web"
        VERSION = "${env.BUILD_NUMBER}"
        REVIEW_IP = "51.21.180.149"  // IP EC2 Review
        STAGING_IP = "51.20.56.9" // IP EC2 Staging
        PROD_IP = "13.60.156.76"    // IP EC2 Production
    }
    
    stages {
        // CI - Intégration Continue
        stage('Build Docker Image') {
            steps {
                git url: 'https://github.com/YassineDev32/Tp_Jenkins_Docker_AWS.git'
                bat 'docker build -t ${DOCKER_IMAGE}:${VERSION} -f Dockerfile .'
            }
        }
        
        stage('Test Image') {
            steps {
                script {
                    bat 'docker run -d -p 8080:80 --name test-container ${DOCKER_IMAGE}:${VERSION}'
                    bat 'timeout /t 10 /nobreak'
                    bat 'curl -I http://localhost:8080 || exit 1'
                    bat 'docker stop test-container && docker rm test-container'
                }
            }
        }
        
        stage('Push to Docker Hub') {
            steps {
                bat """
                    echo ${DOCKER_HUB_PSW} | docker login -u ${DOCKER_HUB_USR} --password-stdin
                    docker push ${DOCKER_IMAGE}:${VERSION}
                """
            }
        }
        
        // CD - Déploiement Continu
        stage('Deploy to Review') {
            steps {
                sshagent(['aws-ssh-key']) {
                    bat """
                        ssh -o StrictHostKeyChecking=no ubuntu@${REVIEW_IP} "
                            docker pull ${DOCKER_IMAGE}:${VERSION}
                            docker stop review-app || true
                            docker rm review-app || true
                            docker run -d -p 80:80 --name review-app ${DOCKER_IMAGE}:${VERSION}
                        "
                    """
                }
            }
        }
        
        stage('Deploy to Staging') {
            steps {
                sshagent(['aws-ssh-key']) {
                    bat """
                        ssh -o StrictHostKeyChecking=no ubuntu@${STAGING_IP} "
                            docker pull ${DOCKER_IMAGE}:${VERSION}
                            docker stop staging-app || true
                            docker rm staging-app || true
                            docker run -d -p 80:80 --name staging-app ${DOCKER_IMAGE}:${VERSION}
                        "
                    """
                }
            }
        }
        
        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                sshagent(['aws-ssh-key']) {
                    bat """
                        ssh -o StrictHostKeyChecking=no ubuntu@${PROD_IP} "
                            docker pull ${DOCKER_IMAGE}:${VERSION}
                            docker stop production-app || true
                            docker rm production-app || true
                            docker run -d -p 80:80 --restart unless-stopped --name production-app ${DOCKER_IMAGE}:${VERSION}
                        "
                    """
                }
            }
        }
    }
}
