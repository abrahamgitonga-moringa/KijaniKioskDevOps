pipeline {
    agent any

    tools {
        nodejs 'node'
    }

    environment {
        NODE_ENV   = 'test'
        BUILD_DIR  = 'dist'
        APP_NAME   = 'kijanikiosk-payments'
        NEXUS_URL  = 'http://nexus:8081/repository/kijanikiosk-payments/'
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

                echo "Verifying build workspace..."
                sh '''
                    set -e
                    test -d "${BUILD_DIR}" || { echo "ERROR: build directory not found"; exit 1; }
                    echo "Build output verified: $(ls ${BUILD_DIR} | wc -l) file(s) in ${BUILD_DIR}/"
                '''
            }
        }

        stage('Test') {
            steps {
                echo "Running unit test suite for ${APP_NAME}..."
                sh 'npm test'
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

        stage('Publish') {
            steps {
                echo "Publishing ${APP_NAME} versioned artifact to Nexus..."
                withCredentials([usernamePassword(credentialsId: 'nexus-credentials', usernameVariable: 'NEXUS_USER', passwordVariable: 'NEXUS_PASS')]) {
                    sh '''
                        set -e
                        # Create temporary authenticated .npmrc for Nexus
                        AUTH_BASE64=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64)
                        echo "//nexus:8081/repository/kijanikiosk-payments/:_auth=${AUTH_BASE64}" > .npmrc
                        echo "//nexus:8081/repository/kijanikiosk-payments/:always-auth=true" >> .npmrc

                        # Pack and publish package to Nexus
                        npm publish --registry http://nexus:8081/repository/kijanikiosk-payments/

                        # Clean up local .npmrc so credentials don't linger on workspace
                        rm -f .npmrc
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Pipeline succeeded: ${APP_NAME} build ${BUILD_NUMBER}"
            echo "Artifact Published to Nexus: ${NEXUS_URL}"
        }
        failure {
            echo "Pipeline FAILED: ${APP_NAME} build ${BUILD_NUMBER} - check console logs"
        }
        always {
            cleanWs()
        }
    }
}
