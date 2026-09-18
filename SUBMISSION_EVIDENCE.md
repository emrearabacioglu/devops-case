# SUBMISSION EVIDENCE

For the submission to be considered complete, add screenshots of the running system to the `docs/screenshots/` directory and specify the related file path under each item below.

Screenshots must not expose real credentials, tokens, passwords, private keys, or sensitive connection details.

## 1. Web Application

### 1.1 Home page

- **Screenshot:** `docs/screenshots/01-web-home.png`
- **Explanation:** The MERN application was reached through the LoadBalancer address of the NGINX Ingress Controller running on AWS, and the home page was displayed.

### 1.2 Create operation

- **Form screenshot:** `docs/screenshots/02-record-create-form.png`
- **Successful result screenshot:** `docs/screenshots/03-record-created.png`
- **Explanation:** A new record was created through the Create Record form. The request followed the Ingress → backend (`/record`) → MongoDB path, and the record was verified to appear on the Record List page.

### 1.3 Edit operation

- **Before-edit screenshot:** `docs/screenshots/04-record-edit-before.png`
- **After-edit screenshot:** `docs/screenshots/05-record-edit-after.png`
- **Explanation:** An existing record was updated from the Edit screen. After the `PATCH /record/:id` request, the change was confirmed both in the list view and in the database.

## 2. Docker

- **Image build screenshot:** `docs/screenshots/06-docker-build-and-containers.png`
- **Running containers screenshot:** `docs/screenshots/06-docker-build-and-containers.png`
- **Explanation:** From the `Parallel Build & Push` stage of the Jenkins pipeline: the frontend, backend and ETL images are built concurrently and pushed to Docker Hub with the `v1.0.<BUILD_NUMBER>` tag. The same screenshot shows the resulting images and containers.

## 3. Kubernetes

- **Pod/workload status:** `docs/screenshots/07-kubernetes-workloads.png`
- **Service and Ingress status, where applicable:** `docs/screenshots/08-kubernetes-services-ingress.png`
- **ETL CronJob/Job status:** `docs/screenshots/09-etl-cronjob-job.png`
- **Explanation:** In the `dev` namespace the frontend and backend Deployments, the MongoDB StatefulSet and the ETL CronJob are `Running`/`Active`. The Service output confirms that the frontend, backend and MongoDB are all `ClusterIP` and that the only `LoadBalancer` entry belongs to the NGINX Ingress Controller in the `ingress-basic` namespace. The CronJob output shows the hourly schedule (`0 * * * *`) and the completed Job records.

## 4. Python ETL

### 4.1 Initial data load

Show that GitHub repository information was stored in MongoDB for the first time.

- **Screenshot or terminal output:** `docs/screenshots/10-etl-first-load.png`
- **Explanation:** On the first ETL run, 11 repositories fetched from the GitHub API were written to MongoDB. The `INSERTED` lines in the log output and the document count in the interface confirm each other.

### 4.2 Update of the same repository

Show that processing the same repository again did not create a duplicate and instead updated the existing record. Where possible, include both the repository count and the updated field in the same evidence.

- **Before (manual change):** `docs/screenshots/11-etl-update-without-duplicate-1.png`
- **After (update and terminal log):** `docs/screenshots/11-etl-update-without-duplicate-2.png`
- **Unique field used:** `github_id` (the repository `id` value returned by the GitHub API)
- **Explanation:** A field of one repository document was first modified by hand in the database, and the ETL was then run a second time. The log output contains `UPDATED existing repo ... (github_id=...)` for that repository, the total document count is unchanged, and the manually corrupted field is back to its original value. Together these three prove that reprocessing the same repository creates no new record and instead updates the existing one through `github_id`. See `CASE_END_ANSWERS.md` Question 15 for details.

## 5. CI/CD

- **Successful pipeline screenshot:** `docs/screenshots/12-cicd-pipeline-success.png`
- **Screenshot showing build/image/deployment stages:** `docs/screenshots/06-docker-build-and-containers.png`
- **Explanation:** A successful end-to-end run of the Jenkins pipeline: `Checkout` → parallel image build and push → infrastructure provisioning with `terraform apply` → deployment to EKS with `helm upgrade --install --wait --atomic` → `kubectl rollout status` smoke test → Cypress E2E test through the ELB. If the E2E stage fails, the `helm rollback` in the `post.failure` block is triggered.

## 6. Backup and Restore

All six steps below must be evidenced. It must be clear that the steps were performed in order and on the same record.

### 6.1 Record creation

