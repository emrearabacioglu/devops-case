pipeline {
    agent any
    
    parameters {
        choice(name: 'ENV_NAME', choices: ['dev', 'test', 'prod'], description: 'select environment')
    }
    
    environment {
        APP_REPO = "emrearabacioglu"
        IMAGE_TAG = "v1.0.${env.BUILD_NUMBER}"
        AWS_REGION = "eu-central-1"
        TF_VAR_env_prefix = "${params.ENV_NAME}"
        AWS_ACCESS_KEY_ID = credentials('jenkins_aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('jenkins_aws_access_secret_key')
        KUBECONFIG = "${env.WORKSPACE}/kubeconfig"
    }

    stages {
        stage('Checkout Code') {
            steps {
                git branch: 'main', url: 'https://github.com/emrearabacioglu/devops-case.git'
            }
        }

        stage('Automated Tests (E2E Cypress)') {
            steps {
                // 1. MongoDB'yi ayağa kaldır
                sh 'docker compose up -d mongodb'
 
                // 2. sleep yerine gerçek hazır-olma kontrolü: Mongo ping cevap verene kadar bekle
                sh '''
                echo "MongoDB hazir olmasi bekleniyor..."
                for i in $(seq 1 30); do
                  if docker compose exec -T mongodb mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
                    echo "MongoDB hazir."
                    break
                  fi
                  echo "MongoDB bekleniyor ($i/30)..."
                  sleep 2
                done
                '''
 
                // 3. MongoDB hazır olduktan sonra Backend'i kaldır
                sh 'docker compose up -d backend'
 
                // 4. sleep yerine: backend gercekten istek cevaplayana kadar bekle
                //    NOT: /record kendi API'nizdeki gercek list/health endpoint'i ile
                //    ayni degilse burayi kendi endpoint'inize gore guncelleyin.
                sh '''
                echo "Backend hazir olmasi bekleniyor..."
                for i in $(seq 1 30); do
                  if curl -sf http://localhost:5050/record > /dev/null; then
                    echo "Backend hazir."
                    break
                  fi
                  echo "Backend bekleniyor ($i/30)..."
                  sleep 2
                done
                '''
 
                dir('mern-project/client') {
                    sh '''
                    cat > Dockerfile.test << 'EOF'
                    FROM cypress/included:12.12.0
                    WORKDIR /app
                    COPY . .
                    RUN npm install && npm install --no-save wait-on
 
                    # Cypress tarayicisinin Backend'i bulabilmesi icin adresi localhost yapiyoruz
                    ENV REACT_APP_API_URL=http://localhost:5050
 
                    # sleep 20 yerine: React dev server gercekten ayaga kalkana kadar bekle (wait-on)
                    ENTRYPOINT ["sh", "-c", "npm start & npx wait-on http://localhost:3000 -t 60000 && npx cypress run"]
                    EOF
 
                    docker build -t temp-cypress-test -f Dockerfile.test .
 
                    # Host agi kullanilarak localhost:5050'nin Jenkins uzerinden dogrudan Backend'e ulasmasi garanti ediliyor
                    docker run --rm --network host temp-cypress-test
                    '''
                }
            }
            post {
                always {
                    // Basarisizlik durumunda kok nedeni gormek icin loglari yakala
                    sh 'docker compose logs mongodb || true'
                    sh 'docker compose logs backend || true'
                    sh 'docker compose ps || true'
                    sh 'docker compose down -v || true'
                    sh 'docker rmi temp-cypress-test || true'
                }
            }
        }

        stage('Parallel Build & Push') {
            failFast true
            parallel {
                stage('Frontend Image') {
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                            sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                            sh "docker build -t ${APP_REPO}/devops_case-frontend:${IMAGE_TAG} ./mern-project/client"
                            sh "docker push ${APP_REPO}/devops_case-frontend:${IMAGE_TAG}"
                        }
                    }
                }
                stage('Backend Image') {
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                            sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                            sh "docker build -t ${APP_REPO}/devops_case-backend:${IMAGE_TAG} ./mern-project/server"
                            sh "docker push ${APP_REPO}/devops_case-backend:${IMAGE_TAG}"
                        }
                    }
                }
                stage('ETL Image') {
                    steps {
                        withCredentials([usernamePassword(credentialsId: 'docker-hub-repo', passwordVariable: 'DOCKER_PASS', usernameVariable: 'DOCKER_USER')]) {
                            sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                            sh "docker build -t ${APP_REPO}/devops_case-etl:${IMAGE_TAG} ./python-project"
                            sh "docker push ${APP_REPO}/devops_case-etl:${IMAGE_TAG}"
                        }
                    }
                }
            }
        }

        stage('Provision Infrastructure') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform apply -auto-approve'
                    script {
                        env.EKS_CLUSTER_NAME = sh(script: "terraform output -raw eks_cluster_name", returnStdout: true).trim()
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh "aws eks update-kubeconfig --region ${AWS_REGION} --name ${EKS_CLUSTER_NAME}"
                
                sh "helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx"
                sh "helm repo update"
                sh "helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-basic --create-namespace --wait"

                sh "helm upgrade --install mern-${params.ENV_NAME} ./mern-stack-chart --namespace ${params.ENV_NAME} --create-namespace -f ./mern-stack-chart/values-${params.ENV_NAME}.yaml --set frontend.image.tag=${IMAGE_TAG} --set backend.image.tag=${IMAGE_TAG} --set etl.image.tag=${IMAGE_TAG} --wait --atomic --timeout 5m"
            }
        }

        stage('Smoke Test (Verify Deployment)') {
            steps {
                sh "kubectl rollout status deployment/mern-${params.ENV_NAME}-frontend -n ${params.ENV_NAME} --timeout=120s"
                sh "kubectl rollout status deployment/mern-${params.ENV_NAME}-backend -n ${params.ENV_NAME} --timeout=120s"
                sh "kubectl get pods -n ${params.ENV_NAME} -l app.kubernetes.io/instance=mern-${params.ENV_NAME}"
            }
        }
    }
    
    post {
        success {
            echo "CI/CD Pipeline finised successfully. App is live on ${params.ENV_NAME} environment."
        }
        failure {
            echo "Pipeline error! check Jenkins logs."
        }
    }
}