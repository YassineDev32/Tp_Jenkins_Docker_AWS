pipeline {
    agent any
    
    environment {
        DOCKER_HUB = credentials('docker-hub-creds')
        AWS_SSH_KEY = credentials('aws-key.pem')
        DOCKER_IMAGE = "yassine112/mon-app-web"
        VERSION = "${env.BUILD_NUMBER}"
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
                powershell 'docker build -t ${env.DOCKER_IMAGE}:${env.VERSION} .'
            }
        }

        stage('Test Image') {
            steps {
                script {
                    powershell '''
                        docker run -d -p 8080:80 --name test-container ${env.DOCKER_IMAGE}:${env.VERSION}
                        Start-Sleep -s 10
                        try {
                            Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing
                        } catch {
                            Write-Host "Test failed, exiting..."
                            exit 1
                        }
                        docker stop test-container
                        docker rm test-container
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                powershell '''
                    echo ${DOCKER_HUB_PSW} | docker login -u ${DOCKER_HUB_USR} --password-stdin
                    docker push ${env.DOCKER_IMAGE}:${env.VERSION}
                '''
            }
        }

        stage('Deploy to Review') {
            steps {
                script {
                    powershell '''
                        echo "$AWS_SSH_KEY" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${env.REVIEW_IP} << EOF
                            docker pull ${env.DOCKER_IMAGE}:${env.VERSION}
                            docker stop review-app || true
                            docker rm review-app || true
                            docker run -d -p 80:80 --name review-app ${env.DOCKER_IMAGE}:${env.VERSION}
                        EOF
                        rm -f aws-key.pem
                    '''
                }
            }
        }

        stage('Deploy to Staging') {
            steps {
                script {
                    powershell '''
                        echo "$AWS_SSH_KEY" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${env.STAGING_IP} << EOF
                            docker pull ${env.DOCKER_IMAGE}:${env.VERSION}
                            docker stop staging-app || true
                            docker rm staging-app || true
                            docker run -d -p 80:80 --name staging-app ${env.DOCKER_IMAGE}:${env.VERSION}
                        EOF
                        rm -f aws-key.pem
                    '''
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    powershell '''
                        echo "$AWS_SSH_KEY" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@${env.PROD_IP} << EOF
                            docker pull ${env.DOCKER_IMAGE}:${env.VERSION}
                            docker stop production-app || true
                            docker rm production-app || true
                            docker run -d -p 80:80 --restart unless-stopped --name production-app ${env.DOCKER_IMAGE}:${env.VERSION}
                        EOF
                        rm -f aws-key.pem
                    '''
                }
            }
        }
    }
}
