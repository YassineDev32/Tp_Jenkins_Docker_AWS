pipeline {
    agent any

    environment {
        SSH_KEY = credentials('aws-key.pem')  // Replace with your actual credentials ID
    }

    stages {
        stage('Connect to AWS EC2') {
            steps {
                script {
                    // For Unix-based systems (Linux/macOS)
                    if (isUnix()) {
                        sh '''
                            echo "$SSH_KEY" > aws-key.pem
                            chmod 400 aws-key.pem
                            ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo Connexion réussie depuis Jenkins !"
                        '''
                    } 
                    // For Windows systems (PowerShell)
                    else {
                        powershell '''
                            $sshKey = $Env:SSH_KEY
                            $sshKey | Out-File -FilePath aws-key.pem -Encoding ASCII
                            icacls "aws-key.pem" /inheritance:r /grant:r "Everyone:(R)"
                            ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo Connexion réussie depuis Jenkins !"
                        '''
                    }
                }
            }
        }
    }
}
