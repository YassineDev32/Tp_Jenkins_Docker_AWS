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
                            exit 1
                        } finally {
                            # Nettoyage en syntaxe PowerShell correcte
                            try { docker stop test-container -t 1 } catch { Write-Host "Stop container failed: $_" }
                            try { docker rm test-container -f } catch { Write-Host "Remove container failed: $_" }
                        }
                    '''
                }
            }
        }

       stage('Push to Docker Hub') {
            environment {
                DOCKER_TOKEN = credentials('docker-hub-token')
            }
            steps {
                powershell '''
                    # Test de connexion préalable
                    $canConnect = Test-NetConnection -ComputerName auth.docker.io -Port 443 -WarningAction SilentlyContinue
                    if (-not $canConnect.TcpTestSucceeded) {
                        throw "Impossible de se connecter à auth.docker.io:443"
                    }
        
                    # Authentification avec timeout
                    $dockerUser = "yassine112"
                    $maxRetries = 3
                    $retryCount = 0
                    $authenticated = $false
        
                    while ($retryCount -lt $maxRetries -and -not $authenticated) {
                        try {
                            echo ${env:DOCKER_TOKEN} | docker login -u $dockerUser --password-stdin
                            if ($LASTEXITCODE -eq 0) {
                                $authenticated = $true
                                break
                            }
                        } catch {
                            Write-Host "Tentative $($retryCount + 1)/$maxRetries échouée"
                            Start-Sleep -Seconds 5
                        }
                        $retryCount++
                    }
        
                    if (-not $authenticated) {
                        throw "Échec d'authentification après $maxRetries tentatives"
                    }
        
                    # Push de l'image
                    docker push "${env:DOCKER_IMAGE}:${env:VERSION}"
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
                                    docker stop review-app 2>&1 | Out-Null
                                    docker rm review-app 2>&1 | Out-Null
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

        // Les autres étapes de déploiement (Staging/Production) suivent le même modèle
    }

    post {
        always {
            cleanWs()
        }
    }
}
