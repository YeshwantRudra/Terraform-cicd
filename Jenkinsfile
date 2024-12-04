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
        stage('Sonar Analysis') {
            steps {
                withSonarQubeEnv('sonar') {
                    sh ''' $SCANNER_HOME/bin/sonar-scanner -Dsonar.projectName=Terraform-cicd \
                    -Dsonar.sources=. \
                    -Dsonar.projectKey=Terraform-cicd '''
                }
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
    post {
        always {
            emaiext (
                subject: 'Pipeline Status: ${BUILD_NUMBER}',
                body: '''<html>
                            <body>
                                <p>Build Status: ${BUILD_STATUS}</p>
                                <p>Build Number: ${BUILD_NUMBER}</p>
                                <p>Check the <a href ='${BUILD_URL}'>console output</a>.</p>
                            </body>
                        </html>''',
                to: 'rudrayeshwant1411@gmai.com',
                from: 'jenkins@demo.com',
                replyTo: 'jenkins@demo.com',
                mimeType: 'text/html'
            )
        }
    }
}

