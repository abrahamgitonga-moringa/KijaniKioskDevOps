pipeline {
    agent any

    environment {
        NODE_ENV  = 'test'
        BUILD_DIR = 'dist'
        APP_NAME  = 'kijanikiosk-payments'
        NEXUS_URL = 'http://nexus:8081/repository/kijanikiosk-payments/'
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
                withCredentials([usernamePassword(
                    credentialsId: 'nexus-credentials',
                    usernameVariable: 'NEXUS_USER',
                    passwordVariable: 'NEXUS_PASS'
                )]) {
                    sh '''
                        set -e
                        
                        # 1. Setup safety cleanup trap
                        trap "rm -f .npmrc" EXIT
                        
                        # 2. Compute dynamic version string
                        PKG_VERSION=$(node -p "require('./package.json').version")
                        GIT_SHORT=$(git rev-parse --short HEAD)
                        ARTIFACT_VERSION="${PKG_VERSION}-${GIT_SHORT}"
                        
                        echo "Target Artifact Version: ${ARTIFACT_VERSION}"
                        
                        # 3. Generate Auth token and write temporary .npmrc
                        AUTH_BASE64=$(echo -n "${NEXUS_USER}:${NEXUS_PASS}" | base64 | tr -d '\n')
                        
                        cat <<EOF > .npmrc
//nexus:8081/repository/kijanikiosk-payments/:_auth=${AUTH_BASE64}
//nexus:8081/repository/kijanikiosk-payments/:always-auth=true
EOF

                        # 4. Update package.json dynamically before publish
                        npm version "${ARTIFACT_VERSION}" --no-git-tag-version
                        
                        # 5. Publish artifact to Nexus
                        npm publish --registry "${NEXUS_URL}"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo "Published ${APP_NAME} version successfully to Nexus."
        }
        failure {
            echo "Pipeline FAILED at build ${BUILD_NUMBER} - check logs at ${BUILD_URL}"
        }
        always {
            cleanWs()
        }
    }
}
