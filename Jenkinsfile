pipeline {
    agent any
    stages {
        stage('Test SSH Connection') {
            steps {
                script {
                    sh 'ssh -i "C:/Users/Yassine_Saiiiiid/.ssh/aws-key.pem" -o StrictHostKeyChecking=no ubuntu@51.21.180.149 "echo SSH Success!"'
                }
            }
        }
    }
}
