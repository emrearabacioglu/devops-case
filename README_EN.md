# 2NTECH DevOps Technical Case

For case requirements, submission scope, and assessment details, read **`DevOps_Technical_Case_EN.docx`**.

> The starter applications intentionally contain production-readiness issues. Existing behavior in the application code must not be assumed to be correct. The candidate is expected to analyze and prioritize critical issues, implement the necessary improvements, and document the decisions made.

## Project structure

- `mern-project/`: Starter application with a React frontend, Express.js backend, and MongoDB
- `python-project/`: Starter Python ETL workload and its limited ETL requirements
- `DevOps_Technical_Case_EN.docx`: Main English case document
- `CASE_END_ANSWERS.md`: Template containing the questions that must be answered at submission time
- `SUBMISSION_EVIDENCE.md`: Required screenshot and runtime-evidence template
- `docs/backup-restore.md`: Backup and restore runbook template (to be filled in by the candidate)
- `docs/screenshots/`: Directory for submission screenshots

## Environment options

The solution may run in a public cloud or on a Linux virtual machine provisioned by the candidate. Cloud usage is not mandatory. A Kubernetes distribution such as k3s, MicroK8s, or kubeadm may be installed on the VM.

## Core functional expectations

- The main user flows and API functions of the MERN application must work.
- The Python ETL must automatically retrieve repository information from the GitHub API and write it to MongoDB.
- When the same repository is retrieved in later ETL runs, a new record must not be created; the existing record must be updated using a unique repository identifier.
- The Python ETL must run once per hour.
- A backup and restore approach must be implemented for the MongoDB data; creating a record, taking a backup, deleting the data, restoring from the backup, and verifying that the data is back must be executed end to end and evidenced.
- Setup, deployment, rollback, backup/restore, and cleanup steps must be documented in the repository.
- Real credentials or secrets must not be stored in the repository.
- Required screenshots of the running system must be stored under `docs/screenshots/` and explained in `SUBMISSION_EVIDENCE.md`.

Detailed core criteria, advanced criteria, submission evidence, and final case questions are included in the Word document.

---

# Candidate Solution — Emre Arabacıoğlu

Target environment: **AWS EKS**. Infrastructure is managed with Terraform, the application with Helm, and deployment with a Jenkins pipeline.

## Solution components

| Directory / file | Contents |
| --- | --- |
| `terraform/` | Local modules for VPC and EKS; state kept encrypted in an S3 backend |
| `mern-stack-chart/` | Helm chart for the frontend, backend, MongoDB, ETL and Ingress; environment-specific values files |
| `Jenkinsfile` | Parallel image build/push → `terraform apply` → `helm upgrade` → smoke test → Cypress E2E → automatic rollback on failure |
| `docker-compose.yml` | Brings the whole stack up locally |
| `scripts/` | `mongo-backup.sh`, `mongo-restore.sh` |
| `k8s/backup/` | Daily MongoDB backup CronJob and its backup PVC |
| `monitoring/` | Prometheus Operator `PrometheusRule` alert definitions |
| `docs/` | Architecture diagram, findings, alerting and backup/restore runbooks |

## Documentation

| File | Contents |
| --- | --- |
| `CASE_END_ANSWERS.md` | Answers to the final case questions, rationale for the technical decisions, items left out of scope and known technical debt |
| `SUBMISSION_EVIDENCE.md` | Screenshots and runtime evidence |
| `docs/architecture.md` | Mermaid architecture diagram, external access points, request and deployment flows |
| `docs/findings.md` | Findings in the starter projects, prioritization criteria and the fixes applied |
| `docs/alerting.md` | Logging/alerting runbook; alert thresholds and response steps |
| `docs/backup-restore.md` | Backup/restore runbook, RPO/RTO targets, verification and limitations |

## Running locally

```bash
# Full stack (frontend, backend, MongoDB, ETL)
docker compose up --build

# Frontend: http://localhost:8080
# Backend : http://localhost:5050/record
```

## Provisioning and deploying on AWS

The whole deployment runs through the Jenkins pipeline by selecting the `ENV_NAME` parameter (`dev` / `test` / `prod`). The pipeline, in order:

1. Checks out the repository.
2. Builds the frontend, backend and ETL images in parallel and pushes them to Docker Hub with the `v1.0.<BUILD_NUMBER>` tag.
3. Provisions the VPC and EKS cluster of the selected environment with `terraform apply`.
4. Fetches the kubeconfig with `aws eks update-kubeconfig` and installs the NGINX Ingress Controller.
5. Deploys the application with `helm upgrade --install --wait --atomic --timeout 10m`.
6. Runs a smoke test with `kubectl rollout status`, followed by a Cypress E2E test through the ELB address.

The same steps manually:

```bash
# Infrastructure (terraform.tfvars is required and is not committed)
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --region eu-central-1 --name $(terraform output -raw eks_cluster_name)

# Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-basic --create-namespace --wait

# Application
helm upgrade --install mern-dev ./mern-stack-chart \
  --namespace dev --create-namespace \
  -f ./mern-stack-chart/values-dev.yaml \
  --wait --atomic --timeout 10m

# Application address
kubectl get svc ingress-nginx-controller -n ingress-basic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Rollback

```bash
helm history mern-dev -n dev                  # release history
helm rollback mern-dev -n dev --wait          # roll back to the previous release
helm rollback mern-dev <REVISION> -n dev      # roll back to a specific revision
kubectl rollout status deployment/mern-dev-backend -n dev
```

In the pipeline, rollback is automatic at two points: `helm upgrade --atomic` reverts the release on a failed deployment, and if the Cypress E2E stage fails, the `helm rollback` in the `post.failure` block is triggered. Details: `CASE_END_ANSWERS.md` Question 11.

## Backup / Restore

```bash
./scripts/mongo-backup.sh                                             # take a backup
./scripts/mongo-restore.sh ./backups/mongodb-<timestamp>.archive.gz   # restore
kubectl apply -f k8s/backup/mongodb-backup-cronjob.yaml               # daily automatic backup
```

Runbook, RPO/RTO targets, verification steps and known limitations: `docs/backup-restore.md`.

## Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace --wait
kubectl apply -f monitoring/prometheus-rules.yaml
```

Alert definitions, threshold rationales and response steps: `docs/alerting.md`.

## Cleanup

To make sure no resources keep incurring charges, in order:

```bash
# 1. Application release
helm uninstall mern-dev -n dev

# 2. StatefulSet PVCs are not removed by Helm and must be deleted explicitly
kubectl delete pvc -n dev -l app=mern-dev-mongodb
kubectl delete pvc mongodb-backup -n dev          # backup PVC (destroys the backups)
kubectl delete -f k8s/backup/mongodb-backup-cronjob.yaml

# 3. Namespace
kubectl delete namespace dev

# 4. Monitoring (if installed)
helm uninstall monitoring -n monitoring && kubectl delete namespace monitoring

# 5. Ingress Controller — must be removed BEFORE terraform destroy so the ELB is deleted
helm uninstall ingress-nginx -n ingress-basic
kubectl delete namespace ingress-basic

# 6. Infrastructure
cd terraform && terraform destroy

# 7. Verify in the AWS console: EC2 > Load Balancers and EBS > Volumes should be empty
```

> **Important:** The ELB created by the NGINX Ingress Controller and the EBS volumes created by the StatefulSet are managed by Kubernetes and therefore do not appear in the Terraform state. If they are not removed before `terraform destroy`, the destroy will hang on VPC dependencies and the orphaned resources will keep incurring charges.
