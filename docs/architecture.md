# Mimari Diyagram / Architecture Diagram

Aşağıdaki diyagram Mermaid formatındadır ve bu dosyanın kendisi düzenlenebilir
kaynak dosyasıdır. GitHub üzerinde doğrudan render edilir.

## Sistem bileşenleri ve trafik akışı

```mermaid
flowchart TB
    user["User<br/>(Browser)"]
    github["GitHub API<br/>(external service)"]
    jenkins["Jenkins<br/>(external server)"]
    dockerhub["Docker Hub"]

    subgraph aws["AWS / eu-central-1 - VPC (Terraform)"]
        elb["Elastic Load Balancer<br/>(Classic LB)<br/>PUBLIC - application traffic"]
        eksapi["EKS Control Plane API<br/>PUBLIC - management traffic<br/>(no CIDR allowlist)"]
        nat["NAT Gateway<br/>(egress only)"]

        subgraph eks["EKS Cluster - worker nodes in private subnets"]
            subgraph nsingress["namespace: ingress-basic"]
                nginx["NGINX Ingress Controller<br/>Service: LoadBalancer"]
            end

            subgraph nsdev["namespace: dev (per-env)"]
                ing["Ingress<br/>path-based routing"]
                fe["Frontend Deployment<br/>nginx-unprivileged :8080<br/>Service: ClusterIP"]
                be["Backend Deployment<br/>Node.js / Express :5050<br/>Service: ClusterIP"]
                mongo["MongoDB StatefulSet<br/>:27017<br/>Service: ClusterIP"]
                pvcdata[("PVC: data<br/>gp2 / EBS 5Gi")]
                etl["ETL CronJob<br/>hourly - 0 * * * *"]
                hook["ETL Job<br/>Helm hook<br/>post-install / post-upgrade"]
                bkp["Backup CronJob<br/>daily 02:00 UTC"]
                pvcbkp[("PVC: mongodb-backup<br/>gp2 / EBS 5Gi")]
            end
        end
    end

    user -->|"HTTP / 80"| elb
    elb --> nginx
    nginx --> ing
    ing -->|"/"| fe
    ing -->|"/record, /healthcheck"| be
    be -->|"mongodb://mern-dev-mongodb:27017"| mongo
    mongo --- pvcdata
    etl -->|"upsert on github_id"| mongo
    hook -->|"initial / refresh load"| mongo
    etl -->|"HTTPS egress"| nat
    nat --> github
    bkp -->|"mongodump --archive --gzip"| mongo
    bkp --> pvcbkp

    jenkins -->|"docker build / push"| dockerhub
    jenkins -->|"terraform apply"| aws
    jenkins -->|"helm upgrade / kubectl"| eksapi
    eksapi --> eks
    eks -.->|"image pull via NAT"| nat
    nat -.-> dockerhub

    classDef ext fill:#f5f5f5,stroke:#999,stroke-dasharray:4
    classDef entry fill:#ffe6e6,stroke:#c33,stroke-width:2px
    classDef store fill:#eef7ee,stroke:#4a4
    class user,github,jenkins,dockerhub ext
    class elb,eksapi entry
    class pvcdata,pvcbkp store
```

## Dış erişim noktaları

| Bileşen | Erişim | Açıklama |
| --- | --- | --- |
| Elastic Load Balancer | **Public** | Uygulama trafiği için kümeye tek giriş noktası. HTTP/80. TLS sonlandırma yapılandırılmamıştır (bkz. kapsam dışı). |
| EKS Control Plane API | **Public** | Yönetim trafiği. `cluster_endpoint_public_access = true`; Jenkins `helm`/`kubectl` çağrılarını buradan yapar. `public_access_cidrs` ile kısıtlanmamıştır — bilinen teknik borç. |
| Frontend Service | ClusterIP | Yalnızca Ingress Controller üzerinden erişilir. |
| Backend Service | ClusterIP | Yalnızca Ingress ve küme içinden erişilir. |
| MongoDB Service | ClusterIP | Küme dışına tamamen kapalı. Yalnızca backend, ETL ve backup CronJob erişir. Authentication kapalıdır; küme içi erişim NetworkPolicy ile kısıtlanmamıştır. |
| GitHub API | Giden (egress) | ETL CronJob, private subnet'ten NAT Gateway üzerinden dışarı çıkar. |
| Docker Hub | Giden (egress) | Worker node'lar imaj çekerken NAT Gateway üzerinden çıkar. |

## İstek akışı

1. Kullanıcı tarayıcıdan ELB adresine HTTP isteği gönderir.
2. ELB trafiği `ingress-basic` namespace'indeki NGINX Ingress Controller pod'larına iletir.
3. Ingress, path-based routing ile `/` isteklerini frontend'e, `/record` ve
   `/healthcheck` isteklerini backend'e yönlendirir.
4. Backend, MongoDB ile ClusterIP Service üzerinden `27017` portundan haberleşir
   (`ATLAS_URI` ortam değişkeni, Helm release adından türetilir).
5. MongoDB verisi, StatefulSet'in `volumeClaimTemplates` bloğu ile gp2 EBS diski
   üzerinde PersistentVolumeClaim olarak kalıcıdır.
6. ETL CronJob saatte bir GitHub API'sini sorgular ve veriyi `github_id` alanı
   üzerinden upsert ederek MongoDB'ye yazar. Kurulum ve her upgrade sonrasında
   aynı iş, Helm `post-install,post-upgrade` hook Job'u ile bir kez daha koşar.
7. Backup CronJob her gece 02:00 UTC'de `mongodump` ile ayrı bir PVC'ye yedek alır.

## Dağıtım akışı

1. Jenkins `Parallel Build & Push` aşamasında frontend, backend ve ETL imajlarını
   eşzamanlı derleyip `v1.0.<BUILD_NUMBER>` etiketiyle Docker Hub'a push eder.
2. `terraform apply` ile seçilen ortamın (`ENV_NAME` → `TF_VAR_env_prefix`) VPC ve
   EKS cluster'ı sağlanır; state S3 backend'inde şifreli tutulur.
3. `helm upgrade --install --wait --atomic --timeout 10m` ile chart, ortam values
   dosyası ve dinamik imaj etiketleriyle dağıtılır.
4. `kubectl rollout status` smoke testi, ardından ELB üzerinden Cypress E2E testi
   koşulur; E2E başarısız olursa `helm rollback` otomatik devreye girer.

## Diyagramda görünmeyen, bilinçli kapsam dışı bileşenler

Aşağıdakiler mimaride yoktur; gerekçeleri `CASE_SONU_CEVAPLARI.md` Soru 3'tedir:
TLS/ACM sertifikası, NetworkPolicy, HorizontalPodAutoscaler, liveness/readiness
probe'ları, MongoDB Replica Set ve authentication, merkezi log toplama katmanı.
