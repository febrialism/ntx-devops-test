pipeline {
    agent any
    
    environment {
        DOCKER_IMAGE = 'my-nodejs-app'
        DOCKER_TAG = "${BUILD_NUMBER}"
        CONTAINER_NAME = 'nodejs-app-container'
        APP_PORT = '3000'
        TEST_PORT = '3001'  // Different port for testing
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
                echo 'Starting application for testing on port ${TEST_PORT}...'
                sh '''
                    # Kill any existing test processes (both npm and node)
                    pkill -f "npm start" || true
                    pkill -f "node index.js" || true
                    sleep 3
                    
                    # Start app directly with node (not npm) to get correct PID
                    PORT=${TEST_PORT} nohup node index.js > app.log 2>&1 &
                    NODE_PID=$!
                    echo $NODE_PID > app.pid
                    
                    echo "Started Node.js process with PID: $NODE_PID"
                    
                    # Verify the process is actually running
                    if ps -p $NODE_PID > /dev/null; then
                        echo "✅ Process $NODE_PID is running"
                    else
                        echo "❌ Process $NODE_PID is not running"
                        cat app.log
                        exit 1
                    fi
                    
                    # Wait for app to start accepting connections
                    echo "Waiting for app to start on port ${TEST_PORT}..."
                    for i in {1..30}; do
                        if curl -s http://localhost:${TEST_PORT}/health > /dev/null 2>&1; then
                            echo "✅ App started successfully on port ${TEST_PORT}"
                            echo "Process details:"
                            ps -p $NODE_PID -o pid,ppid,cmd
                            break
                        fi
                        if [ $i -eq 30 ]; then
                            echo "❌ App failed to start within 30 seconds"
                            echo "Process status:"
                            ps -p $NODE_PID || echo "Process not found"
                            echo "App logs:"
                            cat app.log
                            echo "Port status:"
                            netstat -tlpn | grep ${TEST_PORT} || echo "Port not in use"
                            exit 1
                        fi
                        sleep 1
                    done
                '''
            }
        }
        
        stage('HTTP 200 Test') {
            steps {
                echo 'Running HTTP 200 test...'
                sh '''
                    echo "Testing application on port ${TEST_PORT}..."
                    
                    # Test health endpoint
                    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/health)
                    
                    if [ "$response" = "200" ]; then
                        echo "✅ Health check test PASSED: HTTP 200 received"
                        curl -s http://localhost:${TEST_PORT}/health
                    else
                        echo "❌ Health check test FAILED: Expected 200, got $response"
                        exit 1
                    fi
                    
                    # Test main endpoint
                    response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${TEST_PORT}/)
                    
                    if [ "$response" = "200" ]; then
                        echo "✅ Main endpoint test PASSED: HTTP 200 received"
                        curl -s http://localhost:${TEST_PORT}/
                    else
                        echo "❌ Main endpoint test FAILED: Expected 200, got $response"
                        exit 1
                    fi
                '''
            }
            post {
                always {
                    echo 'Stopping test application...'
                    sh '''
                        if [ -f app.pid ]; then
                            NODE_PID=$(cat app.pid)
                            echo "Killing Node.js process: $NODE_PID"
                            kill $NODE_PID || true
                            
                            # Wait for process to die
                            for i in {1..10}; do
                                if ! ps -p $NODE_PID > /dev/null 2>&1; then
                                    echo "✅ Process $NODE_PID terminated successfully"
                                    break
                                fi
                                if [ $i -eq 10 ]; then
                                    echo "⚠️  Force killing process $NODE_PID"
                                    kill -9 $NODE_PID || true
                                fi
                                sleep 1
                            done
                            
                            rm app.pid
                        fi
                        
                        # Clean up any remaining processes
                        pkill -f "node index.js" || true
                        pkill -f "npm start" || true
                        sleep 2
                        
                        # Verify port is free
                        if netstat -tlpn | grep -q ":${TEST_PORT} "; then
                            echo "⚠️  Port ${TEST_PORT} still in use:"
                            netstat -tlpn | grep ":${TEST_PORT} "
                        else
                            echo "✅ Port ${TEST_PORT} is now free"
                        fi
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
                    sleep 3
                '''
            }
        }
        
        stage('Deploy Container') {
            steps {
                echo 'Deploying new container...'
                sh '''
                    docker run -d \
                        --name ${CONTAINER_NAME} \
                        -p ${APP_PORT}:3001 \
                        --restart unless-stopped \
                        ${DOCKER_IMAGE}:latest
                    
                    # Wait for container to start
                    echo "Waiting for container to start..."
                    for i in {1..30}; do
                        if docker ps | grep -q ${CONTAINER_NAME}; then
                            echo "✅ Container started successfully"
                            break
                        fi
                        if [ $i -eq 30 ]; then
                            echo "❌ Container failed to start within 30 seconds"
                            docker logs ${CONTAINER_NAME}
                            exit 1
                        fi
                        sleep 1
                    done
                '''
            }
        }
        
        stage('Verify Deployment') {
            steps {
                echo 'Verifying deployment...'
                sh '''
                    # Wait for full startup
                    echo "Waiting for application to be ready..."
                    for i in {1..30}; do
                        response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${APP_PORT}/health)
                        if [ "$response" = "200" ]; then
                            echo "✅ Deployment verification successful"
                            echo "Application response:"
                            curl -s http://localhost:${APP_PORT}/
                            break
                        fi
                        if [ $i -eq 30 ]; then
                            echo "❌ Deployment verification failed after 30 seconds - HTTP $response"
                            docker logs ${CONTAINER_NAME}
                            exit 1
                        fi
                        sleep 1
                    done
                '''
            }
        }
    }
    
    post {
        always {
            echo 'Pipeline completed'
            sh '''
                echo "Current Docker containers:"
                docker ps
                echo "Docker images:"
                docker images | grep ${DOCKER_IMAGE}
            '''
        }
        success {
            echo '✅ Pipeline succeeded! Application is running at http://localhost:3000'
        }
        failure {
            echo '❌ Pipeline failed!'
            sh '''
                echo "=== Container logs ==="
                docker logs ${CONTAINER_NAME} || true
                
                echo "=== App test logs ==="
                cat app.log || true
                
                echo "=== Port usage ==="
                netstat -tlpn | grep -E ":300[0-9]" || true
            '''
        }
        cleanup {
            sh '''
                # Clean up test processes thoroughly
                echo "=== Cleanup: Stopping all test processes ==="
                pkill -f "node index.js" || true
                pkill -f "npm start" || true
                
                # Clean up files
                rm -f app.pid app.log || true
                
                # Verify cleanup
                if pgrep -f "node index.js" > /dev/null; then
                    echo "⚠️  Some Node.js processes still running:"
                    pgrep -f "node index.js" | xargs ps -p || true
                else
                    echo "✅ All Node.js test processes cleaned up"
                fi
                
                # Clean up old images (keep last 3)
                docker images ${DOCKER_IMAGE} --format "table {{.Tag}}" | tail -n +2 | sort -nr | tail -n +4 | xargs -r -I {} docker rmi ${DOCKER_IMAGE}:{} || true
            '''
        }
    }
}
