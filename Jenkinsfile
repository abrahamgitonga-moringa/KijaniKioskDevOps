pipeline {
    agent any

    environment {
        NODE_ENV  = 'test'
        BUILD_DIR = 'dist'
        APP_NAME  = 'kijanikiosk-payments'
    }

    options {
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    stages {
        stage('Build') {
            steps {
                echo "Preparing build environment for ${APP_NAME}..."
                sh '''
                    set -e
                    chmod +x *.sh || true
                    if [ -f "./pipeline.sh" ]; then
                        echo "Executing pipeline.sh build step..."
                        ./pipeline.sh build || bash pipeline.sh
                    else
                        echo "pipeline.sh not found in root directory, checking files..."
                        ls -la
                    fi
                '''
            }
        }
        stage('Test') {
            steps {
                echo "Test stage: TODO"
            }
        }
        stage('Archive') {
            steps {
                echo "Archive stage: TODO"
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded: ${APP_NAME} build ${BUILD_NUMBER}"
        }
        failure {
            echo "Pipeline FAILED: ${APP_NAME} build ${BUILD_NUMBER} - check logs"
        }
        always {
            echo "Build URL: ${BUILD_URL}"
            cleanWs()
        }
    }
}
