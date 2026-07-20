pipeline {
    agent any

    tools {
        nodejs 'node'
    }

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
                echo "Installing dependencies for ${APP_NAME}..."
                sh 'npm ci'

                echo "Building application..."
                sh 'npm run build'

                echo "Verifying build output directory..."
                sh '''
                    set -e
                    test -d "${BUILD_DIR}" || { echo "ERROR: build directory ${BUILD_DIR} not found"; exit 1; }
                    echo "Build output verified: $(ls ${BUILD_DIR} | wc -l) file(s) in ${BUILD_DIR}/"
                '''
            }
        }

        stage('Test') {
            steps {
                echo "Running test suite for ${APP_NAME}..."
                sh '''
                    set -e
                    npm test
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true,
                          testResults: 'test-results/*.xml'
                }
            }
        }

        stage('Archive') {
            steps {
                echo "Archiving build artifact for ${APP_NAME} build ${BUILD_NUMBER}..."
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
                echo "Artifact archived. Access at: ${BUILD_URL}artifact/"
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded: ${APP_NAME} build ${BUILD_NUMBER}"
            echo "Artifact URL: ${BUILD_URL}artifact/"
        }
        failure {
            echo "Pipeline FAILED: ${APP_NAME} build ${BUILD_NUMBER} - check console logs"
        }
        always {
            cleanWs()
        }
    }
}
