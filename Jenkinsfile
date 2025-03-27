pipeline {
    agent any
    
    environment {
        DOCKER_HUB = credentials('docker-hub-creds')
        AWS_SSH_KEY = credentials('aws-key.pem')
        DOCKER_IMAGE = "yassine112/mon-app-web"
        VERSION = "${env.BUILD_NUMBER ?: 'latest'}"
        REVIEW_IP = "51.21.180.149"  
        STAGING_IP = "51.20.56.9"  
        PROD_IP = "13.60.156.76"  
    }

    stages {
        stage('Verify Environment') {
            steps {
                powershell '''
                    Write-Host "Docker version:"
                    docker --version
                    Write-Host "Git version:"
                    git --version
                '''
            }
        }

        stage('Checkout Code') {
            steps {
                git branch: 'main', 
                     credentialsId: 'github-credentials', 
                     url: 'https://github.com/YassineDev32/Tp_Jenkins_Docker_AWS.git'
            }
        }

        stage('Build Docker Image') {
            steps {
                powershell '''
                    Write-Host "Building image ${env:DOCKER_IMAGE}:${env:VERSION}"
                    docker build -t "${env:DOCKER_IMAGE}:${env:VERSION}" .
                    if ($LASTEXITCODE -ne 0) { exit 1 }
                '''
            }
        }

        stage('Test Image') {
            steps {
                script {
                    powershell '''
                        try {
                            docker run -d -p 8080:80 --name test-container "${env:DOCKER_IMAGE}:${env:VERSION}"
                            Start-Sleep -s 10
                            $response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -ErrorAction Stop
                            if ($response.StatusCode -ne 200) { throw "HTTP Status ${response.StatusCode}" }
                            Write-Host "Test passed successfully"
                        } catch {
                            Write-Host "Test failed: $_"
                            exit 1
                        } finally {
                            docker stop test-container -t 1 || $null
                            docker rm test-container -f || $null
                        }
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                powershell '''
                    try {
                        $securePass = ConvertTo-SecureString "${env:DOCKER_HUB_PSW}" -AsPlainText -Force
                        $cred = New-Object System.Management.Automation.PSCredential("${env:DOCKER_HUB_USR}", $securePass)
                        docker login -u "${env:DOCKER_HUB_USR}" --password-stdin <<< "${env:DOCKER_HUB_PSW}"
                        docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                    } catch {
                        Write-Host "Failed to push image: $_"
                        exit 1
                    }
                '''
            }
        }

        stage('Deploy to Review') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                        powershell '''
                            $tempKey = "aws-key-${env:BUILD_NUMBER}.pem"
                            Copy-Item "${env:SSH_KEY}" -Destination $tempKey
                            icacls $tempKey /reset
                            icacls $tempKey /grant:r "${env:USERNAME}:(R)"
                            icacls $tempKey /inheritance:r

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

        stage('Deploy to Staging') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                        powershell '''
                            $tempKey = "aws-key-${env:BUILD_NUMBER}.pem"
                            Copy-Item "${env:SSH_KEY}" -Destination $tempKey
                            icacls $tempKey /reset
                            icacls $tempKey /grant:r "${env:USERNAME}:(R)"
                            icacls $tempKey /inheritance:r

                            try {
                                ssh -i $tempKey -o StrictHostKeyChecking=no ubuntu@${env:STAGING_IP} "
                                    docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                                    docker stop staging-app || true
                                    docker rm staging-app || true
                                    docker run -d -p 80:80 --name staging-app ${env:DOCKER_IMAGE}:${env:VERSION}
                                "
                            } finally {
                                Remove-Item $tempKey -Force
                            }
                        '''
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'main'
            }
            steps {
                script {
                    withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                        powershell '''
                            $tempKey = "aws-key-${env:BUILD_NUMBER}.pem"
                            Copy-Item "${env:SSH_KEY}" -Destination $tempKey
                            icacls $tempKey /reset
                            icacls $tempKey /grant:r "${env:USERNAME}:(R)"
                            icacls $tempKey /inheritance:r

                            try {
                                ssh -i $tempKey -o StrictHostKeyChecking=no ubuntu@${env:PROD_IP} "
                                    docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                                    docker stop production-app || true
                                    docker rm production-app || true
                                    docker run -d -p 80:80 --restart unless-stopped --name production-app ${env:DOCKER_IMAGE}:${env:VERSION}
                                "
                            } finally {
                                Remove-Item $tempKey -Force
                            }
                        '''
                    }
                }
            }
        }
    }

    post {
        always {
            cleanWs()
        }
        success {
            mail to: 'your-email@example.com',
                 subject: "SUCCESS: Pipeline ${currentBuild.displayName}",
                 body: "Build ${currentBuild.url} completed successfully"
        }
        failure {
            mail to: 'your-email@example.com',
                 subject: "FAILED: Pipeline ${currentBuild.displayName}",
                 body: "Build ${currentBuild.url} failed. See logs for details."
        }
    }
}
