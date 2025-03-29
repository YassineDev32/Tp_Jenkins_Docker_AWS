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
                    script {
                        // Create properly formatted key file
                        powershell """
                            \$keyContent = [IO.File]::ReadAllText('${SSH_KEY}').Replace("`r`n","`n")
                            [IO.File]::WriteAllText("\${env:TEMP}\\review-key.pem", \$keyContent)
                        """
                        
                        // Set permissions using PowerShell (more reliable than icacls)
                        powershell '''
                            $keyPath = "$env:TEMP\\review-key.pem"
                            $acl = Get-Acl $keyPath
                            $acl.SetAccessRuleProtection($true, $false)
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                                "$env:USERNAME",
                                "Read",
                                "Allow"
                            )
                            $acl.SetAccessRule($rule)
                            Set-Acl $keyPath $acl
                        '''
                        
                        // Execute deployment commands
                        bat """
                            ssh -i "%TEMP%\\review-key.pem" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "docker pull %DOCKER_IMAGE%:%VERSION%"
                            ssh -i "%TEMP%\\review-key.pem" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "docker stop review-app 2> nul || echo No container to stop"
                            ssh -i "%TEMP%\\review-key.pem" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "docker rm review-app 2> nul || echo No container to remove"
                            ssh -i "%TEMP%\\review-key.pem" -o StrictHostKeyChecking=no ubuntu@%REVIEW_IP% "docker run -d -p 80:80 --name review-app %DOCKER_IMAGE%:%VERSION%"
                        """
                        
                        // Clean up
                        bat """
                            del "%TEMP%\\review-key.pem"
                        """
                    }
                }
            }
        }

        stage('Deploy to Staging') {
            when { expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') } }
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    script {
                        powershell """
                            $keyContent = [IO.File]::ReadAllText('${SSH_KEY}').Replace("`r`n","`n")
                            [IO.File]::WriteAllText("${env:TEMP}\\staging-key.pem", $keyContent)
                            $keyPath = "${env:TEMP}\\staging-key.pem"
                            $acl = Get-Acl $keyPath
                            $acl.SetAccessRuleProtection($true, $false)
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                                "${env:USERNAME}",
                                "Read",
                                "Allow"
                            )
                            $acl.SetAccessRule($rule)
                            Set-Acl $keyPath $acl
                        """
                        
                        bat """
                            ssh -i "%TEMP%\\staging-key.pem" -o StrictHostKeyChecking=no ubuntu@%STAGING_IP% "docker pull %DOCKER_IMAGE%:%VERSION%"
                            ssh -i "%TEMP%\\staging-key.pem" -o StrictHostKeyChecking=no ubuntu@%STAGING_IP% "docker stop staging-app 2> nul || echo No container to stop"
                            ssh -i "%TEMP%\\staging-key.pem" -o StrictHostKeyChecking=no ubuntu@%STAGING_IP% "docker rm staging-app 2> nul || echo No container to remove"
                            ssh -i "%TEMP%\\staging-key.pem" -o StrictHostKeyChecking=no ubuntu@%STAGING_IP% "docker run -d -p 80:80 --name staging-app %DOCKER_IMAGE%:%VERSION%"
                            del "%TEMP%\\staging-key.pem"
                        """
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when { expression { currentBuild.resultIsBetterOrEqualTo('SUCCESS') } }
            steps {
                withCredentials([file(credentialsId: 'aws-key.pem', variable: 'SSH_KEY')]) {
                    script {
                        powershell """
                            $keyContent = [IO.File]::ReadAllText('${SSH_KEY}').Replace("`r`n","`n")
                            [IO.File]::WriteAllText("${env:TEMP}\\production-key.pem", $keyContent)
                            $keyPath = "${env:TEMP}\\production-key.pem"
                            $acl = Get-Acl $keyPath
                            $acl.SetAccessRuleProtection($true, $false)
                            $rule = New-Object System.Security.AccessControl.FileSystemAccessRule(
                                "${env:USERNAME}",
                                "Read",
                                "Allow"
                            )
                            $acl.SetAccessRule($rule)
                            Set-Acl $keyPath $acl
                        """
                        
                        bat """
                            ssh -i "%TEMP%\\production-key.pem" -o StrictHostKeyChecking=no ubuntu@%PROD_IP% "docker pull %DOCKER_IMAGE%:%VERSION%"
                            ssh -i "%TEMP%\\production-key.pem" -o StrictHostKeyChecking=no ubuntu@%PROD_IP% "docker stop production-app 2> nul || echo No container to stop"
                            ssh -i "%TEMP%\\production-key.pem" -o StrictHostKeyChecking=no ubuntu@%PROD_IP% "docker rm production-app 2> nul || echo No container to remove"
                            ssh -i "%TEMP%\\production-key.pem" -o StrictHostKeyChecking=no ubuntu@%PROD_IP% "docker run -d -p 80:80 --name production-app %DOCKER_IMAGE%:%VERSION%"
                            del "%TEMP%\\production-key.pem"
                        """
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
