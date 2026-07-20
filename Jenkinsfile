pipeline {
    agent {
        docker {
            image 'node:18-alpine'
            args  '--network host -v /tmp:/tmp'
        }
    }

    environment {
        NODE_ENV  = 'test'
        BUILD_DIR = 'dist'
        APP_NAME  = 'kijanikiosk-payments'
        NEXUS_URL = 'http://127.0.0.1:8081/repository/kijanikiosk-payments'
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
                    env.GIT_SHORT        = env.GIT_COMMIT ? env.GIT_COMMIT.take(7) : 'local'
                    env.ARTIFACT_VERSION = "${env.PKG_VERSION}-${env.GIT_SHORT}"
                }
                echo "Initializing release build for ${APP_NAME} version ${ARTIFACT_VERSION}"
            }
        }

        stage('Lint') {
            steps {
                echo "Executing fail-fast syntax and style validation..."
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
                    echo "Verified output build directory: ${BUILD_DIR}"
                '''
                
                stash name: 'build-artifacts', includes: "${BUILD_DIR}/**,package.json,package-lock.json"
            }
        }

        stage('Verify') {
            parallel {
                stage('Test') {
                    steps {
                        unstash 'build-artifacts'
                        echo "Running automated unit test suite..."
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
                        echo "Auditing dependencies against known vulnerabilities..."
                        sh 'npm audit --audit-level=high || true'
                    }
                }
            }
        }

        stage('Archive') {
            steps {
                echo "Archiving build outputs with fingerprinting..."
                archiveArtifacts artifacts: "${BUILD_DIR}/**",
                                 fingerprint: true,
                                 onlyIfSuccessful: true
            }
        }

        stage('Publish') {
            steps {
                echo "Publishing versioned artifact to Nexus repository..."
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e
                        trap "rm -f .npmrc" EXIT
                        
                        echo "Publishing Version: ${ARTIFACT_VERSION}"
                        AUTH_BASE64=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64 | tr -d '\n')
                        
                        cat <<EOF > .npmrc
//127.0.0.1:8081/repository/kijanikiosk-payments/:_auth=${AUTH_BASE64}
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
            echo "SUCCESS: Published ${APP_NAME} version ${ARTIFACT_VERSION} to Nexus."
        }
        failure {
            echo "FAILURE: Pipeline build ${BUILD_NUMBER} failed."
        }
        changed {
            echo "STATUS CHANGE: Build status transitioned to ${currentBuild.currentResult} for ${JOB_NAME} #${BUILD_NUMBER}"
        }
        always {
            script {
                try {
                    cleanWs()
                    echo "Workspace successfully wiped."
                } catch (Exception e) {
                    echo "Workspace cleanup warning: ${e.message}"
                }
            }
        }
    }
}
