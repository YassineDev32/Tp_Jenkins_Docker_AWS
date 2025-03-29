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
                            # Verify image exists locally
                            $imageExists = docker images -q "${env:DOCKER_IMAGE}:${env:VERSION}"
                            if (-not $imageExists) {
                                throw "Image ${env:DOCKER_IMAGE}:${env:VERSION} doesn't exist locally"
                            }

                            # Run container
                            docker run -d -p 8081:80 --name test-container "${env:DOCKER_IMAGE}:${env:VERSION}"
                            Start-Sleep -Seconds 10
                            
                            # Test application
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
                            # Cleanup container
                            docker stop test-container -t 1 | Out-Null
                            docker rm test-container -f | Out-Null
                        }
                    '''
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    // First verify Docker Hub connectivity
                    powershell '''
                        Write-Host "=== Network Pre-Check ==="
                        $dns = Resolve-DnsName registry-1.docker.io -ErrorAction SilentlyContinue
                        if (-not $dns) { throw "DNS resolution failed" }
                        Write-Host "DNS resolved to: $($dns.IPAddress)"
                        
                        $tcp = Test-NetConnection registry-1.docker.io -Port 443 -InformationLevel Quiet
                        if (-not $tcp) { throw "TCP connection failed" }
                        Write-Host "TCP connection successful"
                    '''
                    
                    // Use direct credential injection (most reliable method)
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-hub-creds',
                            usernameVariable: 'DOCKERHUB_USER',
                            passwordVariable: 'DOCKERHUB_PASS'
                        )
                    ]) {
                        powershell '''
                            # Complete Docker config reset
                            docker logout
                            Remove-Item -Path "$env:USERPROFILE/.docker/config.json" -Force -ErrorAction SilentlyContinue
                            
                            # Manual credential injection (bypasses all Jenkins masking issues)
                            $auth = [Convert]::ToBase64String(
                                [Text.Encoding]::ASCII.GetBytes("${env:DOCKERHUB_USER}:${env:DOCKERHUB_PASS}")
                            )
                            
                            # Create Docker config manually
                            $config = @"
                            {
                                "auths": {
                                    "https://index.docker.io/v1/": {
                                        "auth": "$auth"
                                    }
                                }
                            }
        "@
                            $configPath = "$env:USERPROFILE/.docker/config.json"
                            New-Item -Path (Split-Path $configPath) -ItemType Directory -Force | Out-Null
                            $config | Out-File -FilePath $configPath -Encoding ascii
                            
                            # Verify authentication
                            docker pull hello-world
                            if ($LASTEXITCODE -ne 0) {
                                throw "Docker authentication verification failed"
                            }
                            
                            # Push with retries
                            $maxRetries = 3
                            for ($i=1; $i -le $maxRetries; $i++) {
                                Write-Host "Push attempt $i/$maxRetries"
                                docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                                if ($LASTEXITCODE -eq 0) { 
                                    Write-Host "Push successful!" 
                                    break 
                                }
                                if ($i -lt $maxRetries) { Start-Sleep -Seconds 10 }
                            }
                            if ($LASTEXITCODE -ne 0) { throw "Failed after $maxRetries attempts" }
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
                            # Fix: Use forward slashes or double backslashes for Windows paths
                            $tempKey = "$env:TEMP/aws-key-${env:BUILD_NUMBER}.pem"
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
