# CASE END ANSWERS

Answer all questions below by relating them directly to your implementation.

Answers should be concise, specific, and detailed enough to explain your technical decisions. Where appropriate, reference the relevant source file, manifest, pipeline step, or document path.

---

## Candidate Information

- **Full name:** Emre Arabacıoğlu
- **Repository URL:** https://github.com/emrearabacioglu/devops-case
- **Completion date:** 13/09/2026
- **Target environment used:** Cloud (AWS EKS)

---

## 1. Architecture and Request Flow

Explain the architecture you implemented and the path a user request follows from the frontend through the backend to the database.

Also prepare an architecture diagram showing the system components, connections between components, traffic flow, and external access points, and add it to the project repository as one of the following:

- `docs/architecture.md`
- `docs/architecture.pdf`

The diagram may be created with Mermaid, Draw.io, Excalidraw, or a similar tool. Include the editable source file in the repository as well.

**Answer:**
The infrastructure is provisioned as an isolated environment on AWS following IaC principles, using local Terraform modules (`terraform/modules/vpc`, `terraform/modules/eks`). Worker nodes run in private subnets and egress through a single NAT Gateway. A request follows this path:

1. The user sends an HTTP request from the browser to an AWS Elastic Load Balancer (Classic LB), which is provisioned automatically by the `LoadBalancer` type Service of the NGINX Ingress Controller.
2. Traffic reaches the NGINX Ingress Controller pods inside EKS (`ingress-basic` namespace).
3. The Ingress (`mern-stack-chart/templates/ingress.yaml`) applies path-based routing: `/` goes to the frontend pods, `/record` and `/healthcheck` go to the backend pods.
4. Backend pods talk to MongoDB — which is closed to the outside world — over a ClusterIP Service (`ATLAS_URI=mongodb://<release>-mongodb:27017`). MongoDB data is persisted on a gp2 EBS volume through the StatefulSet's `volumeClaimTemplates` block.
5. The Python ETL runs hourly as a CronJob; it queries the GitHub API through the NAT Gateway and writes the retrieved data directly into MongoDB. In addition, a Helm hook Job (`templates/etl-hook.yaml`, `post-install,post-upgrade`) runs the same load once after install and after every upgrade.

For application traffic the ELB is the single entry point into the cluster; the frontend, backend and MongoDB Services are all of type `ClusterIP`. Besides that, the EKS control plane API endpoint is public for management purposes (`cluster_endpoint_public_access = true`); Jenkins issues its `helm upgrade` and `kubectl` calls through it. Restricting this second entry point with an IP allowlist is listed as technical debt in Question 14.

Deployment is performed through the Jenkins pipeline using Helm; images are pulled from Docker Hub.

*(The architecture diagram is provided in Mermaid format inside `docs/architecture.md`; the file itself is the editable source.)*

---

## 2. Critical Findings and Prioritization

What were the three most critical issues you identified in the starter projects? Which impact and risk criteria did you use to prioritize them?

**Answer:**
Prioritization was based on three criteria, in this order: **(a) user impact** — does the issue make the application unusable; **(b) impact on the container/Kubernetes lifecycle** — does it prevent the platform from managing the workload correctly; **(c) cost of the fix**. All findings and their resolutions are documented in `docs/findings.md`; the three most critical ones are below.

1. **Unhandled exception in the backend database connection (`mern-project/server/db/conn.mjs`) — High.** When the connection failed, the application crashed with an unhandled `TypeError` instead of exiting gracefully, which made the Kubernetes restart/backoff cycle unreliable. The `try-catch` block was reworked so that a connection failure is logged and the process exits in a controlled way via `process.exit(1)`, allowing the platform to interpret the pod state correctly.

2. **Hardcoded API URLs in the frontend (`recordList.js`, `create.js`, `edit.js`, `healthcheck.js`) — High.** The frontend called `http://localhost:5050` from the browser, which cannot resolve to the backend in a container or Kubernetes environment. All addresses were bound to the `process.env.REACT_APP_API_URL` environment variable, and an Ingress with path-based routing (`/record`, `/healthcheck`) was created so browser requests reach the backend.

3. **Hardcoded application port and database name (`server.mjs`, `db/conn.mjs`) — Medium/Low.** These prevented running the same image with a different port or database name across environments. They were made externally configurable through `process.env.PORT` and `process.env.DB_NAME`. Ranked third because on their own they do not take the service down.

---

## 3. Items Left Out of Scope

Which issues did you intentionally leave unresolved or out of scope? Explain the reasons for these decisions.

**Answer:**
The following were deliberately left out of scope for reasons of time, cost and case boundaries:

