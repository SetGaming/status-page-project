pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '992382545251'

        ECR_REPOSITORY = 'avivneta-status-page-dev'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        IMAGE_TAG = "${BUILD_NUMBER}"

        EKS_CLUSTER = 'avivneta-status-page-dev-eks'

        HELM_RELEASE = 'status-page'
        HELM_NAMESPACE = 'status-page'
        HELM_CHART = 'status-page-chart'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Tests') {
            steps {
                sh '''
                    echo "Checking Python source..."

                    docker run --rm \
                      -v "$WORKSPACE:/app" \
                      -w /app \
                      python:3.10-slim \
                      python -m compileall -q statuspage
                '''
            }
        }

        stage('Trivy Scan') {
            steps {
                sh '''
                    trivy fs \
                      --scanners vuln \
                      --exit-code 1 \
                      --severity CRITICAL \
                      --no-progress \
                      --skip-files statuspage/project-static/yarn.lock \
                      .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build \
                      -t ${ECR_REPOSITORY}:${IMAGE_TAG} \
                      -t ${ECR_REPOSITORY}:latest \
                      .
                '''
            }
        }

        stage('Runtime Validation') {
            steps {
                sh '''
                    set -eu

                    NETWORK="status-page-ci-${BUILD_NUMBER}"
                    POSTGRES="status-page-ci-postgres-${BUILD_NUMBER}"
                    REDIS="status-page-ci-redis-${BUILD_NUMBER}"
                    APP="status-page-ci-app-${BUILD_NUMBER}"

                    cleanup() {
                        echo "Cleaning Runtime Validation resources..."

                        docker rm -f \
                          "$APP" \
                          "$POSTGRES" \
                          "$REDIS" \
                          >/dev/null 2>&1 || true

                        docker network rm \
                          "$NETWORK" \
                          >/dev/null 2>&1 || true
                    }

                    trap cleanup EXIT

                    cleanup

                    echo "===== CREATE TEMPORARY NETWORK ====="

                    docker network create "$NETWORK"

                    echo
                    echo "===== START TEMPORARY POSTGRESQL ====="

                    docker run -d \
                      --name "$POSTGRES" \
                      --network "$NETWORK" \
                      -e POSTGRES_DB=statuspage \
                      -e POSTGRES_USER=statuspage \
                      -e POSTGRES_PASSWORD=ci-test-password \
                      postgres:15-alpine

                    echo
                    echo "===== START TEMPORARY REDIS ====="

                    docker run -d \
                      --name "$REDIS" \
                      --network "$NETWORK" \
                      redis:7-alpine

                    echo
                    echo "===== WAIT FOR POSTGRESQL ====="

                    POSTGRES_READY=0

                    for i in $(seq 1 60); do

                        if docker exec "$POSTGRES" \
                          pg_isready \
                          -U statuspage \
                          -d statuspage \
                          >/dev/null 2>&1; then

                            POSTGRES_READY=1
                            break
                        fi

                        sleep 2
                    done

                    if [ "$POSTGRES_READY" != "1" ]; then
                        echo "PostgreSQL did not become ready"

                        docker logs "$POSTGRES" \
                          --tail 100 || true

                        exit 1
                    fi

                    docker exec "$POSTGRES" \
                      pg_isready \
                      -U statuspage \
                      -d statuspage

                    echo
                    echo "===== WAIT FOR REDIS ====="

                    REDIS_READY=0

                    for i in $(seq 1 60); do

                        if docker exec "$REDIS" \
                          redis-cli ping \
                          2>/dev/null |
                          grep -q PONG; then

                            REDIS_READY=1
                            break
                        fi

                        sleep 2
                    done

                    if [ "$REDIS_READY" != "1" ]; then
                        echo "Redis did not become ready"

                        docker logs "$REDIS" \
                          --tail 100 || true

                        exit 1
                    fi

                    docker exec "$REDIS" \
                      redis-cli ping |
                      grep PONG

                    echo
                    echo "===== RUN DATABASE MIGRATIONS ====="

                    docker run --rm \
                      --network "$NETWORK" \
                      -e DB_HOST="$POSTGRES" \
                      -e DB_PORT=5432 \
                      -e DB_NAME=statuspage \
                      -e DB_USER=statuspage \
                      -e DB_PASSWORD=ci-test-password \
                      -e REDIS_HOST="$REDIS" \
                      -e REDIS_PORT=6379 \
                      -e REDIS_PASSWORD="" \
                      -e ALLOWED_HOSTS=localhost,127.0.0.1 \
                      -e SITE_URL=http://localhost \
                      -e SECRET_KEY=ci-runtime-validation-only-secret-key-12345678901234567890 \
                      ${ECR_REPOSITORY}:${IMAGE_TAG} \
                      python manage.py migrate --noinput

                    echo
                    echo "===== START APPLICATION CONTAINER ====="

                    docker run -d \
                      --name "$APP" \
                      --network "$NETWORK" \
                      -p 127.0.0.1::8000 \
                      -e DB_HOST="$POSTGRES" \
                      -e DB_PORT=5432 \
                      -e DB_NAME=statuspage \
                      -e DB_USER=statuspage \
                      -e DB_PASSWORD=ci-test-password \
                      -e REDIS_HOST="$REDIS" \
                      -e REDIS_PORT=6379 \
                      -e REDIS_PASSWORD="" \
                      -e ALLOWED_HOSTS=localhost,127.0.0.1 \
                      -e SITE_URL=http://localhost \
                      -e SECRET_KEY=ci-runtime-validation-only-secret-key-12345678901234567890 \
                      ${ECR_REPOSITORY}:${IMAGE_TAG}

                    HOST_PORT=$(docker port \
                      "$APP" \
                      8000/tcp |
                      awk -F: 'NR==1 {print $NF}')

                    echo "Runtime application port: $HOST_PORT"

                    if [ -z "$HOST_PORT" ]; then
                        echo "Could not determine application port"
                        docker logs "$APP" --tail 150 || true
                        exit 1
                    fi

                    echo
                    echo "===== HTTP RUNTIME HEALTH CHECK ====="

                    APP_READY=0

                    for i in $(seq 1 60); do

                        HTTP_CODE=$(curl \
                          -sS \
                          -o /dev/null \
                          -w '%{http_code}' \
                          --max-time 5 \
                          -H 'Host: localhost' \
                          "http://127.0.0.1:${HOST_PORT}/" \
                          || true)

                        echo "Attempt $i -> HTTP $HTTP_CODE"

                        if [ "$HTTP_CODE" = "200" ]; then
                            APP_READY=1
                            break
                        fi

                        sleep 2
                    done

                    if [ "$APP_READY" != "1" ]; then

                        echo
                        echo "===== APPLICATION LOGS ====="

                        docker logs \
                          "$APP" \
                          --tail 150 || true

                        echo
                        echo "Runtime Validation FAILED"

                        exit 1
                    fi

                    echo
                    echo "Runtime Validation passed."
                '''
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh '''
                    trivy image \
                      --ignore-unfixed \
                      --exit-code 1 \
                      --severity CRITICAL \
                      --no-progress \
                      ${ECR_REPOSITORY}:${IMAGE_TAG}
                '''
            }
        }

        stage('Push to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password \
                      --region ${AWS_REGION} |
                      docker login \
                        --username AWS \
                        --password-stdin \
                        ${ECR_REGISTRY}

                    docker tag \
                      ${ECR_REPOSITORY}:${IMAGE_TAG} \
                      ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}

                    docker tag \
                      ${ECR_REPOSITORY}:latest \
                      ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest

                    docker push \
                      ${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}

                    docker push \
                      ${ECR_REGISTRY}/${ECR_REPOSITORY}:latest
                '''
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''
                    aws eks update-kubeconfig \
                      --region ${AWS_REGION} \
                      --name ${EKS_CLUSTER}

                    helm upgrade \
                      --install \
                      ${HELM_RELEASE} \
                      ${HELM_CHART} \
                      --namespace ${HELM_NAMESPACE} \
                      --create-namespace \
                      --set image.repository=${ECR_REGISTRY}/${ECR_REPOSITORY} \
                      --set image.tag=${IMAGE_TAG} \
                      --wait \
                      --timeout 10m

                    kubectl rollout status \
                      deployment/status-page \
                      -n ${HELM_NAMESPACE} \
                      --timeout=300s

                    kubectl rollout status \
                      deployment/rq-worker \
                      -n ${HELM_NAMESPACE} \
                      --timeout=300s

                    kubectl rollout status \
                      deployment/rq-scheduler \
                      -n ${HELM_NAMESPACE} \
                      --timeout=300s
                '''
            }
        }
    }

    post {

        success {
            echo 'CI pipeline completed successfully.'
        }

        failure {
            echo 'CI pipeline failed. Check the failed stage.'
        }
    }
}
