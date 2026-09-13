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

        stage('E2E Test (Cypress)') {
            steps {
                script {
                    env.APP_URL = sh(
                        script: "kubectl get svc ingress-nginx-controller -n ingress-basic -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'",
                        returnStdout: true
                    ).trim()
                    echo "E2E target: http://${env.APP_URL}"
                }

                sh """
                    echo "Waiting for LoadBalancer DNS propagation..."
                    for i in \$(seq 1 40); do
                      if curl -sfo /dev/null --max-time 5 http://${env.APP_URL}/ ; then
                        echo "Application is reachable."; exit 0
                      fi
                      echo "attempt \$i - not ready yet"; sleep 15
                    done
                    echo "Application did not become reachable in time."; exit 1
                """

                sh "docker build -t devops-case-e2e:${IMAGE_TAG} -f ./mern-project/client/Dockerfile.e2e ./mern-project/client"

                sh """
                    docker run --name e2e-${BUILD_NUMBER} --ipc=host \\
                      -e CYPRESS_baseUrl=http://${env.APP_URL} \\
                      devops-case-e2e:${IMAGE_TAG}
                """
            }
            post {
                always {
                    sh """
                        mkdir -p cypress-results
                        docker cp e2e-${BUILD_NUMBER}:/e2e/cypress/videos      ./cypress-results/ || true
                        docker cp e2e-${BUILD_NUMBER}:/e2e/cypress/screenshots ./cypress-results/ || true
                        docker rm -f e2e-${BUILD_NUMBER} || true
                        docker rmi devops-case-e2e:${IMAGE_TAG} || true
                    """
                    archiveArtifacts artifacts: 'cypress-results/**', allowEmptyArchive: true
                }
                failure {
                    sh "helm rollback mern-${params.ENV_NAME} -n ${params.ENV_NAME} --wait --timeout 5m || echo 'rollback skipped'"
                }
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