- **MongoDB Replica Set (High Availability).** The database runs as a single-replica `StatefulSet`. *Persistent storage is not out of scope and has been implemented:* a 5Gi PersistentVolumeClaim on gp2/EBS is attached through `volumeClaimTemplates`. Only the multi-replica Replica Set architecture and failover were left out.
- **MongoDB authentication.** The database runs without `--auth`. This was considered acceptable within the case because the Service is `ClusterIP` and closed to the outside world. It is not acceptable in production (see Questions 9 and 14).
- **Liveness/readiness probe definitions.** No probes were added to the Helm templates. Because the backend exits with `process.exit(1)` on a connection failure, the pod already becomes not-Ready and is removed from the Service endpoints, which was considered sufficient for the case; however, it is a weak choice in terms of controlled recovery (see Question 10).
- **HPA and autoscaling.** Not implemented, as it requires `metrics-server` and resource requests defined for all environments. The intended approach is described in Question 12.
- **HTTPS/TLS.** HTTPS on the Ingress via AWS Certificate Manager was skipped because no verifiable custom domain was available.
- **NetworkPolicy.** No rules restricting east-west pod traffic were written; currently any pod in the cluster can reach MongoDB.
- **Pod-level `securityContext`.** All images are built to run as non-root (see Question 14), but pod-level constraints such as `runAsNonRoot`, `allowPrivilegeEscalation: false` and `readOnlyRootFilesystem` were not added to the templates.
- **Centralized log collection and image security scanning.** Neither a log shipper (Fluent Bit/CloudWatch Logs or Loki) nor an image scanning step (for example Trivy) was added to the pipeline.
- **Monorepo decision.** In a real scenario each environment would have its own branch/repository and the Terraform code would live in a separate repository. For this case all components were kept in a single repository so the work can be reviewed as a whole; environment separation is handled through Helm values files and the `ENV_NAME` pipeline parameter instead of separate repositories.

---

## 4. Target Environment Selection

Why did you choose a cloud environment or a virtual machine? Which components or approaches would you use differently in a real production environment?

**Answer:**
AWS EKS (cloud) was chosen as the target environment. The main reason was to demonstrate Infrastructure as Code practices and Jenkins CI/CD automation under production-like conditions, and to make use of managed building blocks such as a managed control plane, persistent storage through the EBS CSI driver and native LoadBalancer integration. The `ENV_NAME` pipeline parameter feeds both `TF_VAR_env_prefix` for Terraform and the Helm values selection, so each environment comes up with its own VPC and EKS cluster: isolation is complete, at the cost of a higher bill.

What I would do differently in a real production environment:

- **The database would not run inside EKS.** Amazon DocumentDB or MongoDB Atlas would be used to hand off the operational burden (backups, patching, failover).
- **Frontend static assets would not be served from pods.** The build output would be uploaded to S3 and distributed through CloudFront, reducing both cost and latency.
- **Ingress layer.** ALB via the AWS Load Balancer Controller instead of a Classic LB, with TLS terminated on the ALB using an ACM certificate.
- **Image registry.** Amazon ECR instead of Docker Hub, for IAM integration and built-in image scanning.
- **Access.** The EKS API endpoint would be private (or IP-allowlisted), and pod access to AWS services would be granted through IRSA following least privilege.
- **Environment separation.** A separate AWS account and separate Terraform state/workspace per environment.

---

## 5. MongoDB Approach

Why did you choose your MongoDB deployment and service approach? Explain the alternatives you considered, along with their advantages, disadvantages, and operational trade-offs.

**Answer:**
MongoDB runs as a **`StatefulSet` with `volumeClaimTemplates` (gp2/EBS, 5Gi)** behind a **`ClusterIP` Service**, defined in `mern-stack-chart/templates/mongodb.yaml`.

**Workload choice.** A StatefulSet was chosen because it guarantees that a recreated pod deterministically reattaches to the same PVC, and because the pod identity stays stable (`mern-dev-mongodb-0`). That stability also pays off operationally: `scripts/mongo-backup.sh` and `scripts/mongo-restore.sh` can target the pod deterministically when taking or restoring a backup.

**Service choice.** There is no scenario in which MongoDB needs to be reached from outside the cluster, so `ClusterIP` was selected and NodePort/LoadBalancer were never considered. With a single replica there is no need for per-pod DNS records, so the Service was not made headless (`clusterIP: None`); once a Replica Set is introduced, the StatefulSet's governing service must be headless — this is a known piece of technical debt.

**Alternatives considered and trade-offs:**

| Alternative | Advantage | Disadvantage / why not chosen |
| --- | --- | --- |
| `Deployment` + a single PVC | Simpler template | On a ReadWriteOnce EBS volume, a rolling update makes two pods attempt to attach the same disk — a data integrity risk |
| Bitnami MongoDB Helm chart | Auth, Replica Set and a metrics exporter out of the box | The chart itself is an extra dependency and configuration surface; since the point of the case was to define Kubernetes objects deliberately, it was not used |
| Managed service (DocumentDB / Atlas) | Backup, failover and patching are delegated | Cost and vendor lock-in; it would also remove the "running a database on Kubernetes" dimension of the case. It is my production choice (see Question 4) |

