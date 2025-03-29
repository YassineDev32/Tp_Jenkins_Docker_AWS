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

        stage('Login to Docker Hub') {
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
                            # Clear existing credentials
                            docker logout
                            Remove-Item -Path "$env:USERPROFILE/.docker/config.json" -Force -ErrorAction SilentlyContinue
                            
                            # Create Docker config directory if it doesn't exist
                            $dockerConfigDir = "$env:USERPROFILE/.docker"
                            if (-not (Test-Path $dockerConfigDir)) {
                                New-Item -ItemType Directory -Path $dockerConfigDir -Force | Out-Null
                            }
                            
                            # Create auth token (base64 encoded username:password)
                            $authToken = [Convert]::ToBase64String(
                                [Text.Encoding]::ASCII.GetBytes("${env:DOCKER_USER}:${env:DOCKER_PASS}")
                            )
                            
                            # Create the Docker config file without here-string issues
                            $dockerConfigContent = '{
                                "auths": {
                                    "https://index.docker.io/v1/": {
                                        "auth": "' + $authToken + '"
                                    }
                                }
                            }'
                            
                            $dockerConfigContent | Out-File -FilePath "$dockerConfigDir/config.json" -Encoding ascii
                            
                            # Verify the login works
                            docker pull hello-world
                            if ($LASTEXITCODE -ne 0) {
                                throw "Docker authentication verification failed"
                            }
                            
                            Write-Host "Successfully authenticated with Docker Hub"
                        '''
                    }
                }
            }
        }

        stage('Push to Docker Hub') {
            steps {
                script {
                    powershell '''
                        # Push with retries
                        $maxRetries = 3
                        $retryCount = 0
                        do {
                            docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "Successfully pushed ${env:DOCKER_IMAGE}:${env:VERSION}"
                                break
                            }
                            $retryCount++
                            if ($retryCount -lt $maxRetries) {
                                Start-Sleep -Seconds 10
                                Write-Host "Retrying push ($retryCount/$maxRetries)..."
                            }
                        } while ($retryCount -lt $maxRetries)

                        if ($retryCount -eq $maxRetries) {
                            throw "Failed to push after $maxRetries attempts"
                        }
                    '''
                }
            }
        }

        stage('Test SSH Connection') {
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    script {
                        // 1. Corriger les permissions (Windows)
                        bat """
                            icacls "${SSH_KEY}" /reset
                            icacls "${SSH_KEY}" /grant:r "NT AUTHORITY\\SYSTEM:(R)"
                            icacls "${SSH_KEY}" /grant:r "%USERNAME%:(R)"
                            icacls "${SSH_KEY}" /inheritance:r
                        """
                        
                        // 2. Tester la connexion
                        bat """
                            ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "echo 'Connexion réussie !'"
                            ssh -i "${SSH_KEY}" ubuntu@%REVIEW_IP% "docker --version"
                            ssh -i "${SSH_KEY}" ubuntu@%REVIEW_IP% "whoami && hostname"
                        """
                    }
                }
            }
        }
                
        stage('Deploy to Review') {
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    script {
                        // 1. Prepare the key file with proper permissions
                        powershell '''
                            $tempKey = "$env:TEMP\\aws-key-$env:BUILD_NUMBER.pem"
                            
                            # Copy key content with Unix line endings
                            (Get-Content $env:SSH_KEY -Raw).Replace("`r`n","`n") | Out-File $tempKey -Encoding ascii
                            
                            # Remove inheritance and clear all permissions
                            icacls $tempKey /inheritance:r
                            icacls $tempKey /grant:r "$env:USERNAME:(R)"
                            icacls $tempKey /grant:r "SYSTEM:(R)"
                            
                            # Verify permissions
                            $acl = Get-Acl $tempKey
                            $acl.Access | Format-Table IdentityReference,FileSystemRights,AccessControlType -AutoSize
                        '''
                        
                        // 2. Execute deployment commands
                        bat '''
                            ssh -i "%TEMP%\\aws-key-%BUILD_NUMBER%.pem" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "
                                docker pull %DOCKER_IMAGE%:%VERSION%
                                docker stop review-app || true
                                docker rm review-app || true 
                                docker run -d -p 80:80 --name review-app %DOCKER_IMAGE%:%VERSION%
                            "
                        '''
                        
                        // 3. Clean up
                        bat '''
                            del "%TEMP%\\aws-key-%BUILD_NUMBER%.pem"
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
