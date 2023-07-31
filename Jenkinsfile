pipeline {
    agent any
  parameters {
    string(name: 'STACK_NAME', defaultValue: 'network-stack', description: 'Enter the CloudFormation Stack Name.')
    string(name: 'TEMPLATE_NAME', defaultValue: 'network.yaml', description: 'Enter the CloudFormation Template Name.')
    string(name: 'PARAMETERS_FILE_NAME', defaultValue: 'input-network.json', description: 'Enter the Parameters File Name')
    choice(name: 'DEPLOY_ENV', choices: ['Staging','Prod','PROD'], description: 'The target environment' )
    choice(name: 'REGION', choices: ['ap-south-1 ','ap-south-2','us-east-1'],description: 'AWS Account Region')    
    }
    stages {
        stage('Clean Workspace'){
            steps {
                echo "cleaning Workspace"
                cleanWs()
            }
            }
        stage ('Git Checkout') {
            steps {
                script {
                  checkout scm
                }
                }}
        stage ('Switch to target branch') {
            steps {
                echo "Switching to branch: master"
                sh 'git checkout master'
                sh 'git pull'
            }   }  
        stage ('Slave Info') {
            steps {
                echo "Slave node Info"
                sh 'whoami'
                sh 'hostname'
                sh 'df -h'
                sh 'aws --version'
                sh 'aws sts get-caller-identity'
            }
        }    

        stage ('CloudFormation Stack Deployment') {
            steps {
                script {
                    echo "Which Environment"
                    echo "${DEPLOY_ENV}"
                    sh 'chmod a+x deploy.sh'
                    sh './deploy.sh ${STACK_NAME}-${DEPLOY_ENV} ${REGION} ${TEMPLATE_NAME} ${PARAMETERS_FILE_NAME}'
                    }   
            }
                    }
                }
post {
    always {
        mail to: 'manoj.m@axcess.io',
             subject: "Jenkins Infra Deployment Notification: ${currentBuild.fullDisplayName}",
             body: "Build Result:- ${currentBuild.currentResult}: More details for the build are at ${BUILD_URL}"

    }     
  }   
}