**Image choice.** Instead of writing a dedicated Dockerfile, the official `mongo` image from Docker Hub was used. The advantage is that security patches and base configuration come ready; the trade-off is reduced flexibility for OS hardening, custom plugins or internal compliance requirements. Since this project targets standard CRUD operations, stability was preferred over configuration flexibility.

**Operational limits of the current approach:** with a single replica, losing the node makes the data unreachable (the data itself survives on the PVC, so there is no loss); authentication is disabled. These two gaps are the first items to close in production.

---

## 6. Helm or Manifest Management

If you used Helm, explain why you selected it and what problem it solves in this project.

Describe its advantages and the additional complexity it introduces compared with alternatives such as plain Kubernetes manifests or Kustomize.

If you did not use Helm, explain the method you selected and the reason for your choice.

**Answer:**
Helm was used to manage the Kubernetes objects (`mern-stack-chart/`).

**The problem it solves.** There are two axes: (1) environment differences — `values.yaml` holds the base values while `values-dev.yaml`, `values-test.yaml` and `values-prod.yaml` override only environment-specific differences such as replica counts and resource requests/limits; (2) values that change on every run — the image tag produced by Jenkins (`v1.0.${BUILD_NUMBER}`) is injected in the pipeline with `--set frontend.image.tag=... --set backend.image.tag=... --set etl.image.tag=...`. Neither manual manifest edits nor a copy of the manifests per environment is required.

**Additional advantages.** Idempotent install/upgrade with `--install`; automatic rollback of a failed release with `--wait --atomic --timeout 10m`; release history and one-command rollback with `helm history` / `helm rollback`; and binding the ETL's initial data load to the release lifecycle through a `post-install,post-upgrade` hook.

**Comparison with alternatives.** With plain manifests, environment separation could only be achieved by copying files, and a per-build image tag would require fragile `sed`/`envsubst` constructs. Kustomize offers a more readable environment separation through overlays without templating and has a gentler learning curve; however it has no concept of a release, no revision history and no automatic rollback semantics comparable to `--atomic` — injecting CI-provided dynamic values is possible with `kustomize edit set image`, but it gives no release-level integrity guarantee. The deciding factors in this case were `--atomic` and `helm rollback`, so Helm was chosen.

**The complexity it introduces.** Go template syntax reduces manifest readability and errors only surface at render time, so `helm template` / `--dry-run` verification becomes an extra step in the workflow. In addition, release state is stored as Secrets inside the cluster, which makes the cluster itself the source of truth; without GitOps (Argo CD/Flux) this creates a risk of drift between "what runs in the cluster" and "what is in the repository".

---

## 7. Kubernetes Service Types

Which criteria did you use to select Kubernetes Service types?

For each service, explain why you chose `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName`, or a headless Service. State which services should be accessible from outside the cluster and how you prevented unnecessary external exposure.

**Answer:**
The criterion was kept simple: *before a Service is exposed, the need for direct browser access to that component must be demonstrated.* No application component met that bar, so all of them were left as `ClusterIP` following least privilege.

| Service | Type | Reason |
| --- | --- | --- |
| Frontend | `ClusterIP` | Reachable from outside, but **not directly**; traffic arrives through the Ingress, so the Service itself does not need to be exposed. |
| Backend | `ClusterIP` | Likewise, the `/record` and `/healthcheck` paths are published through the Ingress. |
| MongoDB | `ClusterIP` | No scenario requires external access; only the backend, the ETL and the backup Job reach it. |
| NGINX Ingress Controller | `LoadBalancer` | The single application entry point of the cluster. On AWS it automatically provisions an ELB. |

**Considered but not used.** `NodePort` was rejected because it exposes node IPs and high ports directly to the internet, complicates security group management and provides no stable entry address. The chart keeps `NodePort` support for the frontend Service as a parameter (`values.yaml` → `frontend.service.nodePort`), but it is not enabled in any environment — all three values files use `ClusterIP`. `ExternalName` would only make sense to alias a service outside the cluster (for example a managed database); had we moved to a managed DB, the MongoDB Service would have become `ExternalName`. A **headless Service** (`clusterIP: None`) is meaningful when a StatefulSet needs a stable per-pod DNS record, that is, when Replica Set members must find each other by `<pod>.<service>`; that need does not exist with a single replica, so a standard `ClusterIP` was kept.

**Preventing unnecessary exposure.** For application traffic the ELB is the only public endpoint. Beyond that, the EKS control plane API endpoint is public for management purposes; this is a deliberate choice so that Jenkins can run `helm`/`kubectl` from outside the cluster, but it is not restricted with `public_access_cidrs` (see Question 14). East-west traffic inside the cluster is not restricted with NetworkPolicy (see Question 3).

---

## 8. Kubernetes Workload Types

Which criteria did you use to select workload types for the application components?

Explain why you used `Deployment`, `StatefulSet`, `Job`, `CronJob`, or another workload type for the frontend, backend, MongoDB, and ETL components.

Describe how you evaluated the following:

- Stateless or stateful behavior
- Persistent-storage requirements
- Pod identity and ordered-execution requirements
- Execution frequency
- Restart behavior
- Scalability requirements

**Answer:**

| Component | Workload | State model | Persistent storage | Pod identity | Frequency | Restart behavior | Scalability |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Frontend | `Deployment` | Stateless | None | Irrelevant | Continuous | `Always`, rolling update | Horizontal, replica count via values (prod: 3) |
| Backend | `Deployment` | Stateless | None | Irrelevant | Continuous | `Always`, rolling update | Horizontal, replica count via values (prod: 3) |
| MongoDB | `StatefulSet` | Stateful | **Yes** — `volumeClaimTemplates`, gp2/EBS 5Gi | **Required** — `mern-dev-mongodb-0` | Continuous | `Always`, ordered (`OrderedReady`) | Not scaled horizontally; single replica without a Replica Set |
| Python ETL | `CronJob` | Stateless, batch | None | Irrelevant | Hourly (`0 * * * *`) | `restartPolicy: OnFailure`, `backoffLimit: 2` | Not needed; `concurrencyPolicy: Forbid` guarantees a single run |
| ETL initial load | `Job` (Helm hook) | One-shot | None | Irrelevant | `post-install,post-upgrade` | `restartPolicy: Never` | — |

**Rationale:**

- **Frontend and backend** hold no local state — no sessions, no uploaded files. Pods are therefore interchangeable and can be replicated horizontally with a `Deployment`. No particular startup order is required, and rolling updates provide zero-downtime releases.
- **MongoDB** keeps its state on disk, so persistent storage and pod identity are the deciding criteria. `StatefulSet` + `volumeClaimTemplates` guarantees that a recreated pod reattaches to the same PVC — a `Deployment` provides no such guarantee. The stable pod name (the `-0` suffix) additionally lets the backup scripts target the pod deterministically.
- **The Python ETL** is not a process that must run continuously and consume resources; it is a batch job that fetches data from GitHub once an hour and exits. Hence `CronJob`. `concurrencyPolicy: Forbid` prevents a new run from starting before the previous one finishes, which also removes the race condition in the ETL's upsert logic (see Question 15). On failure, `backoffLimit: 2` bounds the retries instead of looping indefinitely.
- **The initial data load at install time** uses a one-shot `Job` through a Helm `post-install,post-upgrade` hook, so we do not have to wait for the CronJob's first trigger (up to an hour in the worst case) and the data is fresh after every release.

---

## 9. Configuration and Secret Management

How did you manage application configuration and secrets?

**Answer:**
Configuration and secrets were handled in two separate layers.

**Application configuration.** All connection addresses and environment-dependent values (`PORT`, `DB_NAME`, `ATLAS_URI`, `REACT_APP_API_URL`) were removed from the code and moved to environment variables. Runtime values are supplied through the `env` block of the Deployments/CronJobs in the Helm templates; `ATLAS_URI` is derived from the release name (`mongodb://{{ .Release.Name }}-mongodb:27017`), so the same chart works in different namespaces and environments without manual edits. On the frontend side, React variables are baked in at build time, so `REACT_APP_API_URL` is taken as an `ARG`/`ENV` in the Dockerfile — it is deliberately treated as a different class of value because it cannot be changed at runtime.

**Secrets.** In this solution the real secrets live in the CI layer and are managed with Jenkins Credentials: the AWS access keys (`jenkins_aws_access_key_id`, `jenkins_aws_access_secret_key`) and the Docker Hub credentials (`docker-hub-repo`) are not embedded in the Jenkinsfile but injected through `credentials()` and `withCredentials`; Docker login uses `--password-stdin`, so the password never reaches the build log. On the repository side, `.dockerignore` keeps `.env` files out of the build context and `.gitignore` keeps `*.tfvars` and `*.tfstate` out of version control; Terraform state is stored encrypted in the S3 backend (`encrypt = true`). The repository contains no real credentials.

**An honest boundary:** no Kubernetes `Secret` or `ConfigMap` resource is defined. The reason is that MongoDB runs with authentication disabled in this environment and its Service is `ClusterIP`, closed to the outside world — therefore the application carries no credential at all; `ATLAS_URI` is a non-sensitive service address supplied as a plain `env` value. This is unacceptable in production: MongoDB would run with `--auth`, the connection URI containing the username/password would be stored in a Kubernetes `Secret` and mounted into the pod through `envFrom.secretRef`. One step further, secrets would be kept in AWS Secrets Manager and synchronized into the cluster through the External Secrets Operator using IRSA, so that the secret never comes near Git or the pipeline log.

When a secret value is changed or rotated, how would you ensure that the application securely starts using the new value?

**Answer:**
Rotating a secret does not require rebuilding the image; the configuration has to be updated and the pods have to read the new value. The behavior depends on how the value is delivered to the pod:

