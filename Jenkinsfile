pipeline {
    agent any

    environment {
        BACKEND_IMAGE = "rentora-backend:local"
        FRONTEND_IMAGE = "rentora-frontend:local"
        POSTGRES_CONTAINER = "rentora-postgres"
        BACKEND_CONTAINER = "rentora-backend-container"
        FRONTEND_CONTAINER = "rentora-frontend-container"
        FRONTEND_PORT = "5173" 
    }

    triggers{
        pollSCM('H/5 * * * *')
    }

    stages {

        stage('Checkout Repos') {
            steps {
                parallel(
                dir('backend') {
                    git url: 'https://github.com/jabandfriends/rentora-api.git', branch: 'develop', credentialsId: 'github-creds'
                }
                dir('frontend') {
                    git url: 'https://github.com/jabandfriends/rentora-interface.git', branch: 'test/e2e-testing', credentialsId: 'github-creds'
                }
                )
            }
        }

        stage('Prepare Env File') {
            steps {
                dir('backend') {
                    // Make sure .env exists (you can load from Jenkins credentials or keep in repo)
                    sh '''
                    if [ ! -f .env ]; then
                        echo "SERVER_PORT=8081" >> .env
                        echo "POSTGRES_DB=rentora_db" >> .env
                        echo "POSTGRES_USER=rentora" >> .env
                        echo "POSTGRES_PASSWORD=password" >> .env

                        echo "SPRING_DATASOURCE_HOST=localhost" >> .env
                        echo "JWT_SECRET=YourVerySecretJWTKeyThatShouldBeAtLeast256BitsLongForHS256Algorithm" >> .env

                        echo "AWS_S3_ACCESS_KEY=AKIA3XEJ7VNSZLFKNFUK" >> .env
                        echo "AWS_S3_SECRET_ACCESS_KEY=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" >> .env
                        echo "AWS_S3_BUCKET_NAME=rentora-images" >> .env
                        echo "AWS_S3_REGION=ap-southeast-1" >> .env

                        echo "APP_CORS_ALLOWED_ORIGINS=http://localhost:3000,http://localhost:5173,http://localhost:80,http://localhost" >> .env
                    fi
                    '''
                }
            }
        }

        stage('Run Postgres Only') {
            steps {
                dir('backend') {
                    sh 'docker-compose down -v || true'
                    sh 'docker-compose up -d database'
                }
            }
        }

        stage('Build Backend Docker Image') {
            steps {
                dir('backend') {
                    sh "docker build -t ${BACKEND_IMAGE} ."
                }
            }
        }
        stage('Setup Docker Network') {
            steps {
                sh "docker network create rentora-network || true"
            }
        }
        stage('Run Backend Container') {
            steps {
                dir('backend') {
                    sh "docker rm -f ${BACKEND_CONTAINER} || true"
                    sh """
                    docker run -d --name ${BACKEND_CONTAINER} \
                        -p 8081:8081 \
                        --network host \
                        -e SERVER_PORT=8081 \
                        -e SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/rentora_db \
                        -e SPRING_DATASOURCE_USERNAME=rentora \
                        -e SPRING_DATASOURCE_PASSWORD=password \
                        -e JWT_SECRET=YourVerySecretJWTKeyThatShouldBeAtLeast256BitsLongForHS256Algorithm \
                        -e AWS_S3_BUCKET_NAME=rentora-images \
                        -e AWS_S3_REGION=ap-southeast-1 \
                        -e AWS_S3_ACCESS_KEY=AKIA3XEJ7VNSZLFKNFUK \
                        -e AWS_S3_SECRET_ACCESS_KEY=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 \
                        -e APP_CORS_ALLOWED_ORIGINS=http://localhost:80,http://localhost:5173,http://localhost \
                        ${BACKEND_IMAGE}
                    """
                }
            }
        }   

        stage('Build Frontend Docker Image') {
            steps {
                dir('frontend') {
                    sh "docker build --build-arg VITE_RENTORA_API_BASE_URL=http://localhost:8081 -t ${FRONTEND_IMAGE} ."
                }
            }
        }

        stage('Run Frontend Container') {
            steps {
                dir('frontend') {
                    sh "docker rm -f ${FRONTEND_CONTAINER} || true"
                    sh """
                    docker run -d --name ${FRONTEND_CONTAINER} \
                        --network host \
                        -p 80:80 \
                        ${FRONTEND_IMAGE}
                    """
                }
            }
        }
        
        stage('Run Cypress E2E Tests') {
            steps {
                dir('frontend') {
                    sh """
                    pnpm install --frozen-lockfile
                    echo "Running Cypress tests"
                    RENTORA_FRONTEND_BASE_URL=http://localhost npx cypress run
                    """
                }
            }
        }

    }

    post {
        always {
            echo 'Finish'
            // sh """
            // docker rm -f ${FRONTEND_CONTAINER} || true
            // docker rmi -f ${FRONTEND_IMAGE} ${BACKEND_IMAGE} || true
            // """
            // dir('backend') {
            //     sh 'docker-compose down -v || true'
            // }
        }
    }
}
