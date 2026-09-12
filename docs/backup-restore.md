# Backup & Restore Runbook

Bu dosya aday tarafından doldurulur. / This file is to be filled in by the candidate.

Kanıt ekran görüntüleri `TESLIM_KANITLARI.md` (TR) veya `SUBMISSION_EVIDENCE.md` (EN) dosyasından referanslanmalıdır.
Evidence screenshots must be referenced from `TESLIM_KANITLARI.md` (TR) or `SUBMISSION_EVIDENCE.md` (EN).

---

## 1. Yaklaşım / Approach

| | |
| --- | --- |
| Yedekleme yöntemi | `mongodump` ve `mongorestore` araçları ile BSON formatında arşiv yedeği alma. |
| Nasıl çalıştırılıyor | Kubernetes `kubectl exec` komutları üzerinden manuel çalıştırılıyor. |
| Yedeğin saklandığı konum | MongoDB pod'unun yerel dosya sistemi (`/tmp`). Gerçek senaryoda AWS S3 kullanılmalıdır. |
| Yedek formatı ve boyutu | Sıkıştırılmış `.archive` BSON formatı. |
| Sıklık | Günde 1 kez (Daily). |
| Retention süresi | 7 Gün. |
| Şifreleme ve erişim | Beklemede (at-rest) şifreleme yoktur. Kubernetes RBAC yetkileri ile erişim kısıtlanmıştır. |

## 2. Hedefler / Targets

| | Hedef / Target | Ölçülen / Measured |
| --- | --- | --- |
| RPO | 24 Saat | 0 (Manuel tetiklendiği an) |
| RTO | 15 Dakika | < 1 Dakika |

## 3. Yedek alma adımları / Backup procedure

```bash
# komutlar / commands
```

## 4. Geri yükleme adımları / Restore procedure

```bash
# 1. MongoDB Pod ismini bir değişkene atama
POD_NAME=$(kubectl get pods -n prod -l app.kubernetes.io/name=mongodb -o jsonpath='{.items[0].metadata.name}')

# 2. Veritabanının arşiv yedeğini alma (devops isimli db)
kubectl exec -n prod $POD_NAME -- mongodump --db devops --archive=/tmp/devops-backup.archive
```

## 5. Doğrulama / Verification

Yedeğin bozuk veya eksik olmadığı nasıl doğrulanıyor?
How is it verified that the backup is not corrupted or incomplete?

Geri yükleme sonrasında 
`kubectl exec -n prod $POD_NAME -- mongosh devops --eval "db.records.countDocuments()"`
komutu ile koleksiyondaki belge sayısı sayılarak ve uygulamanın web arayüzüne girilerek verilerin eksiksiz render edilip edilmediği gözlemlenerek doğrulanır.

## 6. Uçtan uca test sonucu / End-to-end test result

Aşağıdaki senaryonun çalıştırıldığı tarih ve sonuç:
Date and result of the executed scenario:

| # | Adım / Step | Sonuç / Result | Kanıt / Evidence |
| --- | --- | --- | --- |
| 1 | Kayıt oluşturuldu / Record created | Başarılı/Success | `docs/screenshots/13-backup-record-created.png` |
| 2 | Yedek alındı / Backup taken | Başarılı/Success | `docs/screenshots/14-backup-taken.png` |
| 3 | Collection/DB silindi / Collection or DB dropped | Başarılı/Success | `screenshots/15-collection-dropped.png` |
| 4 | Verinin kaybolduğu görüldü / Data confirmed gone | Başarılı/Success | `docs/screenshots/16-data-missing-after-drop.png` |
| 5 | Yedekten geri yüklendi / Restored from backup | Başarılı/Success | `docs/screenshots/17-restore-executed.png` |
| 6 | Veri geri geldi / Data confirmed back | Başarılı/Success | `docs/screenshots/18-data-restored-verified.png` |

## 7. Bilinen sınırlamalar / Known limitations

Bu çözümün production ortamında eksik kalan yönleri ve nasıl geliştirileceği.
Gaps of this solution in a production environment and how you would improve it.


Bu çözüm, yedek dosyasını pod'un kendi uçucu (ephemeral) dosya sisteminde (/tmp) tutmaktadır. Pod silinirse yedek kaybolur. Production ortamında Kubernetes CronJob'ları aracılığıyla otomatikleştirilmeli ve alınan yedekler aws s3 cp komutu ile güvenli bir Object Storage (AWS S3) servisine aktarılmalıdır. Ayrıca AWS EBS Snapshot veya Velero entegrasyonu değerlendirilmelidir.