- **Supplied via `env`/`envFrom`,** the value is read once at container start; even if the Secret is updated, a running pod keeps using the old value. In that case a rolling restart with `kubectl rollout restart deployment/<name>` is required — with more than one replica this causes no downtime.
- **Mounted as a volume,** the kubelet refreshes the file shortly after the change, but the application must re-read it; if it does not support that, a restart is still required.
- **For automation,** a `checksum/secret` annotation carrying the hash of the Secret is added to the Deployment (with Helm, `{{ include ... | sha256sum }}`); when the Secret changes, the pod template hash changes too and Kubernetes starts a rolling update by itself. A controller such as Reloader does the same job.
- **The rotation order matters:** the new credential is created while the old one is still valid (overlap), pods are restarted with the new value, and only after verification is the old credential revoked. This way no pod ever runs with an invalid credential during rotation.

The exception is build-time values such as `REACT_APP_API_URL`: they are part of the image, so changing them requires a rebuild and a deployment with a new image tag. For that reason secrets must never be placed in such values.

---

## 10. MongoDB Availability Failure

If MongoDB becomes unavailable, how will the backend application, readiness/liveness checks, and user requests behave?

What measures did you take, or would you take, to reduce user impact and allow the service to recover in a controlled manner?

**Answer:**

**Current behavior.** `db/conn.mjs` establishes the connection at module import time. If MongoDB is unreachable, the `try-catch` added during the analysis now takes over instead of the starter project's unhandled exception: the error is logged and the process exits in a controlled way with `process.exit(1)`. Kubernetes sees this as a container exit, restarts it because of `restartPolicy: Always`, and moves the pod into `CrashLoopBackOff` as the failures repeat. Since the pod is not `Ready`, it is removed from the Service endpoints and the Ingress stops routing traffic to it. If all backend replicas are in that state, the user receives HTTP 502/503 from the Ingress; the frontend is served statically, so the page still loads but the record list comes back empty.

**Probe status — an honest observation.** No `readinessProbe`/`livenessProbe` definitions were added to the Helm templates (see Question 3). The behavior above is not produced by probes but by the process terminating itself. It achieves "the pod receives no traffic", but it is not ideal for controlled recovery: because the process cannot stay alive, the `/healthcheck` endpoint cannot respond either, and as the backoff interval grows, recovery is delayed once MongoDB returns.

**Measures to take (production approach):**

1. **Decouple the connection from module import and retry with exponential backoff.** The application stays up, `/healthcheck` keeps responding, and only the DB-dependent endpoints return errors.
2. **Bind the readiness probe to the DB state.** `/healthcheck` also performs a DB ping; while the DB is down the pod becomes `NotReady` and leaves the endpoints — *without being restarted*. The liveness probe only checks process health, so a transient DB outage does not cause a pointless restart loop.
3. **Reduce user impact.** A meaningful error page at the Ingress level through `custom-http-errors`; retries and a "service temporarily unavailable" message on the frontend; backpressure where write requests would otherwise have to be queued.
4. **Reduce the root cause.** Automatic failover with a MongoDB Replica Set, a PodDisruptionBudget so that not all replicas go down during maintenance, and the `MongoDBUnavailable` alert (`monitoring/prometheus-rules.yaml`) notifying on-call within two minutes.

---

## 11. Faulty Deployment and Rollback

How would you detect a faulty deployment?

Which method would you use to roll it back, and how would you verify that the previous working version has been restored safely?

**Answer:**

**Detection — three layers.** The Jenkins pipeline catches a faulty release at three consecutive points:

1. **`Deploy to EKS`** — `helm upgrade --install ... --wait --atomic --timeout 10m`. If the pods do not become ready within 10 minutes (ImagePullBackOff, CrashLoopBackOff, insufficient resources, and so on), Helm treats the release as failed.
2. **`Smoke Test`** — `kubectl rollout status deployment/... --timeout=120s` independently verifies that the frontend and backend rollouts completed.
3. **`E2E Test (Cypress)`** — a real user flow is executed through the ELB address: the home page loads, a record is created via `/create`, the record is verified through the `/record/` API, and its presence on the Record List page is checked. This layer catches cases where the deployment looks healthy but the application is functionally broken (a wrong API address, a broken route).

**Rollback.** At the first layer the rollback is automatic: `--atomic` returns the release to the previous working revision when the upgrade fails. At the third layer, the `post { failure { ... } }` block of the E2E stage runs `helm rollback mern-<env> -n <env> --wait --timeout 5m`; the Cypress videos and screenshots are uploaded to Jenkins with `archiveArtifacts`, so the evidence needed for root cause analysis is not lost with the rollback.

**Verification.** After a rollback, the safe restoration of the previous version is verified as follows:

- `helm history mern-<env> -n <env>` → the target revision is in the `deployed` state.
- `kubectl rollout status deployment/... -n <env>` → all replicas are current and ready.
- `kubectl get pods -n <env> -o jsonpath='{..image}'` → the running image tag is the expected previous `v1.0.<BUILD_NUMBER>`.
- The smoke and E2E stages are re-run for functional verification, and the alerts described in `docs/alerting.md` are confirmed to have cleared.

