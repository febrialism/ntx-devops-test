pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'my-nodejs-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'nodejs-app-container'
        // The port INSIDE the container. It's a string here, which is standard for env vars.
        APP_PORT = '3000' 
        // Port for the final deployed container on the host
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
                sh 'npm install'
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    appImage = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }

        stage('Integration Test in Docker') {
            steps {
                echo "Running integration tests against the new Docker image..."
                script {
                    appImage.withRun("--name test-${CONTAINER_NAME}-${BUILD_NUMBER}") { container ->
                        
                        // *** FIX IS HERE ***
                        // We convert the APP_PORT string from the environment block to an Integer
                        def mappedPort = docker.port(container.id, APP_PORT.toInteger())
                        
                        echo "Waiting for test container to be ready on host port ${mappedPort}..."
                        
                        sh """
                            for i in \$(seq 1 15); do
                                if curl -s -f http://localhost:${mappedPort}/health; then
                                    echo 'Test container is up!'
                                    break
                                fi
                                echo -n '.'
                                sleep 2
                                if [ \$i -eq 15 ]; then
                                    echo 'Test container failed to start in time.'
                                    docker logs ${container.id}
                                    exit 1
                                fi
                            done
                        """
                        
                        echo "Running tests against http://localhost:${mappedPort}..."
                        sh "APP_URL=http://localhost:${mappedPort} npm test"
                    }
                }
            }
        }
        
        stage('Deploy') {
            steps {
                echo 'Stopping and removing previous production container...'
                sh "docker stop ${CONTAINER_NAME} || true"
                sh "docker rm ${CONTAINER_NAME} || true"

                echo "Deploying new container. Mapping host port ${DEPLOY_PORT} to container port ${APP_PORT}"
                sh """
                    docker run -d \\
                        --name ${CONTAINER_NAME} \\
                        -p ${DEPLOY_PORT}:${APP_PORT} \\
                        --restart unless-stopped \\
                        ${DOCKER_IMAGE}:latest
                """
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh """
                    sleep 10
                    response=\$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${DEPLOY_PORT}/health)
                    if [ "\$response" = "200" ]; then
                        echo "✅ Deployment verification successful"
                        curl http://localhost:${DEPLOY_PORT}/
                    else
                        echo "❌ Deployment verification failed - HTTP \$response"
                        docker logs ${CONTAINER_NAME}
                        exit 1
                    fi
                """
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed. Cleaning up...'
            sh '''
                # Clean up old images (keep last 5)
                docker images ${DOCKER_IMAGE} --format "{{.Tag}}" | grep -v "latest" | sort -nr | tail -n +6 | xargs -r --no-run-if-empty docker rmi -f ${DOCKER_IMAGE} || true
            '''
        }
        success {
            echo "✅ Pipeline succeeded! Application is running at http://localhost:${DEPLOY_PORT}"
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                echo "Container logs (if any):"
                docker logs ${CONTAINER_NAME} || echo "No production container was running."
            '''
        }
    }
}