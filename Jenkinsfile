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
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'docker-hub-creds',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        powershell '''
                            # 1. Comprehensive network diagnostics
                            Write-Host "=== Network Diagnostics ==="
                            Write-Host "Testing DNS resolution..."
                            $dnsTest = Resolve-DnsName registry-1.docker.io -ErrorAction SilentlyContinue
                            if (-not $dnsTest) {
                                throw "DNS ERROR: Cannot resolve registry-1.docker.io"
                            }
                            Write-Host "DNS resolved to: $($dnsTest.IPAddress)"
        
                            Write-Host "Testing TCP connectivity..."
                            $tcpTest = Test-NetConnection registry-1.docker.io -Port 443 -InformationLevel Detailed
                            if (-not $tcpTest.TcpTestSucceeded) {
                                throw "NETWORK ERROR: Cannot connect to registry-1.docker.io:443"
                            }
                            Write-Host "Connection successful"
        
                            # 2. Verify credentials format
                            Write-Host "=== Credential Verification ==="
                            Write-Host "Username length: $($env:DOCKER_USER.Length)"
                            Write-Host "Password length: $($env:DOCKER_PASS.Length)"
                            
                            # 3. Alternative authentication method
                            Write-Host "=== Trying Alternative Authentication ==="
                            try {
                                $tempCredFile = "$env:TEMP/docker-creds-$(Get-Random).txt"
                                "https://$($env:DOCKER_USER):$($env:DOCKER_PASS)@registry-1.docker.io" | Out-File $tempCredFile -Encoding ASCII
                                
                                Get-Content $tempCredFile | docker login --username $env:DOCKER_USER --password-stdin
                                
                                if ($LASTEXITCODE -ne 0) {
                                    # Try with raw echo if file method fails
                                    Write-Host "Trying direct echo method..."
                                    $env:DOCKER_PASS | docker login -u $env:DOCKER_USER --password-stdin
                                }
        
                                if ($LASTEXITCODE -ne 0) {
                                    throw "FINAL ERROR: All authentication methods failed"
                                }
        
                                # 4. Push with retries
                                $maxRetries = 3
                                for ($i = 1; $i -le $maxRetries; $i++) {
                                    Write-Host "Push attempt $i/$maxRetries"
                                    docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                                    
                                    if ($LASTEXITCODE -eq 0) {
                                        Write-Host "SUCCESS: Image pushed to Docker Hub"
                                        break
                                    }
                                    
                                    if ($i -lt $maxRetries) {
                                        Start-Sleep -Seconds 10
                                    }
                                }
                            }
                            finally {
                                if (Test-Path $tempCredFile) {
                                    Remove-Item $tempCredFile -Force
                                }
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