**Known risk.** The ETL Job is defined as a `post-upgrade` hook; if the hook fails for a purely external reason such as a GitHub API rate limit, `--atomic` may roll back an otherwise healthy deployment. In production the hook should be decoupled from the release success criteria (an independent Job, or a review of the `hook-failed` policy).

---

## 12. Scalability and Bottlenecks

If traffic increases tenfold, where do you expect the first bottleneck to occur?

Which components would you scale, and based on which metrics and thresholds? Explain how you would evaluate database connections, resource usage, and dependent services.

**Answer:**

**First bottleneck.** In the current architecture I would expect the first bottleneck at **MongoDB**, because it is the only component that is single-replica and cannot be scaled horizontally; on top of that the disk type is gp2, where IOPS scales with volume size. The **Node.js backend process** comes next: once the single-threaded event loop saturates the CPU, latency increases and the MongoDB connection pool (driver default of 100 connections) starts to run out. The frontend is last in line since it only serves static content.

**Scaling plan (not implemented in this solution; this is how it would be done):**

- **Prerequisites:** installing `metrics-server` and defining CPU/memory `requests` for *all* environments. Today requests/limits exist only in `values-test.yaml` and `values-prod.yaml`; because `values.yaml` and `values-dev.yaml` use `resources: {}`, percentage-based HPA cannot work in the dev environment.
- **Backend:** HPA with `minReplicas: 3`, `maxReplicas: 20`, target CPU utilization **70%**. 70% is chosen because a new pod takes roughly 30 seconds to become ready; scaling at 90% is scaling too late. A better approach is to move to a custom metric such as p95 latency or queue depth.
- **Frontend:** HPA at 70% CPU; in practice it will not be the bottleneck since it serves static content — the real fix is moving it to S3 + CloudFront.
- **Node layer:** Cluster Autoscaler or Karpenter; nodes are added once pods start staying `Pending`.
- **Database:** a MongoDB Replica Set for read load, with `readPreference=secondaryPreferred` in the driver to distribute reads across secondaries; if write load grows, sharding or a move to a managed service (DocumentDB/Atlas) would be evaluated. On the connection side, `maxPoolSize` multiplied by the backend replica count must be verified not to exceed the server's connection limit.

**Metrics and thresholds to watch:**

| Metric | Threshold | Action |
| --- | --- | --- |
| Backend CPU utilization | 70% | Add pods via HPA |
| HTTP p95 latency | > 500 ms | Scale out and profile |
| HTTP 5xx rate | > 1% | Alert, consider rollback |
| MongoDB active connections / pool | > 80% | Review pool size and replica count |
| MongoDB disk IOPS / queue depth | Sustained saturation | Move to gp3, raise IOPS |
| Pod `Pending` duration | > 1 min | Scale the node group |

On the dependent-services side, the GitHub API rate limit (60 requests/hour unauthenticated) is a fragility; it is unaffected by traffic growth, but if the ETL frequency is increased, authenticating with a token becomes mandatory.

---

## 13. Logging, Monitoring, and Alerting

Which logs, metrics, and alerts did you create?

During an incident, which dashboards, logs, metrics, or alert records would you examine first to diagnose the problem?

**Answer:**

**Logs.** In line with 12-factor principles, all components write to stdout/stderr; nothing is written to files inside the container. Logs can therefore be read with `kubectl logs` and later shipped to a central collector (Fluent Bit → CloudWatch Logs / Loki). I moved the ETL's `print` calls to the `logging` module, adding a timestamp, a log level and an `INSERTED`/`UPDATED` distinction per repository; I also added `raise_for_status()` so that API errors terminate the process with a non-zero exit code and the Job is marked `Failed` — a precondition for the ETL alerts to work at all.

**Metrics and alerts.** Four alerts are defined in `monitoring/prometheus-rules.yaml` as a Prometheus Operator `PrometheusRule` resource:

| Alert | Condition | For | Severity |
| --- | --- | --- | --- |
| `BackendUnavailable` | Available backend replicas = 0 | 2 m | critical |
| `MongoDBUnavailable` | MongoDB pod not Ready / absent | 2 m | critical |
| `ETLJobFailed` | ETL Job finished with an error | 1 m | warning |
| `ETLNoSuccessfulRun` | No successful ETL run for 2 hours | 10 m | warning |

Threshold rationales and a per-alert runbook are in `docs/alerting.md`. **Scope boundary:** `kube-prometheus-stack` was installed manually with the commands in `docs/alerting.md` rather than as part of the pipeline; Alertmanager's Slack/PagerDuty receiver was not connected to a live target, so the routing configuration is left in the repository in a runnable form.

**Order of investigation during an incident.** I first look at which alert fired, because that points directly at the layer: if MongoDB and the backend are firing together, the root cause is in the database; if only the backend is firing, it is in the application or the last deployment. Next come `kubectl get pods` for the state, `kubectl describe pod` for the events (OOMKilled, ImagePullBackOff, insufficient resources) and `kubectl logs --previous` for the final lines before the crash. If the alert time coincides with the last Jenkins deployment, I bring the service back with `helm rollback` before diagnosing and perform the root cause analysis afterwards — stopping user impact comes before diagnosis.

