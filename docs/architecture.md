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
        elb["Elastic Load Balancer<br/>(Classic LB)<br/>ONLY PUBLIC ENTRY POINT"]
        nat["NAT Gateway"]

        subgraph eks["EKS Cluster"]
            subgraph nsingress["namespace: ingress-basic"]
                nginx["NGINX Ingress Controller"]
            end

            subgraph nsdev["namespace: dev"]
                ing["Ingress<br/>path-based routing"]
                fe["Frontend Deployment<br/>nginx-unprivileged :8080<br/>Service: ClusterIP"]
                be["Backend Deployment<br/>Node.js / Express :5050<br/>Service: ClusterIP"]
                mongo["MongoDB StatefulSet<br/>:27017<br/>Service: ClusterIP"]
                pvcdata[("PVC: data<br/>gp2 / EBS 5Gi")]
                etl["ETL CronJob<br/>hourly"]
                bkp["Backup CronJob<br/>daily 02:00 UTC"]
                pvcbkp[("PVC: mongodb-backup<br/>gp2 / EBS 5Gi")]
            end
        end
    end

    user -->|HTTP| elb
    elb --> nginx
    nginx --> ing
    ing -->|"/"| fe
    ing -->|"/record, /healthcheck"| be
    be -->|"mongodb://mern-dev-mongodb:27017"| mongo
    mongo --- pvcdata
    etl -->|write| mongo
    etl -->|"HTTPS egress"| nat
    nat --> github
    bkp -->|mongodump| mongo
    bkp --> pvcbkp

    jenkins -->|"docker build / push"| dockerhub
    jenkins -->|"helm upgrade"| eks
    fe -.->|"image pull"| dockerhub
    be -.->|"image pull"| dockerhub
    etl -.->|"image pull"| dockerhub

    classDef ext fill:#f5f5f5,stroke:#999,stroke-dasharray:4
    classDef entry fill:#ffe6e6,stroke:#c33,stroke-width:2px
    classDef store fill:#eef7ee,stroke:#4a4
    class user,github,jenkins,dockerhub ext
    class elb entry
    class pvcdata,pvcbkp store
```

## Dış erişim noktaları

| Bileşen | Erişim | Açıklama |
| --- | --- | --- |
| Elastic Load Balancer | **Public** | Kümeye tek giriş noktası. HTTP/80. |
| Frontend Service | ClusterIP | Yalnızca Ingress Controller üzerinden erişilir. |
| Backend Service | ClusterIP | Yalnızca Ingress ve küme içinden erişilir. |
| MongoDB Service | ClusterIP | Küme dışına tamamen kapalı. Yalnızca backend, ETL ve backup CronJob erişir. |
| GitHub API | Giden (egress) | ETL CronJob, NAT Gateway üzerinden dışarı çıkar. |

## İstek akışı

1. Kullanıcı tarayıcıdan ELB adresine HTTP isteği gönderir.
2. ELB trafiği NGINX Ingress Controller pod'larına iletir.
3. Ingress, path-based routing ile `/` isteklerini frontend'e, `/record` ve
   `/healthcheck` isteklerini backend'e yönlendirir.
4. Backend, MongoDB ile ClusterIP Service üzerinden `27017` portundan haberleşir.
5. MongoDB verisi gp2 EBS diski üzerinde PersistentVolumeClaim ile kalıcıdır.
6. ETL CronJob saatte bir GitHub API'sini sorgular ve veriyi MongoDB'ye yazar.
7. Backup CronJob her gece `mongodump` ile ayrı bir PVC'ye yedek alır.
