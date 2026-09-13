# TESLİM KANITLARI

Teslimin başarılı şekilde tamamlanmış sayılabilmesi için çalışan sisteme ait ekran görüntülerini `docs/screenshots/` klasörüne ekleyin ve aşağıdaki maddelerde ilgili dosya yolunu belirtin.

Ekran görüntülerinde gerçek credential, token, parola, private key veya hassas bağlantı bilgileri görünmemelidir.

## 1. Web Uygulaması

### 1.1 Ana sayfa

- **Görsel:** `docs/screenshots/01-web-home.png`
- **Açıklama:**AWS Ingress Load Balancer URL'si üzerinden MERN uygulamasına erişilmiş ve uygulamanın ana sayfası görüntülenmiştir.

### 1.2 Create işlemi

- **Form görseli:** `docs/screenshots/...`
- **Başarılı sonuç görseli:** `docs/screenshots/02-record-create-form.png`
- **Açıklama:** Arayüz üzerinden yeni bir kayıt oluşturulmuş ve Backend üzerinden MongoDB'ye başarılı bir şekilde yazılarak listeye düşmesi doğrulanmıştır.

### 1.3 Edit işlemi

- **İşlem öncesi görsel:** `docs/screenshots/04-record-edit-before.png`
- **İşlem sonrası görsel:** `docs/screenshots/05-record-edit-after.png`
- **Açıklama:** 

## 2. Docker

- **Image build ve çalışan container görseli:** `06-docker-build-and-containers.png`
- **Açıklama:** Frontend(Nginx), Backend(Node), ETL(Python) ve MongoDB imajı `docker-compose` üzerinde ayağa kaldırılmıştır.
                Docker ağı üzerinde service discovery sorunsuz çalışmış ve host üzerinden konteynere yapılan port mapping ile arayüz başarılı şekilde expose edilmiştirç Frontend'e browserdan erişim sağlanmıştır.

## 3. Kubernetes

- **Pod/workload durumu:** `docs/screenshots/07-kubernetes-workloads.png`
- **Service ve varsa Ingress durumu:** `docs/screenshots/08-kubernetes-services-ingress.png`
- **ETL CronJob/Job durumu:** `docs/screenshots/09-etl-cronjob-job.png`
- **Açıklama:**

## 4. Python ETL

### 4.1 İlk veri aktarımı

GitHub repository bilgilerinin MongoDB’ye ilk kez kaydedildiğini gösterin.

- **Görsel veya terminal çıktısı:** `docs/screenshots/10-etl-first-load.png`
- **Açıklama:** Python ETL script'i ilk kez çalıştırıldığında GitHub API üzerinden çekilen 11 adet repository MongoDB'ye aktarılmış ve Mongo Express arayüzündeki döküman sayısıyla doğrulanmıştır.

### 4.2 Aynı repository için güncelleme

Aynı repository tekrar işlendiğinde duplicate kayıt oluşmadığını ve mevcut kaydın güncellendiğini gösterin. Mümkünse repository sayısını ve güncellenen alanı aynı kanıt içinde belirtin.

- **Görsel veya terminal çıktısı:** `docs/screenshots/11-etl-update-without-duplicate-2.png`
- Öncesi (Manuel Değişiklik): `docs/screenshots/11-etl-update-without-duplicate-1.png`
- Sonrası (Güncelleme ve Terminal Logu): `docs/screenshots/11-etl-update-without-duplicate-2.png`
- **Kullanılan benzersiz alan:** github_id
- **Açıklama:** lokal ortamda kurulan yapi mongoexpress arayzuunden ve terminal ciktisindan dogrulandi

## 5. CI/CD

- **Başarılı pipeline görseli:** `docs/screenshots/12-cicd-pipeline-success.png`
- **Build/image/deployment aşamalarını gösteren görsel:** `docs/screenshots/06-docker-build-and-containers.png`
- **Açıklama:** 

## 6. Backup ve Restore

Aşağıdaki altı adımın tamamı kanıtlanmalıdır. Adımların aynı kayıt üzerinde ve sırayla yapıldığı anlaşılmalıdır.

### 6.1 Kayıt oluşturma

- **Görsel:** `docs/screenshots/...`
- **Açıklama:**

### 6.2 Yedek alma

- **Görsel veya terminal çıktısı:** `docs/screenshots/...`
- **Kullanılan yöntem ve komut:**
- **Yedeğin saklandığı konum:**
- **Açıklama:**

### 6.3 Collection veya veritabanının silinmesi

- **Görsel veya terminal çıktısı:** `docs/screenshots/...`
- **Açıklama:**

### 6.4 Verinin kaybolduğunun gösterilmesi

- **Arayüz görseli:** `docs/screenshots/...`
- **Veritabanı çıktısı:** `docs/screenshots/...`
- **Açıklama:**

### 6.5 Yedekten geri yükleme

- **Görsel veya terminal çıktısı:** `docs/screenshots/...`
- **Ölçülen geri yükleme süresi:**
- **Açıklama:**

### 6.6 Verinin geri geldiğinin doğrulanması

- **Arayüz görseli:** `docs/screenshots/...`
- **Veritabanı çıktısı:** `docs/screenshots/...`
- **Açıklama:**

> Runbook, RPO/RTO hedefleri ve retention süresi `docs/backup-restore.md` içinde dokümante edilmelidir.

## 7. Logging, Monitoring ve Üst Kriterler

Uyguladığınız logging, monitoring, alarm, Helm, Terraform, güvenlik taraması veya diğer üst kriterlere ait kanıtları ekleyin.

- **Görsel:** `docs/screenshots/19-monitoring-or-upper-criteria.png`
- **Açıklama:** ETL CronJob'ının manuel tetiklenen koşumunun log çıktısı. Her repository için INSERTED/UPDATED ayrımı ve sondaki özet satırı, aynı repository tekrar işlendiğinde yeni kayıt oluşturulmadığını, mevcut kaydın github_id üzerinden güncellendiğini gösterir.

## 8. Ek Kanıtlar

- **Görsel:** `docs/screenshots/...`
- **Açıklama:**