---

## 14. Security Risks

What are the three most important security risks in your solution?

Explain the controls you implemented, or would implement in production, to reduce these risks.

**Answer:**

1. **MongoDB running without authentication.** This is the most important risk in the solution: because the database runs without `--auth`, *any* pod in the cluster can read from and write to `mongodb://mern-dev-mongodb:27017` without restriction. **Controls in place:** the Service is `ClusterIP` and is never exposed outside the cluster; taking a backup requires `kubectl exec` permission, that is, a Kubernetes RBAC grant. **In production:** authentication would be enabled, the connection URI stored in a Kubernetes `Secret` (ideally through the External Secrets Operator with AWS Secrets Manager), a `NetworkPolicy` would allow only the backend and ETL pods to reach port 27017, and at-rest encryption (KMS-encrypted EBS) would be enabled.

2. **Container and pod-level privileges.** Containers running as root by default. **Controls in place:** all three images are built to run as non-root — `useradd etluser` + `USER etluser` for the ETL, `USER node` for the backend, and the `nginxinc/nginx-unprivileged` base image for the frontend (port 8080, no root required). **What is missing:** no pod-level `securityContext` is defined. In production I would add `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true` and `capabilities.drop: [ALL]`, move Pod Security Admission to the `restricted` level, and add a Trivy image-scanning step to the pipeline.

3. **Control plane and IaC state security.** The EKS control plane API endpoint is public (`cluster_endpoint_public_access = true`) and is not restricted with `public_access_cidrs`; in addition, `enable_cluster_creator_admin_permissions = true` grants admin rights to the identity that created the cluster. On the Terraform side the S3 backend is encrypted (`encrypt = true`) and `.gitignore` keeps state/tfvars files out of the repository; however, **state locking (a DynamoDB table / lockfile) is not configured**, which risks state corruption on concurrent `apply` runs. **In production:** a private endpoint or IP allowlist, least-privilege service accounts through IRSA, human access granted through SSO with temporary roles, and a DynamoDB lock plus S3 versioning and object lock for the state.

---

## 15. Python ETL Record Update Behavior

When the Python ETL receives the same repository information again, how does it find and update the existing record?

Which field did you use as the unique record key, and which screenshot or output demonstrates that no duplicate was created?

**Answer:**
The ETL script (`python-project/ETL.py`) takes the original `id` value from the JSON returned by the GitHub API, stores it in a `github_id` field in MongoDB, and uses that field as the record's unique business key. `id` was chosen over `name` or `html_url` because a repository rename changes the name and the URL while the `id` stays the same — matching on the name would have created a duplicate for every renamed repository.

The database operation is:

```python
filter_query = {"github_id": repo["id"]}
update_data = {"$set": {"github_id": repo["id"], "name": repo["name"], "url": repo["html_url"]}}
result = collection.update_one(filter_query, update_data, upsert=True)
```

Thanks to `upsert=True`, MongoDB first looks for a document matching `github_id`; if none exists it inserts a new document, and if one does exist it updates that document's fields with `$set`. The distinction is read from `result.upserted_id` and written to the log as `INSERTED` / `UPDATED`, with a summary line at the end of the run.

**An honest technical note:** uniqueness is currently enforced by the application's upsert logic, not by a unique index at the database level. In theory, two concurrent ETL runs could produce a race condition; in practice this is prevented by `concurrencyPolicy: Forbid` on the CronJob. The lasting fix is to add `collection.create_index("github_id", unique=True)` and delegate uniqueness to a database constraint — an item planned for the next iteration.

Evidence that no duplicate is created and that the update succeeds is provided in section 4.2 of `SUBMISSION_EVIDENCE.md`:

- `docs/screenshots/11-etl-update-without-duplicate-1.png` — a record's field being changed manually in the interface
- `docs/screenshots/11-etl-update-without-duplicate-2.png` — the log output after the second run (`UPDATED existing repo ...`) and the corrected value in the interface; the total document count is unchanged

---

## 16. Backup and Restore Approach

Which backup method and storage location did you choose for MongoDB?

What are your backup frequency, retention period, RPO, and RTO targets, and what was the actual restore duration you measured?

How would you verify that a backup is not corrupted or incomplete, and how would you change this approach in a real production environment?

Provide your runbook in `docs/backup-restore.md` and reference the evidence from `SUBMISSION_EVIDENCE.md`.

**Answer:**

**Method and location.** MongoDB is backed up with `mongodump` into a single compressed archive (`--archive --gzip`); a single file is easy to move and to verify. Backups are taken in two ways: manually by the operator with `scripts/mongo-backup.sh`, and automatically inside the cluster every day at 02:00 UTC with `k8s/backup/mongodb-backup-cronjob.yaml`. Manual backups are stored in the `backups/` directory on the operator's machine (listed in `.gitignore`, never committed); scheduled backups are stored on the `mongodb-backup` PersistentVolumeClaim (5Gi, gp2/EBS) in the `dev` namespace. The scope is the entire `sample_training` database; application data (`records`) and ETL data (`github_repos`) are in the same archive.

