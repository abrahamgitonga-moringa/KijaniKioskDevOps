pipeline {
    agent any

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
        stage('Initialize Environment') {
            steps {
                script {
                    env.PKG_VERSION      = sh(script: "node -p \"require('./package.json').version\"", returnStdout: true).trim()
                    env.GIT_SHORT        = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                    env.ARTIFACT_VERSION = "${env.PKG_VERSION}-${env.GIT_SHORT}"
                }
                echo "Building ${APP_NAME} version ${ARTIFACT_VERSION}"
            }
        }

        stage('Lint') {
            steps {
                echo "Running code quality and syntax checks..."
                sh 'npm run lint || true'
            }
        }

        stage('Build') {
            steps {
                echo "Installing dependencies and building application..."
                sh 'npm ci'
                sh 'npm run build'
                
                sh '''
                    set -e
                    test -d ${BUILD_DIR}
                    test $(ls -A ${BUILD_DIR} | wc -l) -gt 0
                    echo "Verified build output directory: ${BUILD_DIR}"
                '''
                
                stash name: 'build-artifacts', includes: "${BUILD_DIR}/**"
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        unstash 'build-artifacts'
                        echo "Executing unit test suite..."
                        sh 'npm test'
                    }
                    post {
                        always {
                            junit allowEmptyResults: true, testResults: 'test-results/*.xml'
                        }
                    }
                }
                stage('Security Audit') {
                    steps {
                        echo "Running security audit for high/critical vulnerabilities..."
                        sh 'npm audit --audit-level=high || true'
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                echo "Archiving build outputs in Jenkins..."
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }

        stage('Publish') {
            steps {
                echo "Publishing versioned artifact to Nexus..."
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
        }
        failure {
            echo "Pipeline FAILED at build ${BUILD_NUMBER} - check console logs at ${BUILD_URL}"
        }
        always {
            script {
                // Safeguard cleanWs so it doesn't throw when no workspace node exists
                try {
                    cleanWs()
                } catch (Exception e) {
                    echo "Skipped workspace cleanup: ${e.message}"
                }
            }
        }
    }
}
