# Backup & Restore Runbook

Kanıt ekran görüntüleri `TESLIM_KANITLARI.md` (TR) / `SUBMISSION_EVIDENCE.md` (EN) dosyalarından referanslanmıştır.

---

## 1. Yaklaşım / Approach

| | |
| --- | --- |
| Yedekleme yöntemi | `mongodump` / `mongorestore` ile tek dosyalık sıkıştırılmış arşiv (`--archive --gzip`). Tek dosya olduğu için taşınması ve bütünlüğünün doğrulanması kolaydır. |
| Nasıl çalıştırılıyor | İki yolla: **(a)** operatör tarafından tekrarlanabilir script ile (`scripts/mongo-backup.sh`, `scripts/mongo-restore.sh`), **(b)** küme içinde zamanlanmış Kubernetes CronJob ile (`k8s/backup/mongodb-backup-cronjob.yaml`). |
| Kapsam | `sample_training` veritabanının tamamı. Uygulama verisi (`records`) ve ETL verisi (`github_repos`) aynı arşivde yer alır. |
| Yedeğin saklandığı konum | **Manuel yedekler:** operatör makinesinde `./backups/` klasörü (`.gitignore` içinde, repoya girmez). **Zamanlanmış yedekler:** `dev` namespace'indeki `mongodb-backup` PersistentVolumeClaim (5Gi, gp2/EBS). |
| Yedek formatı ve boyutu | `mongodb-YYYYMMDD-HHMMSS.archive.gz` — gzip sıkıştırmalı BSON arşivi. Ölçülen boyut: **4.0K** |
| Sıklık | Zamanlanmış: her gün 02:00 UTC. Manuel: değişiklik öncesi ve restore tatbikatlarında. |
| Retention süresi | 7 gün. Hem script hem CronJob her koşumda `find -mtime +7 -delete` ile eski arşivleri siler. |
| Şifreleme ve erişim | Beklemede (at-rest) şifreleme yoktur. Erişim kontrolü: MongoDB Service tipi **ClusterIP**'tir, küme dışına kapalıdır; yedek almak için `kubectl exec` yetkisi gerekir (Kubernetes RBAC); yedek PVC'si yalnızca `dev` namespace'inden mount edilebilir; yedek dosyaları repoya veya container imajına yazılmaz. |

## 2. Hedefler / Targets

| | Hedef / Target | Ölçülen / Measured |
| --- | --- | --- |
| RPO | 24 saat (günlük yedek; en kötü senaryoda son 24 saatin verisi kaybedilir) | Senaryoda 0 — yedek, silme işleminden hemen önce manuel alındı |
| RTO | 15 dakika | **0m1.490s** (`time ./scripts/mongo-restore.sh` ile ölçüldü) |

## 3. Yedek alma adımları / Backup procedure

```bash
# Manuel yedek (operatör)
cd ~/DevOps_Case
./scripts/mongo-backup.sh

# Script'in yaptığı iş:
#   kubectl exec -n dev mern-dev-mongodb-0 -- mongodump --archive --gzip \
#     > ./backups/mongodb-$(date +%Y%m%d-%H%M%S).archive.gz
#   ardından 7 günden eski arşivleri siler

# Zamanlanmış yedeği devreye alma
kubectl apply -f k8s/backup/mongodb-backup-cronjob.yaml
kubectl get cronjob -n dev

# Zamanlanmış yedeği manuel tetikleme
kubectl create job --from=cronjob/mongodb-backup backup-manual -n dev
kubectl logs -n dev -l job-name=backup-manual

# PVC üzerindeki yedeklerin listesi
kubectl run backup-viewer -n dev --rm -it --restart=Never --image=busybox \
  --overrides='{"spec":{"volumes":[{"name":"b","persistentVolumeClaim":{"claimName":"mongodb-backup"}}],"containers":[{"name":"v","image":"busybox","command":["ls","-lh","/backup"],"volumeMounts":[{"name":"b","mountPath":"/backup"}]}]}}'
```

## 4. Geri yükleme adımları / Restore procedure

```bash
cd ~/DevOps_Case

# 1. Mevcut yedekleri listele
ls -lh backups/

# 2. Seçilen yedekten geri yükle
./scripts/mongo-restore.sh ./backups/mongodb-YYYYMMDD-HHMMSS.archive.gz

# Script'in yaptığı iş:
#   kubectl exec -i -n dev mern-dev-mongodb-0 -- \
#     mongorestore --archive --gzip --drop < <yedek dosyası>
#
#   --drop bayrağı, geri yüklemeden önce hedef collection'ı siler;
#   böylece restore sonrası duplicate kayıt oluşmaz.

# 3. Doğrula
kubectl exec -n dev mern-dev-mongodb-0 -- mongosh --quiet --eval \
  'print("records count:", db.getSiblingDB("sample_training").records.countDocuments())'
```

