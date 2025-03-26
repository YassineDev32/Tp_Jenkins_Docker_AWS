pipeline {
    agent any

    stages {
        stage('Test SSH Connection') {
            steps {
                script {
                    try {
                        // Méthode 1: Avec sshagent (si plugin installé)
                        sshagent(['aws-ec2-deploy-key']) {
                            bat 'ssh -vvv -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo \'Méthode sshagent: Connexion réussie\'"'
                        }

                        // Méthode 2: Avec withCredentials (alternative)
                        withCredentials([sshUserPrivateKey(
                            credentialsId: 'aws-ec2-deploy-key',
                            keyFileVariable: 'SSH_KEY'
                        )]) {
                            bat """
                                ssh -vvv -i "%SSH_KEY%" -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo 'Méthode withCredentials: Connexion réussie'"
                            """
                        }

                        // Méthode 3: Commande directe (pour debug)
                        bat 'where ssh'
                        bat 'whoami'
                        bat 'type "%JENKINS_HOME%\\credentials.xml" | find "aws-ec2-deploy-key"'
                    } catch (Exception e) {
                        error "Échec: ${e.message}"
                    }
                }
            }
        }
    }
}
