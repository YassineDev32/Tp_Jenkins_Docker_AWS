pipeline {
    agent any

    environment {
        SSH_KEY = credentials('aws-key.pem')  // Remplace par l'ID du credential
    }

    stages {
        stage('Connect to AWS EC2') {
            steps {
                script {
                    sh '''
                        echo "$SSH_KEY" > aws-key.pem
                        chmod 400 aws-key.pem
                        ssh -i aws-key.pem -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo Connexion réussie depuis Jenkins !"
                    '''
                }
            }
        }
    }
}
