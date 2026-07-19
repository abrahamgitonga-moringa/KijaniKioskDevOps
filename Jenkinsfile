pipeline {
    agent any
    
    tools {
        // Tells Jenkins to inject the pre-configured Node.js toolset
        nodejs 'node' 
    }

    stages {
        stage('Environment Check') {
            steps {
                echo "Build triggered for: ${env.GIT_COMMIT}"
		sh 'sudo apt-get update && sudo apt-get install -y libatomic1'
                sh 'node --version'
                sh 'npm --version'
            }
        }
        // ... your other stages (Install, Test, etc.)
    }
    post {
        always {
            echo "Pipeline finished. Status: ${currentBuild.result ?: 'SUCCESS'}"
        }
    }
}
