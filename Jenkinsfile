pipeline {
    agent any

    tools {
        nodejs 'node' // Ensures Node.js and npm are available in PATH
    }

    environment {
        NODE_ENV  = 'test'
        BUILD_DIR = 'dist'
        APP_NAME  = 'kijanikiosk-payments'
        NEXUS_URL = 'http://nexus:8081/repository/kijanikiosk-payments'
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
                    test -d ${BUILD_DIR}
                    echo "Build output verified in ${BUILD_DIR}/"
                '''
            }
        }

        stage('Test') {
            steps {
                echo "Running unit test suite..."
                sh '''
                    set -e
                    npm test
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                }
            }
        }

        stage('Archive') {
            steps {
                echo "Archiving build artifacts..."
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }

        stage('Publish') {
            steps {
                echo "Publishing versioned artifact to Nexus..."
                script {
                    env.PKG_VERSION = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()
                    env.GIT_SHORT   = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.ARTIFACT_VERSION = "${env.PKG_VERSION}-${env.GIT_SHORT}"
                }
                
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e
                        
                        trap "rm -f .npmrc" EXIT
                        
                        echo "Target Artifact Version: ${ARTIFACT_VERSION}"
                        
                        AUTH_BASE64=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64 | tr -d '\n')
                        
                        cat <<EOF > .npmrc
//nexus:8081/repository/kijanikiosk-payments/:_auth=${AUTH_BASE64}
//nexus:8081/repository/kijanikiosk-payments/:always-auth=true
EOF

                        npm version "${ARTIFACT_VERSION}" --no-git-tag-version
                        npm publish --registry "${NEXUS_URL}/" --tag dev
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Published ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus"
            echo "Artifact URL: ${NEXUS_URL}/${APP_NAME}/-/${APP_NAME}-${ARTIFACT_VERSION}.tgz"
        }
        failure {
            echo "Pipeline FAILED at build ${BUILD_NUMBER} - check logs at ${BUILD_URL}"
        }
        always {
            cleanWs()
        }
    }
}
