pipeline {
    agent any

    environment {
        AWS_REGION = 'us-east-1'
        AWS_ACCOUNT_ID = '992382545251'

        ECR_REPOSITORY = 'avivneta-status-page-dev'

        ECR_REGISTRY = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        IMAGE_TAG = "${BUILD_NUMBER}"

        SKIP_PIPELINE = 'false'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Detect GitOps Commit') {
            steps {
                script {
                    def commitMessage = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()

                    if (commitMessage.contains('[skip ci]')) {
                        env.SKIP_PIPELINE = 'true'
                        currentBuild.description = 'GitOps state commit - CI skipped'
                        echo 'GitOps-generated commit detected. CI stages will be skipped.'
                    } else {
                        env.SKIP_PIPELINE = 'false'
                    }
                }
            }
        }

        stage('Tests') {
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

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

        stage('Update GitOps Desired State') {
            when {
                expression {
                    env.SKIP_PIPELINE != 'true'
                }
            }

            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'github-status-page-write',
                        usernameVariable: 'GITHUB_USER',
                        passwordVariable: 'GITHUB_TOKEN'
                    )
                ]) {
                    sh '''
                        set -eu

                        echo "===== UPDATE GITOPS IMAGE TAG ====="

                        python3 - <<'PYUPDATE'
from pathlib import Path
import os

p = Path("status-page-chart/values.yaml")
lines = p.read_text().splitlines()

image_tag = os.environ["IMAGE_TAG"]

image_block = None
tag_index = None

for i, line in enumerate(lines):
    if line.strip() == "image:" and not line.startswith(" "):
        image_block = i
        break

if image_block is None:
    raise SystemExit("Top-level image block not found")

for i in range(image_block + 1, min(image_block + 10, len(lines))):
    if lines[i].startswith("  tag:"):
        tag_index = i
        break

if tag_index is None:
    raise SystemExit("Top-level image tag not found")

old = lines[tag_index]
new = f'  tag: "{image_tag}"'

print(f"{old} -> {new}")

lines[tag_index] = new

p.write_text("\n".join(lines) + "\n")
PYUPDATE

                        echo
                        echo "===== VALIDATE GIT CHANGE ====="

                        git diff --check

                        git diff -- status-page-chart/values.yaml

                        git config user.name "Jenkins GitOps"
                        git config user.email "jenkins-gitops@users.noreply.github.com"

                        git add status-page-chart/values.yaml

                        if git diff --cached --quiet; then
                            echo "GitOps desired state already uses image ${IMAGE_TAG}"
                            exit 0
                        fi

                        git commit                           -m "chore(gitops): deploy image ${IMAGE_TAG} [skip ci]"

                        ASKPASS_SCRIPT=$(mktemp)

                        cleanup_git_auth() {
                            rm -f "$ASKPASS_SCRIPT"
                        }

                        trap cleanup_git_auth EXIT

                        cat > "$ASKPASS_SCRIPT" <<'EOF'
#!/bin/sh
case "$1" in
  *Username*)
    printf '%s\n' "$GITHUB_USER"
    ;;
  *Password*)
    printf '%s\n' "$GITHUB_TOKEN"
    ;;
esac
EOF

                        chmod 700 "$ASKPASS_SCRIPT"

                        echo
                        echo "===== PUSH GITOPS DESIRED STATE ====="

                        GIT_ASKPASS="$ASKPASS_SCRIPT"                         GIT_TERMINAL_PROMPT=0                         git push                           https://github.com/SetGaming/status-page-project.git                           HEAD:main
                    '''
                }
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
