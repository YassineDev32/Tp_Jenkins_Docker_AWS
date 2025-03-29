pipeline {
    agent any
    
    environment {
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
                        $imageExists = docker images -q "${env:DOCKER_IMAGE}:${env:VERSION}"
                        if (-not $imageExists) { throw "Image not found" }

                        docker run -d -p 8081:80 --name test-container "${env:DOCKER_IMAGE}:${env:VERSION}"
                        Start-Sleep -Seconds 10
                        
                        $response = Invoke-WebRequest -Uri "http://localhost:8081" -UseBasicParsing -ErrorAction Stop
                        if ($response.StatusCode -ne 200) { throw "HTTP ${response.StatusCode}" }
                        Write-Host "Test passed"
                    } catch {
                        Write-Host "Test failed: $_"
                        docker logs test-container
                        exit 1
                    } finally {
                        docker stop test-container -t 1 | Out-Null
                        docker rm test-container -f | Out-Null
                    }
                '''
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
                powershell '''
                    $maxRetries = 3
                    $retryCount = 0
                    do {
                        docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
                        if ($LASTEXITCODE -eq 0) { break }
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

        stage('Deploy to Review') {
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    powershell '''
                        # Create temporary key file
                        $keyFile = "$env:TEMP\\review-key.pem"
                        [IO.File]::WriteAllText($keyFile, $env:SSH_KEY.Replace("`r`n","`n"))
                        
                        # Deploy commands
                        ssh -i $keyFile -o StrictHostKeyChecking=no ubuntu@${env:REVIEW_IP} "
                            docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                            docker stop review-app || true
                            docker rm review-app || true
                            docker run -d -p 80:80 --name review-app ${env:DOCKER_IMAGE}:${env:VERSION}
                        "
                        
                        # Cleanup
                        Remove-Item $keyFile -Force
                        Write-Host "Successfully deployed to Review"
                    '''
                }
            }
        }

        stage('Deploy to Staging') {
            when { expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') } }
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    powershell '''
                        $keyFile = "$env:TEMP\\staging-key.pem"
                        [IO.File]::WriteAllText($keyFile, $env:SSH_KEY.Replace("`r`n","`n"))
                        
                        ssh -i $keyFile -o StrictHostKeyChecking=no ubuntu@${env:STAGING_IP} "
                            docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                            docker stop staging-app || true
                            docker rm staging-app || true
                            docker run -d -p 80:80 --name staging-app ${env:DOCKER_IMAGE}:${env:VERSION}
                        "
                        
                        Remove-Item $keyFile -Force
                        Write-Host "Successfully deployed to Staging"
                    '''
                }
            }
        }

        stage('Deploy to Production') {
            when { expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') } }
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    powershell '''
                        $keyFile = "$env:TEMP\\production-key.pem"
                        [IO.File]::WriteAllText($keyFile, $env:SSH_KEY.Replace("`r`n","`n"))
                        
                        ssh -i $keyFile -o StrictHostKeyChecking=no ubuntu@${env:PROD_IP} "
                            docker pull ${env:DOCKER_IMAGE}:${env:VERSION}
                            docker stop production-app || true
                            docker rm production-app || true
                            docker run -d -p 80:80 --name production-app ${env:DOCKER_IMAGE}:${env:VERSION}
                        "
                        
                        Remove-Item $keyFile -Force
                        Write-Host "Successfully deployed to Production"
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
