pipeline {
    agent any
    stages {
        stage('Test SSH vers AWS EC2') {
            steps {
                sshagent(credentials: ['aws-ec2-deploy-key']) {
                    script {
                        // Test de base
                        bat 'ssh -vvv -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo \'CONNEXION SSH VALIDÉE\'"'
                        
                        // Vérification Docker (avec timeout)
                        bat 'ssh -o ConnectTimeout=10 ubuntu@51.21.180.149 "docker --version || echo \'Docker non installé\'"'
                        
                        // Vérification système
                        bat 'ssh ubuntu@51.21.180.149 "whoami && hostname && df -h"'
                    }
                }
            }
        }
    }
}
