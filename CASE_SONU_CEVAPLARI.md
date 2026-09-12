# CASE SONU CEVAPLARI

Bu dosyada aşağıdaki soruların tamamını, yaptığınız çalışma ile doğrudan ilişkilendirerek cevaplayın.

Cevaplarınızın kısa, somut ve teknik kararlarınızı açıklayacak düzeyde olması beklenmektedir. Gerekli gördüğünüz yerlerde ilgili kaynak koduna, manifest dosyasına, pipeline adımına veya dokümana dosya yolu vererek referans verebilirsiniz. Çalışma kanıtları ve ekran görüntüleri ayrıca `TESLIM_KANITLARI.md` dosyasında sunulmalıdır.

---

## Aday Bilgileri

- **Ad Soyad:**
- **Repository adresi:**
- **Çalışmanın tamamlandığı tarih:**
- **Kullanılan hedef ortam:** Cloud / Sanal Makine / Yerel Kubernetes / Diğer

---

## 1. Mimari ve İstek Akışı

Kurduğunuz mimariyi ve bir kullanıcı isteğinin frontend’den başlayarak backend ve veritabanına kadar izlediği yolu açıklayın.

Ayrıca sistem bileşenlerini, bileşenler arasındaki bağlantıları, trafik akışını ve dış erişim noktalarını gösteren bir mimari diyagram hazırlayarak proje reposuna aşağıdaki dosyalardan biri olarak ekleyin:

- `docs/architecture.md`
- `docs/architecture.pdf`

Diyagram Mermaid, Draw.io, Excalidraw veya benzeri bir araçla hazırlanabilir. Düzenlenebilir kaynak dosyasının da repoya eklenmesi beklenmektedir.

**Cevap:**

---

## 2. Kritik Bulgular ve Önceliklendirme

Başlangıç projelerinde tespit ettiğiniz en kritik üç sorun neydi? Bu sorunları hangi etki ve risk kriterlerine göre önceliklendirdiniz?

**Cevap:**
1- Backend Veritabanı Bağlantısı: Veritabanı bağlantısı koptuğunda uygulamanın kontrolsüz şekilde çökmesine yol açan durum, uygulamanın Docker/Kubernetes içindeki döngüsünü bozacağı için en kritik riskti. try-catch bloğu yeniden düzenlenip bağlantı hatasında uygulamanın process.exit ile kontrollü şekilde kapanması sağlandı.

2- Frontend isteklerindeki hardcoded API adresleri: Frontend'in backend'e istek atarken http://localhost:5050 adresini koda gömülü olarak kullanması, konteyner mimarisinde tarayıcı hedefi bulamayacağı için tüm adresler ortam değişkenine (process.env.REACT_APP_API_URL) bağlandı. Ingress oluşturulup path routing ile isteklerin backend'e ulaşması sağlandı.

3- Backend Uygulama Portunun Koda Gömülmesi: Uygulama portunun hardcoded olması konteyner ağ yapılandırmasını zorlaştırdığından, port değişkeni process.env.PORT ile dışarıdan alınabilir hale getirildi.

---

## 3. Kapsam Dışında Bırakılan Konular

Hangi sorunları bilinçli olarak düzeltmediniz veya kapsam dışında bıraktınız? Bu kararların gerekçelerini açıklayın.

**Cevap:**

---

## 4. Hedef Ortam Seçimi

Cloud veya sanal makine tercihinin gerekçesi nedir? Gerçek bir production ortamında mevcut çözümden farklı olarak hangi bileşenleri veya yaklaşımları kullanırdınız?

**Cevap:**

---

## 5. MongoDB Yaklaşımı

MongoDB için kullandığınız deployment ve servis yaklaşımını neden seçtiniz? Değerlendirdiğiniz alternatifleri, avantajları, dezavantajları ve operasyonel trade-off’ları açıklayın.

**Cevap:** MongoDB için  bir Dockerfile yazmak yerine Dockerhub üzerindeki official mongo imajı kullanıldı.

Avantajı: Güvenlik patchlerinin, base konfigürasyonların ve optimizasyonların imajda hazır gelmesi sayesinde deployment hızını artırmasıdır.

Dezavantajı (Trade-off): Spesifik OS hardening, custom plugin veya şirket içi compliance gereksinimlerinde esnekliği kısıtlamasıdır. Bu projede standart CRUD operasyonları hedeflendiği için custom konfigürasyon esnekliği yerine stabilite tercih edilmiştir.

---

## 6. Helm veya Manifest Yönetimi

Çözümünüzde Helm kullandıysanız neden tercih ettiğinizi ve Helm’in bu projede hangi problemi çözdüğünü açıklayın.

Düz Kubernetes manifestleri veya Kustomize gibi alternatiflerle karşılaştırıldığında sağladığı avantajları ve oluşturduğu ek karmaşıklığı belirtin.

Helm kullanmadıysanız tercih ettiğiniz yöntemi ve seçim gerekçenizi açıklayın.

**Cevap:**

---

## 7. Kubernetes Service Tipleri

Kubernetes Service tiplerini hangi kriterlere göre belirlediniz?

Her servis için neden `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName` veya headless Service tercih ettiğinizi açıklayın. Hangi servislerin cluster dışından erişilebilir olması gerektiğini ve gereksiz dış erişimi nasıl engellediğinizi belirtin.

**Cevap:**

---

## 8. Kubernetes Workload Türleri

Uygulama bileşenleri için kullandığınız iş yükü (workload) türlerini hangi kriterlere göre seçtiniz?

