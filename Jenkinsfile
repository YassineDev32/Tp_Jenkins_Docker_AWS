pipeline {
    agent any
    stages {
        stage('Test SSH Connection') {
            steps {
                script {
                    sshagent(['aws-ec2-deploy-key']) {
                        sh 'ssh -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo SSH Success!"'
                    }
                }
            }
        }
    }
}
