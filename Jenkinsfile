pipeline {
    agent any

    stages {
        stage('Connect to AWS EC2') {
            steps {
                script {
                    sshagent(['aws-ec2-deploy-key']) {
                        sh 'ssh -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo Connexion réussie depuis Jenkins !"'
                    }
                }
            }
        }
    }
}