**Frequency, retention, targets.** Scheduled backups run daily with a retention period of 7 days; both the script and the CronJob remove older archives with `find -mtime +7 -delete` on every run. The RPO target is 24 hours (daily full backup) and the RTO target is 15 minutes. The actual restore duration measured in the end-to-end scenario was **0m1.490s** (archive size 4.0K), well below the target because the current data volume is small — the RTO target should be re-measured as the data grows.

**Verification.** Backup integrity is checked in two stages: before restoring, the archive is read without touching the data using `mongorestore --archive --gzip --dryRun --verbose` — a corrupt or truncated archive fails at this point; after restoring, the `countDocuments()` result is compared with the pre-backup value and the records are observed to render completely in the interface. The `--dryRun` step is deliberately not embedded in the restore script; it is defined in the runbook (`docs/backup-restore.md` §5) as a separate step the operator runs before the restore.

**What I would change in production.** Backups would be shipped outside the cluster to an S3 bucket with versioning and object lock enabled, and moved to Glacier through a lifecycle rule; they would be encrypted with KMS and accessed through a dedicated IAM role scoped only to backup operations. RPO would be reduced to minutes using an oplog backup (`mongodump --oplog`) or a managed service (DocumentDB/Atlas continuous backup). Restore verification would be automated with a daily Job that restores the latest backup into a disposable environment, checks the record count and raises an alert on failure. A DR drill would be performed quarterly with the measured RTO recorded.

**Known limitation.** The scheduled backup CronJob lives outside the Helm chart with `namespace: dev` and `--host mern-dev-mongodb` hardcoded, and it is applied manually with `kubectl apply` rather than by the pipeline; therefore no automatic backups are taken in the test and prod environments. Moving it into the chart and deriving those values from the release name and namespace is a piece of technical debt. Other limitations are listed in `docs/backup-restore.md` §7.

The runbook is in `docs/backup-restore.md`. The evidence is referenced as screenshots 13–18 in section 6 of `SUBMISSION_EVIDENCE.md`.

---

## Additional Notes

Use this section for any additional decisions, limitations, or future improvement steps that you would like to highlight.

**Answer:**

**Infrastructure (IaC).** The AWS infrastructure is provisioned with Terraform through local `vpc` and `eks` modules, which wrap the official `terraform-aws-modules`. Worker nodes run in private subnets and egress through a single NAT Gateway (`single_nat_gateway = true` for cost; one NAT per AZ is recommended in production). The `ENV_NAME` pipeline parameter feeds both `TF_VAR_env_prefix` for Terraform and the Helm values selection, so infrastructure and application deployment advance in sync from a single parameter and each environment gets its own VPC/EKS cluster.

**CI/CD.** In the Jenkins pipeline the three images are built concurrently in a `parallel` block to shorten build time, with `failFast true` cancelling the rest when one fails. Credentials are injected through Jenkins Credentials and Docker login uses `--password-stdin`. After deployment a smoke test and a real Cypress E2E test through the ELB are executed; if E2E fails, an automatic `helm rollback` is triggered and the test videos and screenshots are archived as build artifacts.

**Known technical debt (next iteration).** Items that are understood and must be closed before production:

1. **The Terraform state key is not environment-scoped.** `key = "eks-cluster/terraform.tfstate"` in `terraform/backend.tf` is fixed and no workspace is used, so different `ENV_NAME` values share the same state file. Fix: `terraform init -reconfigure -backend-config="key=eks-cluster/${ENV_NAME}/terraform.tfstate"`, or Terraform workspaces. State locking (a DynamoDB table) should also be configured.
2. **`terraform.tfvars` is not in the repository** (`*.tfvars` is excluded by `.gitignore`) and the variables have no defaults; a `terraform.tfvars.example` file should be added so the work can be reproduced.
3. **The EBS CSI driver was installed manually.** The `aws-ebs-csi-driver` add-on and the `AmazonEBSCSIDriverPolicy` IAM policy required for MongoDB's persistent volume were added by hand in this environment; they should be managed in Terraform through the `cluster_addons` block with IRSA.
4. **Liveness/readiness probes, `securityContext`, NetworkPolicy and HPA** were not added to the templates (see Questions 3, 10, 12, 14).
5. **MongoDB authentication is disabled** and the chart defines no `Secret`/`ConfigMap` resources (see Question 9).
6. **The backup CronJob is specific to the `dev` environment** and lives outside the chart (see Question 16).
7. **There is no unique index on `github_id` in the ETL**; uniqueness is enforced in application code (see Question 15).
8. **The pipeline has no image security scanning (Trivy) and no centralized log collection** (see Questions 3 and 13).
