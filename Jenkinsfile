pipeline {
    agent any
    
    environment {
        AWS_SSH_KEY = credentials('aws-key.pem')
        DOCKER_IMAGE = "yassine112/mon-app-web"
        VERSION = "${env.BUILD_NUMBER ?: 'latest'}"
        REVIEW_IP = "51.21.180.149"
        STAGING_IP = "51.20.56.9" 
        PROD_IP = "13.60.156.76"
    }
    
    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-credentials',
                    url: 'https://github.com/YassineDev32/Tp_Jenkins_Docker_AWS.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                powershell 'docker build -t "${env:DOCKER_IMAGE}:${env:VERSION}" .'
            }
        }

        stage('Test Image') {
            steps {
                powershell '''
                    try {
                        docker run -d -p 8081:80 --name test-container "${env:DOCKER_IMAGE}:${env:VERSION}"
                        Start-Sleep -Seconds 10
                        $response = Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing
                        if ($response.StatusCode -ne 200) { throw "Test failed" }
                        Write-Host "Test passed"
                    } finally {
                        docker stop test-container
                        docker rm test-container
                    }
                '''
            }
        }

        stage('Login to Docker Hub') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'docker-hub-creds',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    powershell '''
                        $auth = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${env:DOCKER_USER}:${env:DOCKER_PASS}"))
                        @{"auths"=@{"https://index.docker.io/v1/"=@{"auth"="$auth"}}} | ConvertTo-Json | Out-File "$env:USERPROFILE/.docker/config.json"
                        docker pull hello-world || throw "Login verification failed"
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                powershell '''
                    docker push "${env:DOCKER_IMAGE}:${env:VERSION}" || {
                        Write-Host "Push failed, retrying..."
                        Start-Sleep -Seconds 5
                        docker push "${env:DOCKER_IMAGE}:${env:VERSION}" || throw "Push failed after retry"
                    }
                '''
            }
        }

        stage('Deploy to Review') {
            steps {
                withCredentials([file(credentialsId: 'aws-key', variable: 'SSH_KEY')]) {
                    powershell '''
                        $tempKey = "$env:TEMP/aws-key.pem"
                        $env:SSH_KEY | Out-File $tempKey
                        icacls $tempKey /inheritance:r /grant:r "$env:USERNAME:R"
                        
                        try {
                            ssh -i $tempKey -o StrictHostKeyChecking=no ubuntu@${env:REVIEW_IP} "
                                docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                                docker stop review-app || true
                                docker rm review-app || true
                                docker run -d -p 80:80 --name review-app ${env:DOCKER_IMAGE}:${env:VERSION}
                            "
                        } finally {
                            Remove-Item $tempKey -Force
                        }
                    '''
                }
            }
        }
    }
    
    post {
        always {
            cleanWs()
        }
    }
}
