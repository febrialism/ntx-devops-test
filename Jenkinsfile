pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'webapp-dockerize-nodejs'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'webapp-nodejs'
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
        
        stage('Install Dependencies') {
            steps {
                echo 'Installing Node.js dependencies...'
                sh 'npm install'
            }
        }
        
        stage('Start App for Testing') {
            steps {
                echo 'Starting application for testing...'
                sh '''
                    # Start app in background
                    nohup npm start > app.log 2>&1 &
                    echo $! > app.pid
                    
                    # Wait for app to start
                    sleep 5
                    
                    # Check if app is running
                    if ps -p $(cat app.pid) > /dev/null; then
                        echo "App started successfully with PID $(cat app.pid)"
                    else
                        echo "Failed to start app"
                        exit 1
                    fi
                '''
            }
        }
        
        stage('HTTP 200 Test') {
            steps {
                echo 'Running HTTP 200 test...'
                sh 'npm test'
            }
            post {
                always {
                    echo 'Stopping test application...'
                    sh '''
                        if [ -f app.pid ]; then
                            kill $(cat app.pid) || true
                            rm app.pid
                        fi
                        pkill -f "node index.js" || true
                    '''
                }
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
                    docker rm ${CONTAINER_NAME} || true
                '''
            }
        }
        
        stage('Deploy Container') {
            steps {
                echo 'Deploying new container...'
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p ${APP_PORT}:3000 \
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
                        curl http://localhost:${APP_PORT}/
                    else
                        echo "❌ Deployment verification failed - HTTP $response"
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
