# CASE SONU CEVAPLARI

Bu dosyada aşağıdaki soruların tamamını, yaptığınız çalışma ile doğrudan ilişkilendirerek cevaplayın.

Cevaplarınızın kısa, somut ve teknik kararlarınızı açıklayacak düzeyde olması beklenmektedir. Gerekli gördüğünüz yerlerde ilgili kaynak koduna, manifest dosyasına, pipeline adımına veya dokümana dosya yolu vererek referans verebilirsiniz. Çalışma kanıtları ve ekran görüntüleri ayrıca `TESLIM_KANITLARI.md` dosyasında sunulmalıdır.

---

## Aday Bilgileri

- **Ad Soyad:** Emre Arabacıoğlu
- **Repository adresi:** https://github.com/emrearabacioglu/devops-case
- **Çalışmanın tamamlandığı tarih:** 13/09/2026
- **Kullanılan hedef ortam:** Cloud

---

## 1. Mimari ve İstek Akışı

Kurduğunuz mimariyi ve bir kullanıcı isteğinin frontend’den başlayarak backend ve veritabanına kadar izlediği yolu açıklayın.

Ayrıca sistem bileşenlerini, bileşenler arasındaki bağlantıları, trafik akışını ve dış erişim noktalarını gösteren bir mimari diyagram hazırlayarak proje reposuna aşağıdaki dosyalardan biri olarak ekleyin:

- `docs/architecture.md`
- `docs/architecture.pdf`

Diyagram Mermaid, Draw.io, Excalidraw veya benzeri bir araçla hazırlanabilir. Düzenlenebilir kaynak dosyasının da repoya eklenmesi beklenmektedir.

**Cevap:**
Altyapı IaC prensibiyle AWS üzerinde Terraform yerel modülleri (`vpc`, `eks`) kullanarak izole bir ortam olarak kurulmuştur. İstek akışı şu şekildedir:
1. Kullanıcı tarayıcı üzerinden AWS Application Load Balancer'a HTTP isteği atar.
2. Trafik EKS içindeki NGINX Ingress Controller'a ulaşır. 
3. Ingress, path-based routing ile root `/` isteklerini frontend podlarına, `/record` ve `/healthcheck` isteklerini backend podlarına yönlendirir. 
4. Backend podları veritabanı işlemleri için dışarıya tamamen kapalı olan MongoDB poduyla ClusterIP üzerinden haberleşir. 
5. Python ETL, CronJob nesnesi olarak çalışıp dışarıdan GitHub API'sini sorgular ve çektiği verileri doğrudan MongoDB'ye yazar.

*(Mimari diyagram proje reposunda `docs/architecture.md` / `docs/architecture.pdf` içerisinde sunulmuştur).*

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

**Cevap:**Zaman ve kaynak kısıtları nedeniyle MongoDB için Replica Set (High Availability) mimarisi ve kalıcı depolama (AWS EBS - Persistent Volume) yapılandırması kapsam dışında bırakılıp stateless deployment olarak çalıştırılmıştır. Ingress üzerinde AWS Certificate Manager kullanılarak HTTPS yapılandırması custom domain kısıtları nedeniyle es geçilmiştir. Podlar arası iletişimi kısıtlayan detaylı NetworkPolicy kuralları yazılmamıştır.

---

## 4. Hedef Ortam Seçimi

Cloud veya sanal makine tercihinin gerekçesi nedir? Gerçek bir production ortamında mevcut çözümden farklı olarak hangi bileşenleri veya yaklaşımları kullanırdınız?

**Cevap:**Hedef ortam olarak AWS EKS (Cloud) seçilmiştir. Temel neden Infrastructure as Code pratiklerini ve Jenkins CI/CD otomasyonunu  production standartlarında sergilemektir. Gerçek bir production ortamında veritabanı EKS içinde tutulmaz, operasyonel yükü almak için AWS DocumentDB veya MongoDB Atlas kullanılırdı. Frontend statik dosyaları ise EKS podlarında koşmak yerine S3 bucket üzerine yüklenip CloudFront üzerinden sunulurdu.

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

