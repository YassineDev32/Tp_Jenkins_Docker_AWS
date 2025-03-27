pipeline {
    agent any
    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'aws-ec2-deploy-key',
                    url: 'git@github.com:YassineDev32/Tp_Jenkins_Docker_AWS.git'
            }
        }
        
        stage('Test SSH Connection') {
            steps {
                sh 'ssh -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo Connection Successful"'
            }
        }
    }
}
