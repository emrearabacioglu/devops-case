# 2NTECH DevOps Teknik Case

Case gereksinimleri, teslim kapsamı ve değerlendirme bilgileri için **`DevOps_Teknik_Case_TR.docx`** dosyasını okuyun.

> Başlangıç uygulamaları bilinçli olarak production-readiness sorunları içermektedir. Uygulama kodundaki mevcut davranışlar doğru kabul edilmemeli; adayın kritik sorunları analiz etmesi, önceliklendirmesi ve gerekli iyileştirmeleri dokümante etmesi beklenmektedir.

## Proje yapısı

- `mern-project/`: React frontend, Express.js backend ve MongoDB kullanan başlangıç uygulaması
- `python-project/`: Başlangıç Python ETL iş yükü ve sınırlı ETL gereksinimleri
- `DevOps_Teknik_Case_TR.docx`: Ana case dokümanı
- `CASE_SONU_CEVAPLARI.md`: Teslim sırasında cevaplanması gereken soru şablonu
- `TESLIM_KANITLARI.md`: Zorunlu ekran görüntüsü ve çalışma kanıtı şablonu
- `docs/backup-restore.md`: Yedekleme ve geri yükleme runbook şablonu (aday tarafından doldurulur)
- `docs/screenshots/`: Teslim ekran görüntülerinin konulacağı klasör

## Ortam seçimi

Çözüm bir public cloud üzerinde veya adayın oluşturduğu Linux sanal makine üzerinde çalıştırılabilir. Cloud kullanımı zorunlu değildir. VM üzerinde k3s, microk8s veya kubeadm gibi bir Kubernetes dağıtımı kullanılabilir.

## Temel fonksiyonel beklentiler

- MERN uygulamasının temel kullanıcı akışları ve API fonksiyonları çalışmalıdır.
- Python ETL, GitHub API üzerinden repository bilgilerini otomatik olarak almalı ve MongoDB’ye yazmalıdır.
- Aynı repository sonraki ETL çalışmalarında tekrar geldiğinde yeni kayıt oluşturulmamalı; mevcut kayıt benzersiz repository bilgisi üzerinden güncellenmelidir.
- Python ETL saatte bir çalıştırılmalıdır.
- MongoDB verisi için yedekleme ve geri yükleme uygulanmalı; kayıt oluşturma, yedek alma, veriyi silme, yedekten geri yükleme ve verinin geri geldiğinin doğrulanması adımları uçtan uca çalıştırılıp kanıtlanmalıdır.
- Kurulum, deployment, rollback, backup/restore ve temizlik adımları repository içinde dokümante edilmelidir.
- Repository içerisinde gerçek credential veya secret bulunmamalıdır.
- Çalışan sisteme ait zorunlu ekran görüntüleri `docs/screenshots/` altında paylaşılmalı ve `TESLIM_KANITLARI.md` içinde açıklanmalıdır.

Ayrıntılı ana kriterler, üst kriterler, teslim kanıtları ve case sonu soruları Word dokümanında yer almaktadır.

---

# Aday Çözümü — Emre Arabacıoğlu

Hedef ortam: **AWS EKS**. Altyapı Terraform ile, uygulama Helm ile, dağıtım Jenkins pipeline'ı ile yönetilmektedir.

## Çözüm bileşenleri

| Dizin / dosya | İçerik |
| --- | --- |
| `terraform/` | VPC ve EKS için yerel modüller; state S3 backend'inde şifreli tutulur |
| `mern-stack-chart/` | Frontend, backend, MongoDB, ETL ve Ingress için Helm chart; ortam bazlı values dosyaları |
| `Jenkinsfile` | Paralel imaj derleme/push → `terraform apply` → `helm upgrade` → smoke test → Cypress E2E → hata durumunda otomatik rollback |
| `docker-compose.yml` | Tüm yığının lokalde ayağa kaldırılması |
| `scripts/` | `mongo-backup.sh`, `mongo-restore.sh` |
| `k8s/backup/` | Günlük MongoDB yedeği alan CronJob ve yedek PVC'si |
| `monitoring/` | Prometheus Operator `PrometheusRule` alarm tanımları |
| `docs/` | Mimari diyagram, bulgular, alerting ve backup/restore runbook'ları |

## Dokümantasyon

| Dosya | İçerik |
| --- | --- |
| `CASE_SONU_CEVAPLARI.md` | Case sonu sorularının cevapları, teknik kararların gerekçeleri, kapsam dışı bırakılanlar ve bilinen teknik borçlar |
| `TESLIM_KANITLARI.md` | Ekran görüntüleri ve çalışma kanıtları |
| `docs/architecture.md` | Mermaid mimari diyagramı, dış erişim noktaları, istek ve dağıtım akışı |
| `docs/findings.md` | Başlangıç projelerindeki bulgular, önceliklendirme kriterleri ve uygulanan çözümler |
| `docs/alerting.md` | Logging/alerting runbook'u; alarm eşikleri ve müdahale adımları |
| `docs/backup-restore.md` | Backup/restore runbook'u, RPO/RTO hedefleri, doğrulama ve sınırlamalar |

