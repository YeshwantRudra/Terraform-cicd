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
                sh 'terraform apply --auto approve'
            }
        }
    }
}
