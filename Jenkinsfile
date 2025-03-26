pipeline {
    agent any
    stages {
        stage('Test SSH vers AWS EC2') {
            steps {
                sshagent(credentials: ['aws-ec2-deploy-key']) {
                    script {
                        try {
                            // Test basique de connexion
                            bat 'ssh -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo \'Connexion SSH réussie !\'"'
                            
                            // Vérification Docker
                            bat 'ssh ubuntu@VOTRE_IP_EC2 "docker --version"'
                            
                            // Vérification de l\'utilisateur
                            bat 'ssh ubuntu@VOTRE_IP_EC2 "whoami && hostname"'
                            
                            echo "✅ Tous les tests SSH ont réussi"
                        } catch (Exception e) {
                            error "❌ Échec de la connexion SSH : ${e.message}"
                        }
                    }
                }
            }
        }
    }
}