Geri yükleme sonrasında uygulamanın yeniden başlatılmasına gerek yoktur; backend her istekte MongoDB'ye bağlandığı için veri anında arayüzde görünür.

## 5. Doğrulama / Verification

Yedeğin bozuk veya eksik olmadığı iki aşamada doğrulanır:

**a) Geri yükleme öncesi — arşiv bütünlüğü.** Arşiv, veriye dokunmadan okunur:

```bash
kubectl exec -i -n dev mern-dev-mongodb-0 -- \
  mongorestore --archive --gzip --dryRun --verbose < ./backups/mongodb-YYYYMMDD-HHMMSS.archive.gz
```

Başarılı bir `--dryRun`, arşivin okunabilir ve tutarlı olduğunu; hangi veritabanı ve collection'ların içerdiğini gösterir. Bozuk veya yarım kalmış bir arşiv bu aşamada hata verir.

**b) Geri yükleme sonrası — kayıt sayısı ve arayüz.** Collection'daki belge sayısı yedek öncesi değerle karşılaştırılır ve uygulamanın Record List sayfasında kayıtların eksiksiz render edildiği gözlemlenir:

```bash
kubectl exec -n dev mern-dev-mongodb-0 -- mongosh --quiet --eval \
  'print("records count:", db.getSiblingDB("sample_training").records.countDocuments())'
```

## 6. Uçtan uca test sonucu / End-to-end test result

Senaryo `dev` ortamında (`sample_training` veritabanı, `records` collection'ı) uçtan uca çalıştırılmış ve her adım kanıtlanmıştır.

| # | Adım / Step | Sonuç / Result | Kanıt / Evidence |
| --- | --- | --- | --- |
| 1 | Arayüzden `BackupTest` kaydı oluşturuldu | Başarılı | `docs/screenshots/13-backup-record-created.png` |
| 2 | `./scripts/mongo-backup.sh` ile yedek alındı, konumu ve boyutu gösterildi | Başarılı | `docs/screenshots/14-backup-taken.png` |
| 3 | `records` collection'ı `drop()` ile silindi | Başarılı | `docs/screenshots/15-collection-dropped.png` |
| 4 | Veritabanında `count: 0`, arayüzde boş tablo gözlendi | Başarılı | `docs/screenshots/16-data-missing-after-drop.png` |
| 5 | `./scripts/mongo-restore.sh` ile yedekten geri yüklendi | Başarılı | `docs/screenshots/17-restore-executed.png` |
| 6 | Aynı kayıt hem veritabanında hem arayüzde geri geldi | Başarılı | `docs/screenshots/18-data-restored-verified.png` |

## 7. Bilinen sınırlamalar / Known limitations

- **Yedekler küme dışında saklanmıyor.** Zamanlanmış yedekler aynı bölgedeki bir EBS PVC'sinde, manuel yedekler operatörün makinesinde duruyor. Küme veya AZ kaybı senaryosunda yedek de kaybolur. Production'da yedekler versiyonlama ve object-lock açık bir **S3 bucket**'ına yazılmalı, yaşam döngüsü kuralı ile Glacier'a taşınmalıdır.
- **Point-in-time recovery yok.** Günlük tam yedek alındığı için RPO 24 saattir. Production'da MongoDB oplog yedeği (`mongodump --oplog`) veya yönetilen bir servis (MongoDB Atlas / DocumentDB) ile dakikalar seviyesinde RPO hedeflenmelidir.
- **Restore otomatik doğrulanmıyor.** Şu an doğrulama manuel yapılıyor. Production'da günlük bir Job, son yedeği tek kullanımlık bir ortama geri yükleyip kayıt sayısını kontrol eder ve başarısızlık durumunda alarm üretirdi.
- **At-rest şifreleme ve ayrı IAM rolü yok.** Production'da yedekler KMS ile şifrelenmeli ve yalnızca yedekleme işlemine yetkili, en az ayrıcalıklı ayrı bir IAM rolü tanımlanmalıdır.
- **Felaket kurtarma tatbikatı düzenli değil.** Production'da çeyrek dönemde bir DR tatbikatı yapılır, ölçülen RTO kayıt altına alınır ve hedefle karşılaştırılırdı.
- **EBS CSI driver manuel kuruldu.** MongoDB'nin kalıcı diski için gereken `aws-ebs-csi-driver` addon'u ve `AmazonEBSCSIDriverPolicy` IAM politikası bu ortamda elle eklendi; Terraform'da `cluster_addons` bloğu ile IRSA üzerinden yönetilmesi gereken bir teknik borçtur.