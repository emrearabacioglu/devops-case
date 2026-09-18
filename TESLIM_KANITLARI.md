# TESLİM KANITLARI

Teslimin başarılı şekilde tamamlanmış sayılabilmesi için çalışan sisteme ait ekran görüntülerini `docs/screenshots/` klasörüne ekleyin ve aşağıdaki maddelerde ilgili dosya yolunu belirtin.

Ekran görüntülerinde gerçek credential, token, parola, private key veya hassas bağlantı bilgileri görünmemelidir.

## 1. Web Uygulaması

### 1.1 Ana sayfa

- **Görsel:** `docs/screenshots/01-web-home.png`
- **Açıklama:** AWS üzerindeki NGINX Ingress Controller'ın LoadBalancer adresi üzerinden MERN uygulamasına erişilmiş ve uygulamanın ana sayfası görüntülenmiştir.

### 1.2 Create işlemi

- **Form görseli:** `docs/screenshots/02-record-create-form.png`
- **Başarılı sonuç görseli:** `docs/screenshots/03-record-created.png`
- **Açıklama:** Arayüzdeki Create Record formu doldurularak yeni bir kayıt oluşturulmuş; isteğin Ingress → backend (`/record`) → MongoDB yolunu izlediği ve kaydın Record List sayfasına düştüğü doğrulanmıştır.

### 1.3 Edit işlemi

- **İşlem öncesi görsel:** `docs/screenshots/04-record-edit-before.png`
- **İşlem sonrası görsel:** `docs/screenshots/05-record-edit-after.png`
- **Açıklama:** Mevcut bir kaydın alanları Edit ekranından güncellenmiş, `PATCH /record/:id` isteği sonrası değişikliğin hem listede hem veritabanında geçerli olduğu görülmüştür.

## 2. Docker

- **Image build ve çalışan container görseli:** `docs/screenshots/06-docker-build-and-containers.png`
- **Açıklama:** Jenkins pipeline'ının `Parallel Build & Push` aşamasından frontend, backend ve ETL imajlarının paralel olarak derlendiği ve `v1.0.<BUILD_NUMBER>` etiketiyle Docker Hub'a push edildiği adımlar gösterilmiştir.

## 3. Kubernetes

- **Pod/workload durumu:** `docs/screenshots/07-kubernetes-workloads.png`
- **Service ve varsa Ingress durumu:** `docs/screenshots/08-kubernetes-services-ingress.png`
- **ETL CronJob/Job durumu:** `docs/screenshots/09-etl-cronjob-job.png`
- **Açıklama:** `dev` namespace'inde frontend ve backend Deployment'ları, MongoDB StatefulSet'i ve ETL CronJob'ı `Running`/`Active` durumda görülmektedir. Service çıktısında frontend, backend ve MongoDB'nin tamamının `ClusterIP` olduğu, tek `LoadBalancer` kaydının `ingress-basic` namespace'indeki NGINX Ingress Controller'a ait olduğu doğrulanmaktadır. CronJob çıktısında saatlik zamanlama (`0 * * * *`) ve tamamlanan Job kayıtları yer almaktadır.

## 4. Python ETL

### 4.1 İlk veri aktarımı

GitHub repository bilgilerinin MongoDB’ye ilk kez kaydedildiğini gösterin.

- **Görsel veya terminal çıktısı:** `docs/screenshots/10-etl-first-load.png`
- **Açıklama:** Python ETL ilk kez çalıştırıldığında GitHub API üzerinden çekilen 11 repository MongoDB'ye aktarılmış; log çıktısındaki `INSERTED` satırları ve arayüzdeki doküman sayısı birlikte doğrulanmıştır.

### 4.2 Aynı repository için güncelleme

Aynı repository tekrar işlendiğinde duplicate kayıt oluşmadığını ve mevcut kaydın güncellendiğini gösterin. Mümkünse repository sayısını ve güncellenen alanı aynı kanıt içinde belirtin.

