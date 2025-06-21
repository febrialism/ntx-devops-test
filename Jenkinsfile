pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'my-nodejs-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'nodejs-app-container'
        APP_PORT = '3000'
    }
    
    triggers {
        // Poll GitHub every 2 minutes for changes
        pollSCM('H/2 * * * *')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Install Dependencies & App Test') {
            steps {
                echo 'Installing Node.js & App Test...'
                sh 'npm install test'
            }
        }
        
        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    def image = docker.build("${DOCKER_IMAGE}:${DOCKER_TAG}")
                    docker.build("${DOCKER_IMAGE}:latest")
                }
            }
        }
        
        stage('Stop Previous Container') {
            steps {
                echo 'Stopping and removing previous container...'
                sh '''
                    docker stop ${CONTAINER_NAME} || true
                    docker stop ${CONTAINER_NAME}-second || true
                    docker rm -f ${CONTAINER_NAME} || true
                    docker rm -f ${CONTAINER_NAME}-second || true
                '''
            }
        }
        
        stage('Deploy Container') {
            steps {
                echo 'Deploying new container...'
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        --network my-loadbalancer-net \
                        -p localhost:${APP_PORT}:3000 \
                        --restart unless-stopped \
                        ${DOCKER_IMAGE}:latest
                    
                    # Wait for container to start
                    sleep 5
                    
                    # Verify container is running
                    if docker ps | grep -q ${CONTAINER_NAME}; then
                        echo "Container deployed successfully"
                        docker logs ${CONTAINER_NAME}
                    else
                        echo "Container deployment failed"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    # Wait a bit more for full startup
                    sleep 10
                    
                    # Test the deployed application
                    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${APP_PORT}/health)
                    
                    if [ "$response" = "200" ]; then
                        echo "✅ Deployment verification successful"
                        curl http://localhost:3000/
                    else
                        echo "❌ Deployment verification failed - HTTP $response"
                        exit 1
                    fi
                '''
            }
        }

        stage('Deploy Second Container') {
            steps {
                echo 'Deploying second container...'
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME}-second \
                        --network my-loadbalancer-net \
                        -p localhost:3001:${APP_PORT} \
                        --restart unless-stopped \
                        ${DOCKER_IMAGE}:latest
                    
                    # Wait for container to start
                    sleep 5
                    
                    # Verify container is running
                    if docker ps | grep -q ${CONTAINER_NAME}-second; then
                        echo "Second Container deployed successfully"
                        docker logs ${CONTAINER_NAME}-second
                    else
                        echo "Second Container deployment failed"
                        exit 1
                    fi
                '''
            }
        }
    }

    
    post {
        always {
            echo 'Pipeline completed'
            sh 'docker images | grep ${DOCKER_IMAGE}'
        }
        success {
            echo '✅ Pipeline succeeded! Application is running at http://localhost:3000'
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                echo "Container logs:"
                docker logs ${CONTAINER_NAME} || true
                
                echo "App logs:"
                cat app.log || true
            '''
        }
        cleanup {
            sh '''
                # Clean up old images (keep last 5)
                docker images ${DOCKER_IMAGE} --format "table {{.Tag}}" | tail -n +2 | sort -nr | tail -n +6 | xargs -r docker rmi ${DOCKER_IMAGE}: || true
            '''
        }
    }
}