pipeline {
    agent any
    
    environment {
        SSH_KEY = credentials('aws-ec2-deploy-key')
    }

    stages {
        stage('Test SSH Connection') {
            steps {
                script {
                    try {
                        // Méthode directe avec fichier de clé
                        bat """
                            set SSH_CMD=ssh -i "C:\Users\Yassine_Saiiiiid\.ssh\id_rsa" -o StrictHostKeyChecking=no ubuntu@51.21.180.149
                            %SSH_CMD% "echo 'Connexion SSH réussie !'"
                            %SSH_CMD% "docker --version"
                            %SSH_CMD% "whoami && hostname"
                        """
                        echo "✅ Tous les tests SSH ont réussi"
                    } catch (Exception e) {
                        error "❌ Échec de la connexion SSH : ${e.message}"
                    }
                }
            }
        }
    }
}