**Cevap:** Projede kubernetes nesnelerini yönetmek için Helm kullanılmıştır. Helm'in çözdüğü temel problemö ortam (dev, test, prod) parametrelerinin ve Jenkins pipeline'ında dinamik üretilen image etiketlerinin (`${BUILD_NUMBER}`) tek bir `values.yaml` dosyası üzerinden `--set` komutuyla koda manuel dokunmadan override edilebilmesidir. Ayrıca `--atomic` parametresiyle hatalı sürümlerde rollback işlemlerini otomatikleştirir. Düz manifestlere göre dezavantajı Go Template syntaxını öğrenme ve yönetme karmaşıklığıdır.

---

## 7. Kubernetes Service Tipleri

Kubernetes Service tiplerini hangi kriterlere göre belirlediniz?

Her servis için neden `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName` veya headless Service tercih ettiğinizi açıklayın. Hangi servislerin cluster dışından erişilebilir olması gerektiğini ve gereksiz dış erişimi nasıl engellediğinizi belirtin.

**Cevap:**Güvenlik kuralı (Zero Trust) gereği Frontend, Backend ve MongoDB servislerinin tamamı `ClusterIP` yapılmıştır. Servisler dışarıya `NodePort` veya `LoadBalancer` ile gereksiz yere açılmamıştır. Sadece dışarıdan erişim sağlanması beklenen Frontend ve Backend API tek giriş noktası olan NGINX Ingress Controller arkasında toplanmış ve sadece Ingress Controller AWS üzerinde bir `LoadBalancer` olarak ayağa kaldırılmıştır.

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
- **Frontend ve Backend:** Stateless yapıda oldukları ve artan trafikte yatayda kolayca replicate edilip ölçeklenebilmeleri için `Deployment` kullanılmıştır.
- **MongoDB:** Projede kısıtlar gereği Deployment kullanılsa da, production ortamında verinin diskte kalıcılığı ve ağ kimliğinin sabitliği için `StatefulSet` kullanılmalıdır.
- **Python ETL:** Arkaplanda sürekli çalışıp kaynak tüketmesine gerek olmayan, saat başı Github'dan veri çekip işi bitince kapanması gereken bir süreç olduğu için `CronJob` seçilmiştir. Kurulum anında ilk veri yüklemesi için ise Helm `post-install` hooku ile bir kerelik `Job` kullanılmıştır.

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

**Cevap:**Backend koduna eklenen `try-catch` mekanizması sayesinde MongoDB erişilemez olursa backend takılı kalmak yerine `process.exit(1)` ile çöker. Kubernetes liveness/readiness probları bunu algılar, podu `CrashLoopBackOff` durumuna alır ve Ingress o poddan trafiği keser. Kullanıcı arayüzde HTTP 502/503 hatası alır. Etkiyi azaltmak için Ingress seviyesinde bir uyarı/error sayfası tanımlanabilir.

---

## 11. Hatalı Deployment ve Rollback

Hatalı bir sürüm deploy edildiğinde problemi nasıl tespit edersiniz?

Rollback işlemini hangi yöntemle gerçekleştirirsiniz ve önceki çalışan sürümün güvenli şekilde devreye alındığını nasıl doğrularsınız?

**Cevap:**Hatalı bir deployment, jenkins pipelineındaki `smoke test` aşamasında çalıştırılan `kubectl rollout status` komutunun timeouta düşmesiyle anında tespit edilir. Rollback işlemi,, helm upgrade komutunda kullanılan `--atomic` ve `--wait` flagleri sayesinde otomatiktir. Dağıtım 5 dakika içinde sağlıklı duruma geçmezse, helm işlemi iptal edip clusterı otomatik olarak çalışan bir önceki versiyona güvenle geri döndürür.

---

## 12. Ölçeklenebilirlik ve Darboğazlar

Trafik 10 kat arttığında ilk darboğazın nerede oluşmasını beklersiniz?

Hangi bileşenleri, hangi metriklere ve eşiklere göre ölçeklersiniz? Veritabanı bağlantıları, kaynak kullanımı ve bağımlı servisleri nasıl değerlendirirsiniz?

