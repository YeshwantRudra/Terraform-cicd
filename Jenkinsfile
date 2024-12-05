pipeline {
    agent { label 'Terraform-agent' }
    tools {
    terraform 'terraform'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main', credentialsId: 'Git-cred', url: 'https://github.com/YeshwantRudra/Terraform-cicd.git'
            }
        }
        stage('Terraform init'){
            steps {
                sh 'terraform init'
            }
        }
        stage('Terraform plan'){
            steps {
                sh 'terraform plan'
            }
        }
        stage('Terraform apply'){
            steps {
                sh 'terraform apply -auto-approve'
            }
        }
    }
    
    post {
            success {
                emailext attachLog: true, body: 'Email sen from Jenkins', subject: 'Test Email - Success', to: 'rudrayeshwant1411@gmail.com'
        }
            failure {
                emailext attachLog: true, body: 'Email sen from Jenkins', subject: 'Test Email - Failure', to: 'rudrayeshwant1411@gmail.com'
            }
    }
}

