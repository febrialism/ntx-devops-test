pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'my-nodejs-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'nodejs-app-container'
        APP_PORT = '3000'
        // Port for the final deployed container
        DEPLOY_PORT = '3500' 
    }
    
    triggers {
        pollSCM('H/2 * * * *')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Install Dependencies & Unit Test') {
            steps {
                echo 'Installing Node.js dependencies...'
                // It's good practice to run unit tests here before building an image
                sh 'npm install'
                // sh 'npm run test:unit' // If you have unit tests that don't need a running server
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    // Define the image variable so we can use it in the next stage
                    appImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        // *** NEW, ROBUST TESTING STAGE ***
        stage('Integration Test in Docker') {
            steps {
                echo "Running integration tests against the new Docker image..."
                script {
                    // withRun starts a container, runs commands, and guarantees cleanup
                    appImage.withRun("--name test-${CONTAINER_NAME}-${BUILD_NUMBER}") { container ->
                        echo "Waiting for test container to be ready..."
                        // A more robust wait loop
                        sh """
                            for i in \$(seq 1 10); do
                                if curl -s http://localhost:${container.port(APP_PORT)}/health; then
                                    echo 'Test container is up!'
                                    break
                                fi
                                echo -n '.'
                                sleep 2
                                if [ \$i -eq 10 ]; then
                                    echo 'Test container failed to start in time.'
                                    exit 1
                                fi
                            done
                        """
                        
                        echo "Running tests..."
                        // Your npm test script must be configured to use the container's URL
                        // You can pass it as an environment variable
                        sh "APP_URL=http://localhost:${container.port(APP_PORT)} npm test"
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Stopping and removing previous production container...'
                sh "docker stop ${CONTAINER_NAME} || true"
                sh "docker rm ${CONTAINER_NAME} || true"

                echo 'Deploying new container...'
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p ${DEPLOY_PORT}:${APP_PORT} \
                        --restart unless-stopped \
                        ${DOCKER_IMAGE}:latest
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    sleep 10
                    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${DEPLOY_PORT}/health)
                    if [ "$response" = "200" ]; then
                        echo "✅ Deployment verification successful"
                        curl http://localhost:${DEPLOY_PORT}/
                    else
                        echo "❌ Deployment verification failed - HTTP $response"
                        docker logs ${CONTAINER_NAME}
                        exit 1
                    fi
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed. Cleaning up...'
            sh '''
                # Clean up old images (keep last 5)
                docker images ${DOCKER_IMAGE} --format "{{.Tag}}" | grep -v "latest" | sort -nr | tail -n +6 | xargs -r docker rmi ${DOCKER_IMAGE} || true
            '''
        }
        success {
            echo "✅ Pipeline succeeded! Application is running at http://localhost:${DEPLOY_PORT}"
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                echo "Container logs (if any):"
                docker logs ${CONTAINER_NAME} || echo "No container logs."
            '''
        }
    }
}