**Cevap:** Trafik 10 kat arttığında ilk darboğazın Backend (Node.js) Event Loop işlemci limitlerinde ve MongoDB Connection Pool (bağlantı havuzu) tükenmesinde oluşması beklenir.
Ölçekleme için Kubernetes HPA (Horizontal Pod Autoscaler) devreye alınarak CPU %70 eşiğini geçtiğinde backend pod sayısı yatayda artırılır. Database tarafında read yükü artacağı için MongoDB Replica Set kurularak okuma istekleri bu node'lara dağıtılır.

---

## 13. Logging, Monitoring ve Alarm Yönetimi

Hangi logları, metrikleri ve alarmları oluşturdunuz?

Bir incident sırasında problemi teşhis etmek için ilk olarak hangi dashboard, log, metrik veya alarm kayıtlarını incelersiniz?

**Cevap:** EKS cluster üzerinde AWS CloudWatch logları ve pod bazında stdout/stderr logları (`kubectl logs`) izlenmektedir. Ayrıca Jenkins pipeline failure durumlarında konsola log basacak post-action kurgulanmıştır. Bir incident anında problemi teşhis etmek için ilk olarak Ingress Controller loglarındaki HTTP 5xx hata oranlarına ve endpoint bağlantı kopmalarına bakarım. Ardından çöken Backend veya ETL pod'unun uygulama loglarını incelerim.

---

## 14. Güvenlik Riskleri

Çözümünüzde gördüğünüz en önemli üç güvenlik riski nedir?

Bu riskleri azaltmak için uyguladığınız veya production ortamında uygulayacağınız kontrolleri açıklayın.

**Cevap:**
1. **Konteyner Root İzinleri:** Konteynerlerin varsayılan olarak root yetkisiyle çalışması (ETL Dockerfile'ında `useradd etluser` komutuyla ayrı kullanıcı oluşturularak önlenmiştir).
2. **Açık Portlar ve İfşa:** Servislerin NodePort veya LoadBalancer ile doğrudan internete açılması (ClusterIP ve NGINX Ingress kalkanı ile önlenmiştir).
3. **State Dosyasının Açıkta Olması:** IaC altyapı kodlarının makinede düz metin kalması yerine AWS S3 Backend kullanılarak izole edilmiş ve şifrelenmesi sağlanmıştır.

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

**Cevap:**Yedekleme yöntemi olarak Kubernetes içinde çalıştırılan `mongodump` ve `mongorestore` araçları ile manuel arşiv (BSON/JSON) yedeği alınması yöntemi kullanılmıştır. Detaylı RTO, RPO hedefleri ve çalıştırma adımları `docs/backup-restore.md` dosyasında sunulmuştur. Kanıtları `TESLIM_KANITLARI.md` içinde belgelenmiştir. Gerçek bir production ortamında bu manuel yöntem yerine snapshot tabanlı EBS yedeklemesi kullanılarak cluster bazlı felaket kurtarma (DR) stratejisi oluşturulabilirdi.

---

## Ek Notlar

Case kapsamında özellikle belirtmek istediğiniz ek kararlar, sınırlamalar veya sonraki geliştirme adımları varsa bu bölümde açıklayabilirsiniz.

**Cevap:**Projede altyapı kodlaması (IaC) için AWS üzerinde Terraform yerel modülleri (vpc, eks) kullanılmış, yapı environment bazlı (dev/test/prod) kurulabilir hale getirilmiştir. CI/CD pipeline'ında Parallel Build özelliğiyle Docker imaj derleme süreleri optimize edilmiş, Helm ile tek bir parametre (`ENV_NAME`) üzerinden altyapı ve kod dağıtımı tam senkronize edilerek sıfır kesintili (Atomic deployment) bir akış yaratılmıştır. Jenkinsfile'da Hardcoded AWS Key'ler yerine Jenkins Credentials mekanizması ile güvenlik artırılmış, Terraform State dosyası AWS S3'e taşınarak state bütünlüğü sağlanmıştır.