- **Öncesi (manuel değişiklik):** `docs/screenshots/11-etl-update-without-duplicate-1.png`
- **Sonrası (güncelleme ve terminal logu):** `docs/screenshots/11-etl-update-without-duplicate-2.png`
- **Kullanılan benzersiz alan:** `github_id` (GitHub API'den dönen repository `id` değeri)
- **Açıklama:** Önce veritabanındaki bir repository kaydının alanı elle değiştirilmiş, ardından ETL ikinci kez çalıştırılmıştır. Log çıktısında ilgili repo için `UPDATED existing repo ... (github_id=...)` satırı görülmekte, toplam doküman sayısı değişmemekte ve elle bozulan alan orijinal değerine dönmektedir. Bu üçü birlikte, aynı repository tekrar işlendiğinde yeni kayıt oluşmadığını ve mevcut kaydın `github_id` üzerinden güncellendiğini kanıtlar. Ayrıntı için `CASE_SONU_CEVAPLARI.md` Soru 15.

## 5. CI/CD

- **Başarılı pipeline görseli:** `docs/screenshots/12-cicd-pipeline-success.png`
- **Build/image/deployment aşamalarını gösteren görsel:** `docs/screenshots/06-docker-build-and-containers.png`
- **Açıklama:** Jenkins pipeline'ının uçtan uca başarılı koşumu: `Checkout` → paralel imaj derleme ve push → `terraform apply` ile altyapı sağlama → `helm upgrade --install --wait --atomic` ile EKS'e dağıtım → `kubectl rollout status` smoke testi → ELB üzerinden Cypress E2E testi. E2E aşamasının başarısız olması durumunda `post.failure` bloğundaki `helm rollback` devreye girer.

## 6. Backup ve Restore

Aşağıdaki altı adımın tamamı kanıtlanmalıdır. Adımların aynı kayıt üzerinde ve sırayla yapıldığı anlaşılmalıdır.

### 6.1 Kayıt oluşturma

- **Görsel:** `docs/screenshots/13-backup-record-created.png`
- **Açıklama:** Arayüzden `BackupTest` kaydı oluşturuldu ve Record List sayfasında görüntülendi.

### 6.2 Yedek alma

- **Görsel veya terminal çıktısı:** `docs/screenshots/14-backup-taken.png`
- **Kullanılan yöntem ve komut:** `./scripts/mongo-backup.sh` → `kubectl exec -n dev mern-dev-mongodb-0 -- mongodump --archive --gzip`
- **Yedeğin saklandığı konum:** `backups/mongodb-<timestamp>.archive.gz` (operatör makinesi); zamanlanmış yedekler `dev` namespace'indeki `mongodb-backup` PVC'sinde.
- **Açıklama:** Yedek dosyasının yolu, boyutu (4.0K) ve 7 günlük retention uygulaması çıktıda görülmektedir.

### 6.3 Collection veya veritabanının silinmesi

- **Görsel veya terminal çıktısı:** `docs/screenshots/15-collection-dropped.png`
- **Açıklama:** `sample_training.records` collection'ı `drop()` ile silindi.

### 6.4 Verinin kaybolduğunun gösterilmesi

- **Arayüz görseli:** `docs/screenshots/16-data-missing-after-drop.png`
- **Veritabanı çıktısı:** `docs/screenshots/16-data-missing-after-drop.png`
- **Açıklama:** Veritabanında `records count: 0`, arayüzde boş tablo görülmektedir (aynı görselde birlikte).

### 6.5 Yedekten geri yükleme

- **Görsel veya terminal çıktısı:** `docs/screenshots/17-restore-executed.png`
- **Ölçülen geri yükleme süresi:** 0m1.490s (`time ./scripts/mongo-restore.sh ...` ile ölçüldü)
- **Açıklama:** `./scripts/mongo-restore.sh` ile `mongorestore --archive --gzip --drop` çalıştırıldı. `--drop` bayrağı hedef collection'ı geri yüklemeden önce sildiği için restore sonrası duplicate kayıt oluşmaz.

### 6.6 Verinin geri geldiğinin doğrulanması

- **Arayüz görseli:** `docs/screenshots/18-data-restored-verified.png`
- **Veritabanı çıktısı:** `docs/screenshots/18-data-restored-verified.png`
- **Açıklama:** Kayıt sayısı yedek öncesi değerine döndü, `BackupTest` kaydı arayüzde tekrar görüntülendi. Geri yükleme sonrası uygulamanın yeniden başlatılmasına gerek olmadığı da doğrulanmıştır.

> Runbook, RPO/RTO hedefleri, retention süresi ve bilinen sınırlamalar `docs/backup-restore.md` içinde dokümante edilmiştir.

## 7. Logging, Monitoring ve Üst Kriterler

Uyguladığınız logging, monitoring, alarm, Helm, Terraform, güvenlik taraması veya diğer üst kriterlere ait kanıtları ekleyin.

- **Görsel (logging):** `docs/screenshots/19-monitoring-or-upper-criteria.png`
- **Açıklama:** ETL CronJob'ının manuel tetiklenen bir koşumunun log çıktısı. ETL'in `print` çağrıları `logging` modülüne taşınmış; her satırda zaman damgası, log seviyesi ve her repository için `INSERTED`/`UPDATED` ayrımı, sonda ise özet satırı basılmaktadır. Bu format hem 12-factor log yaklaşımının (stdout/stderr) hem de Soru 15'teki duplicate oluşmadığı iddiasının kanıtıdır.
- **Alarm tanımları:** `monitoring/prometheus-rules.yaml` — Prometheus Operator `PrometheusRule` kaynağı olarak dört alarm (`BackendUnavailable`, `MongoDBUnavailable`, `ETLJobFailed`, `ETLNoSuccessfulRun`). Eşik gerekçeleri, devreye alma komutları, Alertmanager routing örneği ve alarm başına runbook adımları `docs/alerting.md` içindedir. `kube-prometheus-stack` bu ortamda pipeline'ın parçası olarak değil elle kurulmuş, Alertmanager receiver'ı harici bir Slack/PagerDuty hedefi bulunmadığı için canlıya bağlanmamıştır.
- **Helm:** `mern-stack-chart/` — ortam bazlı values dosyaları (`values-dev/test/prod.yaml`) ve pipeline'da `--set *.image.tag=v1.0.<BUILD_NUMBER>` ile dinamik imaj etiketi enjeksiyonu; `--wait --atomic` ile otomatik rollback.
- **Terraform:** `terraform/` — `vpc` ve `eks` yerel modülleri, S3 backend'inde `encrypt = true` ile şifreli state, `ENV_NAME` parametresiyle ortam bazlı kurulum.

## 8. Ek Kanıtlar

- **Yazılı kanıtlar:**
  - `docs/architecture.md` — Mermaid formatında mimari diyagram, dış erişim noktaları tablosu ve istek akışı (düzenlenebilir kaynak dosyanın kendisidir).
  - `docs/findings.md` — Başlangıç projelerinde tespit edilen sorunlar, severity değerlendirmesi ve uygulanan çözümler.
  - `docs/alerting.md` — Logging ve alerting runbook'u; alarm başına müdahale adımları ve kapsam dışı bırakılanlar.
  - `docs/backup-restore.md` — Backup/restore runbook'u, RPO/RTO hedefleri, doğrulama yöntemi ve bilinen sınırlamalar.
- **Açıklama:** Kod ve manifest tarafındaki kararların gerekçeleri `CASE_SONU_CEVAPLARI.md` içinde ilgili dosya yollarına referans verilerek açıklanmıştır. Bilinçli olarak kapsam dışı bırakılan konular ve bilinen teknik borçlar aynı dosyanın Soru 3 ve Ek Notlar bölümlerinde açıkça listelenmiştir.
