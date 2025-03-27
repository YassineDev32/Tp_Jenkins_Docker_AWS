pipeline {
    agent any
    environment {
        AWS_EC2_IP = '51.21.180.149'
    }
    stages {
        stage('Test SSH Connection') {
            steps {
                withCredentials([file(credentialsId: 'aws-ssh-key-file', variable: 'SSH_KEY')]) {
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
                            ssh -i "${SSH_KEY}" -o StrictHostKeyChecking=no ubuntu@%AWS_EC2_IP% "echo 'Connexion réussie !'"
                            ssh -i "${SSH_KEY}" ubuntu@%AWS_EC2_IP% "docker --version"
                            ssh -i "${SSH_KEY}" ubuntu@%AWS_EC2_IP% "whoami && hostname"
                        """
                    }
                }
            }
        }
    }
}
