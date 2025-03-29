pipeline {
    agent any
    
    environment {
        AWS_SSH_KEY = credentials('aws-key.pem')  // Utilisation correcte des credentials
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
                script {
                    powershell '''
                        docker build -t "${env:DOCKER_IMAGE}:${env:VERSION}" .
                    '''
                }
            }
        }

        stage('Test Image') {
            steps {
                script {
                    powershell '''
                        try {
                            # Vérifier si l'image existe localement
                            $imageExists = docker images -q "${env:DOCKER_IMAGE}:${env:VERSION}"
                            if (-not $imageExists) {
                                throw "L'image ${env:DOCKER_IMAGE}:${env:VERSION} n'existe pas localement."
                            }

                            # Lancer le conteneur
                            docker run -d -p 8081:80 --name test-container "${env:DOCKER_IMAGE}:${env:VERSION}"
                            Start-Sleep -s 10
                            
                            # Tester l'application
                            $response = Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing -ErrorAction Stop
                            if ($response.StatusCode -ne 200) { 
                                throw "HTTP Status ${response.StatusCode}" 
                            }
                            Write-Host "Test passed successfully"
                        } catch {
                            Write-Host "Test failed: $_"
                            docker logs test-container
                            exit 1
                        } finally {
                            # Nettoyage du conteneur
                            docker stop test-container -t 1 | Out-Null
                            docker rm test-container -f | Out-Null
                        }
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            environment {
                // This helps Docker use the correct config location
                DOCKER_CONFIG = "${WORKSPACE}/.docker"
            }
            steps {
                script {
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-hub-creds',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        powershell '''
                            # Clean any existing credentials
                            Write-Host "=== Resetting Docker configuration ==="
                            docker logout
                            Remove-Item -Path "$env:DOCKER_CONFIG" -Recurse -Force -ErrorAction SilentlyContinue
                            New-Item -Path "$env:DOCKER_CONFIG" -ItemType Directory -Force | Out-Null
        
                            # Test connectivity to Docker Hub
                            Write-Host "=== Testing Docker Hub connectivity ==="
                            if (-not (Test-NetConnection registry-1.docker.io -Port 443 -InformationLevel Quiet)) {
                                throw "Cannot connect to Docker Hub registry"
                            }
        
                            # Login using username/password
                            Write-Host "=== Authenticating to Docker Hub ==="
                            $securePass = ConvertTo-SecureString $env:DOCKER_PASS -AsPlainText -Force
                            $credential = New-Object System.Management.Automation.PSCredential($env:DOCKER_USER, $securePass)
                            
                            $loginOutput = docker login -u $credential.UserName --password-stdin 2>&1 <<< "$($credential.GetNetworkCredential().Password)"
                            
                            if ($LASTEXITCODE -ne 0) {
                                Write-Host "LOGIN ERROR OUTPUT: $loginOutput"
                                throw "Docker authentication failed"
                            }
                            Write-Host "Successfully logged in to Docker Hub"
        
                            # Push with retries
                            $maxRetries = 3
                            $retryCount = 0
                            do {
                                Write-Host "Pushing image (attempt $($retryCount + 1))..."
                                docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                                
                                if ($LASTEXITCODE -eq 0) {
                                    Write-Host "Image pushed successfully!"
                                    break
                                }
                                
                                $retryCount++
                                if ($retryCount -lt $maxRetries) {
                                    Start-Sleep -Seconds 10
                                }
                            } while ($retryCount -lt $maxRetries)
        
                            if ($retryCount -eq $maxRetries) {
                                throw "Failed to push image after $maxRetries attempts"
                            }
                        '''
                    }
                }
            }
        }

        stage('Deploy to Review') {
            steps {
                script {
                    withCredentials([file(credentialsId: 'aws-key', variable: 'SSH_KEY')]) {
                        powershell '''
                            $tempKey = "$env:TEMP\\aws-key-${env:BUILD_NUMBER}.pem"
                            Set-Content -Path $tempKey -Value $env:SSH_KEY
                            icacls $tempKey /inheritance:r
                            icacls $tempKey /grant:r "$env:USERNAME:R"

                            try {
                                ssh -i $tempKey -o StrictHostKeyChecking=no ubuntu@${env:REVIEW_IP} "
                                    docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                                    docker stop review-app || true
                                    docker rm review-app || true
                                    docker run -d -p 80:80 --name review-app ${env:DOCKER_IMAGE}:${env:VERSION}
                                "
                            } catch {
                                Write-Host "Deployment failed: $_"
                                exit 1
                            } finally {
                                Remove-Item $tempKey -Force -ErrorAction SilentlyContinue
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
    }
}