## Lokal çalıştırma

```bash
# Tüm yığın (frontend, backend, MongoDB, ETL)
docker compose up --build

# Frontend: http://localhost:8080
# Backend : http://localhost:5050/record
```

## AWS'e kurulum ve dağıtım

Dağıtımın tamamı Jenkins pipeline'ı üzerinden, `ENV_NAME` parametresi (`dev` / `test` / `prod`) seçilerek yapılır. Pipeline sırasıyla:

1. Repository'yi çeker.
2. Frontend, backend ve ETL imajlarını paralel derleyip `v1.0.<BUILD_NUMBER>` etiketiyle Docker Hub'a push eder.
3. `terraform apply` ile seçilen ortamın VPC ve EKS cluster'ını sağlar.
4. `aws eks update-kubeconfig` ile kubeconfig alır, NGINX Ingress Controller'ı kurar.
5. `helm upgrade --install --wait --atomic --timeout 10m` ile uygulamayı dağıtır.
6. `kubectl rollout status` ile smoke test, ardından ELB adresi üzerinden Cypress E2E testi koşar.

Manuel olarak aynı işlemler:

```bash
# Altyapı (terraform.tfvars gereklidir; repoya dahil değildir)
cd terraform
terraform init
terraform apply
aws eks update-kubeconfig --region eu-central-1 --name $(terraform output -raw eks_cluster_name)

# Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx && helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-basic --create-namespace --wait

# Uygulama
helm upgrade --install mern-dev ./mern-stack-chart \
  --namespace dev --create-namespace \
  -f ./mern-stack-chart/values-dev.yaml \
  --wait --atomic --timeout 10m

# Uygulama adresi
kubectl get svc ingress-nginx-controller -n ingress-basic \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## Rollback

```bash
helm history mern-dev -n dev                  # sürüm geçmişi
helm rollback mern-dev -n dev --wait          # bir önceki sürüme dön
helm rollback mern-dev <REVISION> -n dev      # belirli bir sürüme dön
kubectl rollout status deployment/mern-dev-backend -n dev
```

Pipeline'da geri alma iki noktada otomatiktir: `helm upgrade --atomic` başarısız dağıtımda sürümü kendiliğinden geri alır, Cypress E2E aşaması başarısız olursa `post.failure` bloğundaki `helm rollback` devreye girer. Ayrıntı: `CASE_SONU_CEVAPLARI.md` Soru 11.

## Backup / Restore

```bash
./scripts/mongo-backup.sh                                     # yedek al
./scripts/mongo-restore.sh ./backups/mongodb-<timestamp>.archive.gz   # geri yükle
kubectl apply -f k8s/backup/mongodb-backup-cronjob.yaml        # günlük otomatik yedek
```

Runbook, RPO/RTO hedefleri, doğrulama adımları ve bilinen sınırlamalar: `docs/backup-restore.md`.

## Monitoring

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace --wait
kubectl apply -f monitoring/prometheus-rules.yaml
```

Alarm tanımları, eşik gerekçeleri ve müdahale adımları: `docs/alerting.md`.

## Temizlik / Cleanup

Kaynakların ücretlendirmeye devam etmemesi için sırayla:

```bash
# 1. Uygulama release'i
helm uninstall mern-dev -n dev

# 2. StatefulSet'in PVC'leri Helm tarafından silinmez, elle silinmelidir
kubectl delete pvc -n dev -l app=mern-dev-mongodb
kubectl delete pvc mongodb-backup -n dev          # yedek PVC'si (veri kaybına dikkat)
kubectl delete -f k8s/backup/mongodb-backup-cronjob.yaml

# 3. Namespace
kubectl delete namespace dev

# 4. Monitoring (kurulduysa)
helm uninstall monitoring -n monitoring && kubectl delete namespace monitoring

# 5. Ingress Controller — ELB'nin silinmesi için terraform destroy'dan ÖNCE yapılmalıdır
helm uninstall ingress-nginx -n ingress-basic
kubectl delete namespace ingress-basic

# 6. Altyapı
cd terraform && terraform destroy

# 7. AWS konsolundan doğrulama: EC2 > Load Balancers ve EBS > Volumes boş olmalı
```

> **Önemli:** NGINX Ingress Controller'ın oluşturduğu ELB ve StatefulSet'in EBS diskleri Kubernetes tarafından yönetildiği için Terraform'un state'inde yer almaz. Bu kaynaklar `terraform destroy` öncesinde silinmezse VPC bağımlılığı nedeniyle destroy takılır ve orphan kaynaklar ücretlendirilmeye devam eder.