Frontend, backend, MongoDB ve ETL bileşenlerinde neden `Deployment`, `StatefulSet`, `Job`, `CronJob` veya farklı bir workload türü kullandığınızı açıklayın.

Karar verirken aşağıdaki konuları nasıl değerlendirdiğinizi belirtin:

- Stateless veya stateful çalışma modeli
- Kalıcı depolama ihtiyacı
- Pod kimliği ve sıralı çalışma gereksinimi
- Çalışma sıklığı
- Yeniden başlatma davranışı
- Ölçeklenebilirlik ihtiyacı

**Cevap:**

---

## 9. Konfigürasyon ve Secret Yönetimi

Uygulama konfigürasyonlarını ve secret bilgilerini nasıl yönettiniz?

**Cevap:** Tüm bağlantı adresleri (API URL, DB URI) hardcoded halinden çıkarılarak external hale getirildi. Değerler environment değişkenleri aracılığıyla runtime'da veya build stage'de (ARG, ENV) konteynerlere pass edildi. Secret'ların image katmanlarına sızmaması için .env dosyaları .dockerignore listesine eklenerek build context'ten izole edildi.

Bir secret değeri değiştirildiğinde veya yenilendiğinde uygulamanın yeni değeri güvenli şekilde kullanmasını nasıl sağlarsınız?

**Cevap:** Bir secret değiştiğinde kodu re-build etmeye gerek kalmaz. Yeni konfigürasyon güncellenir ve pod'ların rolling restart işlemiyle downtime olmadan yeni değerleri okuması sağlanır.

---

## 10. MongoDB Erişim Problemi

MongoDB erişilemez hale gelirse backend uygulaması, readiness/liveness kontrolleri ve kullanıcı istekleri nasıl davranır?

Kullanıcı etkisini azaltmak ve servisin kontrollü şekilde toparlanmasını sağlamak için hangi önlemleri aldınız veya alırdınız?

**Cevap:**

---

## 11. Hatalı Deployment ve Rollback

Hatalı bir sürüm deploy edildiğinde problemi nasıl tespit edersiniz?

Rollback işlemini hangi yöntemle gerçekleştirirsiniz ve önceki çalışan sürümün güvenli şekilde devreye alındığını nasıl doğrularsınız?

**Cevap:**

---

## 12. Ölçeklenebilirlik ve Darboğazlar

Trafik 10 kat arttığında ilk darboğazın nerede oluşmasını beklersiniz?

Hangi bileşenleri, hangi metriklere ve eşiklere göre ölçeklersiniz? Veritabanı bağlantıları, kaynak kullanımı ve bağımlı servisleri nasıl değerlendirirsiniz?

**Cevap:**

---

## 13. Logging, Monitoring ve Alarm Yönetimi

Hangi logları, metrikleri ve alarmları oluşturdunuz?

Bir incident sırasında problemi teşhis etmek için ilk olarak hangi dashboard, log, metrik veya alarm kayıtlarını incelersiniz?

**Cevap:**

---

## 14. Güvenlik Riskleri

Çözümünüzde gördüğünüz en önemli üç güvenlik riski nedir?

Bu riskleri azaltmak için uyguladığınız veya production ortamında uygulayacağınız kontrolleri açıklayın.

**Cevap:**

---

## 15. Python ETL Güncelleme Yaklaşımı

Python ETL aynı repository bilgisini tekrar aldığında mevcut kaydı nasıl bulup güncelliyor? 
Benzersiz kayıt anahtarı olarak hangi alanı kullandınız ve duplicate oluşmadığını hangi ekran görüntüsü veya çıktı ile gösterdiniz?

**Cevap:**
Python ETL scripti, GitHub API'den dönen JSON yanıtındaki orijinal id değerini alıp, MongoDB tarafında github_id isimli benzersiz bir anahtar (unique key) olarak kullanmaktadır.
Veritabanı operasyonu için PyMongo'nun update_one() fonksiyonu, upsert=True parametresiyle kullanıldı. Bu şekilde db öncelikle verilen github_id değerini arar, eğer kayıt yoksa veriyi yeni bir doküman olarak insert eder, kayıt zaten mevcutsa yeni kayıt oluşturmak yerine eldeki mevcut dokümanı update eder.

Duplicate oluşmadığı ve güncellemenin başarıyla yapıldığına dair kanıtlar, TESLIM_KANITLARI.md dosyasında şu görsellerle gösterilmiştir:  
    11-etl-update-without-duplicate-1.png (Arayüzde manuel değişiklik yapılan an)
    11-etl-update-without-duplicate-2.png (Script 2. defa çalıştıktan sonraki log ve arayüzdeki düzelme)

---

## 16. Backup ve Restore Yaklaşımı

MongoDB için hangi yedekleme yöntemini ve saklama konumunu seçtiniz?

Yedekleme sıklığı, retention süresi, RPO ve RTO hedefleriniz nedir ve ölçtüğünüz gerçek geri yükleme süresi ne kadar oldu?

Yedeğin bozuk veya eksik olmasına karşı hangi doğrulamayı yaparsınız; gerçek bir production ortamında bu yaklaşımı nasıl farklılaştırırdınız?

Runbook’unuzu `docs/backup-restore.md` içinde paylaşın ve kanıtları `TESLIM_KANITLARI.md` dosyasından referanslayın.

**Cevap:**

---

## Ek Notlar

Case kapsamında özellikle belirtmek istediğiniz ek kararlar, sınırlamalar veya sonraki geliştirme adımları varsa bu bölümde açıklayabilirsiniz.

**Cevap:**