- **Screenshot:** `docs/screenshots/13-backup-record-created.png`
- **Explanation:** A `BackupTest` record was created from the interface and displayed on the Record List page.

### 6.2 Taking the backup

- **Screenshot or terminal output:** `docs/screenshots/14-backup-taken.png`
- **Method and command used:** `./scripts/mongo-backup.sh` → `kubectl exec -n dev mern-dev-mongodb-0 -- mongodump --archive --gzip`
- **Backup storage location:** `backups/mongodb-<timestamp>.archive.gz` on the operator machine; scheduled backups on the `mongodb-backup` PVC in the `dev` namespace.
- **Explanation:** The output shows the backup file path, its size (4.0K) and the 7-day retention policy being applied.

### 6.3 Dropping the collection or database

- **Screenshot or terminal output:** `docs/screenshots/15-collection-dropped.png`
- **Explanation:** The `sample_training.records` collection was removed with `drop()`.

### 6.4 Showing that the data is gone

- **Interface screenshot:** `docs/screenshots/16-data-missing-after-drop.png`
- **Database output:** `docs/screenshots/16-data-missing-after-drop.png`
- **Explanation:** `records count: 0` in the database and an empty table in the interface, shown together in the same screenshot.

### 6.5 Restoring from the backup

- **Screenshot or terminal output:** `docs/screenshots/17-restore-executed.png`
- **Measured restore duration:** 0m1.490s (measured with `time ./scripts/mongo-restore.sh ...`)
- **Explanation:** `./scripts/mongo-restore.sh` was executed, running `mongorestore --archive --gzip --drop`. The `--drop` flag removes the target collection before restoring, so no duplicate records are produced.

### 6.6 Verifying that the data is back

- **Interface screenshot:** `docs/screenshots/18-data-restored-verified.png`
- **Database output:** `docs/screenshots/18-data-restored-verified.png`
- **Explanation:** The record count returned to its pre-backup value and the `BackupTest` record was displayed again in the interface. It was also confirmed that the application does not need to be restarted after a restore.

> The runbook, RPO/RTO targets, retention period and known limitations are documented in `docs/backup-restore.md`.

## 7. Logging, Monitoring, and Advanced Criteria

Add evidence for any implemented logging, monitoring, alerting, Helm, Terraform, security scanning, or other advanced criteria.

- **Screenshot (logging):** `docs/screenshots/19-monitoring-or-upper-criteria.png`
- **Explanation:** Log output of a manually triggered ETL CronJob run. The ETL's `print` calls were moved to the `logging` module; every line carries a timestamp, a log level and an `INSERTED`/`UPDATED` distinction per repository, followed by a summary line. This format is evidence both for the 12-factor logging approach (stdout/stderr) and for the no-duplicate claim in Question 15.
- **Alert definitions:** `monitoring/prometheus-rules.yaml` — four alerts defined as a Prometheus Operator `PrometheusRule` resource (`BackendUnavailable`, `MongoDBUnavailable`, `ETLJobFailed`, `ETLNoSuccessfulRun`). Threshold rationales, installation commands, an Alertmanager routing example and per-alert runbook steps are in `docs/alerting.md`. In this environment `kube-prometheus-stack` was installed manually rather than through the pipeline, and the Alertmanager receiver was not connected to a live Slack/PagerDuty target.
- **Helm:** `mern-stack-chart/` — environment-specific values files (`values-dev/test/prod.yaml`) and dynamic image tag injection in the pipeline with `--set *.image.tag=v1.0.<BUILD_NUMBER>`; automatic rollback with `--wait --atomic`.
- **Terraform:** `terraform/` — local `vpc` and `eks` modules, state encrypted in the S3 backend (`encrypt = true`), environment-based provisioning driven by the `ENV_NAME` parameter.

## 8. Additional Evidence

- **Written evidence:**
  - `docs/architecture.md` — architecture diagram in Mermaid format, external access points table and request/deployment flows (the file itself is the editable source).
  - `docs/findings.md` — issues identified in the starter projects, severity assessment and the fixes applied.
  - `docs/alerting.md` — logging and alerting runbook; per-alert response steps and items left out of scope.
  - `docs/backup-restore.md` — backup/restore runbook, RPO/RTO targets, verification method and known limitations.
- **Explanation:** The rationale behind the code and manifest decisions is documented in `CASE_END_ANSWERS.md`, with references to the relevant file paths. Items deliberately left out of scope and the known technical debt are listed explicitly in Question 3 and the Additional Notes section of the same file.
