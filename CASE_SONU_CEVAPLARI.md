# CASE SONU CEVAPLARI

Bu dosyada aşağıdaki soruların tamamını, yaptığınız çalışma ile doğrudan ilişkilendirerek cevaplayın.

Cevaplarınızın kısa, somut ve teknik kararlarınızı açıklayacak düzeyde olması beklenmektedir. Gerekli gördüğünüz yerlerde ilgili kaynak koduna, manifest dosyasına, pipeline adımına veya dokümana dosya yolu vererek referans verebilirsiniz. Çalışma kanıtları ve ekran görüntüleri ayrıca `TESLIM_KANITLARI.md` dosyasında sunulmalıdır.

---

## Aday Bilgileri

- **Ad Soyad:** Emre Arabacıoğlu
- **Repository adresi:** https://github.com/emrearabacioglu/devops-case
- **Çalışmanın tamamlandığı tarih:** 13/09/2026
- **Kullanılan hedef ortam:** AWS

---

## 1. Mimari ve İstek Akışı

Kurduğunuz mimariyi ve bir kullanıcı isteğinin frontend’den başlayarak backend ve veritabanına kadar izlediği yolu açıklayın.

Ayrıca sistem bileşenlerini, bileşenler arasındaki bağlantıları, trafik akışını ve dış erişim noktalarını gösteren bir mimari diyagram hazırlayarak proje reposuna aşağıdaki dosyalardan biri olarak ekleyin:

- `docs/architecture.md`
- `docs/architecture.pdf`

Diyagram Mermaid, Draw.io, Excalidraw veya benzeri bir araçla hazırlanabilir. Düzenlenebilir kaynak dosyasının da repoya eklenmesi beklenmektedir.

**Cevap:**
Altyapı IaC prensibiyle AWS üzerinde Terraform yerel modülleri (`terraform/modules/vpc`, `terraform/modules/eks`) kullanılarak izole bir ortam olarak kurulmuştur. Worker node'lar private subnet'lerde çalışır, dışarıya çıkışları tek bir NAT Gateway üzerindendir. İstek akışı şu şekildedir:

1. Kullanıcı tarayıcı üzerinden, NGINX Ingress Controller'ın `LoadBalancer` tipindeki Service'i tarafından otomatik provision edilen AWS Elastic Load Balancer'a (Classic LB) HTTP isteği gönderir.
2. Trafik EKS içindeki NGINX Ingress Controller pod'larına ulaşır (`ingress-basic` namespace'i).
3. Ingress (`mern-stack-chart/templates/ingress.yaml`), path-based routing ile `/` isteklerini frontend pod'larına, `/record` ve `/healthcheck` isteklerini backend pod'larına yönlendirir.
4. Backend pod'ları veritabanı işlemleri için, küme dışına kapalı olan MongoDB ile ClusterIP Service üzerinden haberleşir (`ATLAS_URI=mongodb://<release>-mongodb:27017`). MongoDB verisi, StatefulSet'in `volumeClaimTemplates` bloğu ile gp2 EBS diski üzerinde PersistentVolumeClaim olarak kalıcı tutulur.
5. Python ETL, CronJob olarak saatte bir çalışır; NAT Gateway üzerinden GitHub API'sini sorgular ve çektiği veriyi doğrudan MongoDB'ye yazar. Kurulum ve her upgrade sonrasında veriyi tazelemek için ayrıca bir Helm hook Job'u (`templates/etl-hook.yaml`, `post-install,post-upgrade`) çalışır.

Uygulama trafiği için kümeye tek giriş noktası ELB'dir; frontend, backend ve MongoDB Service'lerinin tamamı `ClusterIP` tipindedir. Bunun dışında EKS control plane API endpoint'i yönetim amacıyla public'tir (`cluster_endpoint_public_access = true`); Jenkins `helm upgrade` ve `kubectl` çağrılarını bu endpoint üzerinden yapar. Bu ikinci giriş noktasının IP allowlist'i ile kısıtlanması gerektiği Soru 14'te teknik borç olarak belirtilmiştir.

Dağıtım Jenkins pipeline'ı üzerinden Helm ile yapılır; imajlar Docker Hub'dan çekilir.

*(Mimari diyagram `docs/architecture.md` içerisinde Mermaid formatında sunulmuştur; dosyanın kendisi düzenlenebilir kaynaktır.)*

---

## 2. Kritik Bulgular ve Önceliklendirme

Başlangıç projelerinde tespit ettiğiniz en kritik üç sorun neydi? Bu sorunları hangi etki ve risk kriterlerine göre önceliklendirdiniz?

**Cevap:**
Önceliklendirme üç kritere göre yapılmıştır: **(a) kullanıcı etkisi** (sorun uygulamayı tamamen kullanılamaz hale getiriyor mu), **(b) konteyner/Kubernetes yaşam döngüsüne etkisi** (platformun sorunu yönetebilmesini engelliyor mu), **(c) düzeltme maliyeti**. Tespit edilen bulguların tamamı ve çözümleri `docs/findings.md` dosyasındadır; en kritik üçü aşağıdadır.

1. **Backend veritabanı bağlantısında yakalanmamış hata (`mern-project/server/db/conn.mjs`) — Yüksek.** Bağlantı koptuğunda uygulama `TypeError` ile kontrolsüz şekilde çöküyor, Kubernetes'in restart/backoff mekanizmasının anlamlı çalışmasını engelliyordu. `try-catch` bloğu yeniden düzenlenip, bağlantı hatasında hatanın loglanması ve `process.exit(1)` ile kontrollü kapanış sağlandı. Bu sayede pod'un durumu platform tarafından doğru yorumlanabiliyor.

2. **Frontend isteklerindeki hardcoded API adresleri (`recordList.js`, `create.js`, `edit.js`, `healthcheck.js`) — Yüksek.** Frontend'in backend'e istek atarken `http://localhost:5050` adresini koda gömülü kullanması, konteyner/Kubernetes mimarisinde tarayıcının hedefi bulamamasına yol açıyordu. Tüm adresler `process.env.REACT_APP_API_URL` ortam değişkenine bağlandı; Ingress oluşturulup path routing ile (`/record`, `/healthcheck`) isteklerin backend'e ulaşması sağlandı.

3. **Backend port ve veritabanı adının koda gömülmesi (`server.mjs`, `db/conn.mjs`) — Orta/Düşük.** Aynı imajın farklı ortamlarda farklı port ve veritabanı adıyla çalıştırılmasını engelliyordu. `process.env.PORT` ve `process.env.DB_NAME` ile dışarıdan konfigüre edilebilir hale getirildi. Tek başına servisi düşürmediği için üçüncü sıraya alınmıştır.

---

## 3. Kapsam Dışında Bırakılan Konular

Hangi sorunları bilinçli olarak düzeltmediniz veya kapsam dışında bıraktınız? Bu kararların gerekçelerini açıklayın.

**Cevap:**
Aşağıdaki konular zaman, maliyet ve case kapsamı gerekçeleriyle bilinçli olarak kapsam dışında bırakılmıştır:

- **MongoDB Replica Set (High Availability).** Veritabanı tek replikalı bir `StatefulSet` olarak çalıştırılmıştır. *Kalıcı depolama kapsam dışı değildir ve uygulanmıştır:* `volumeClaimTemplates` ile gp2/EBS üzerinde 5Gi PersistentVolumeClaim bağlanmıştır. Kapsam dışı olan yalnızca çok replikalı Replica Set mimarisi ve failover'dır.
- **MongoDB authentication.** Veritabanı `--auth` olmadan çalıştırılmıştır; Service `ClusterIP` olduğu ve küme dışına kapalı olduğu için case kapsamında kabul edilebilir bulunmuştur. Production'da kabul edilemez (bkz. Soru 9 ve Soru 14).
- **Liveness/Readiness probe tanımları.** Helm şablonlarına probe eklenmemiştir. Backend'in bağlantı hatasında `process.exit(1)` ile kapanması, pod'un `Ready` olmamasını ve Endpoints'ten düşmesini zaten sağladığı için case kapsamında yeterli görülmüştür; ancak bu, kontrollü toparlanma açısından eksik bir tercihtir (bkz. Soru 10).
- **HPA ve otomatik ölçekleme.** `metrics-server` kurulumu ve tüm ortamlar için resource request tanımı gerektirdiğinden uygulanmamış, yaklaşım Soru 12'de tarif edilmiştir.
- **HTTPS/TLS.** Ingress üzerinde AWS Certificate Manager ile HTTPS yapılandırması, elde doğrulanabilir bir custom domain bulunmadığı için yapılmamıştır.
- **NetworkPolicy.** Pod'lar arası doğu-batı trafiğini kısıtlayan kurallar yazılmamıştır; mevcut durumda küme içindeki herhangi bir pod MongoDB'ye erişebilir.
- **Pod seviyesinde `securityContext`.** İmajlar non-root kullanıcıyla çalışacak şekilde hazırlanmıştır (bkz. Soru 14) ancak `runAsNonRoot`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem` gibi pod seviyesi kısıtlar şablonlara eklenmemiştir.
- **Merkezi log toplama ve imaj güvenlik taraması.** Fluent Bit/CloudWatch Logs veya Loki ile merkezi log toplama ve pipeline'a Trivy benzeri bir imaj tarama adımı eklenmemiştir.
- **Monorepo tercihi.** Gerçek bir senaryoda her ortam için ayrı branch/repo ve Terraform kodu için ayrı bir repository kullanılırdı. Bu case'de çalışmanın bütün halde ve tek noktadan incelenebilmesi amacıyla tüm bileşenler tek repository'de toplanmış, ortam ayrımı ayrı repo yerine Helm values dosyaları ve pipeline parametresi (`ENV_NAME`) ile yapılmıştır.

---

## 4. Hedef Ortam Seçimi

Cloud veya sanal makine tercihinin gerekçesi nedir? Gerçek bir production ortamında mevcut çözümden farklı olarak hangi bileşenleri veya yaklaşımları kullanırdınız?

**Cevap:**
Hedef ortam olarak AWS EKS (Cloud) seçilmiştir. Temel neden, Infrastructure as Code pratiklerini ve Jenkins CI/CD otomasyonunu production'a yakın koşullarda sergileyebilmek; managed control plane, EBS CSI üzerinden kalıcı depolama ve LoadBalancer entegrasyonu gibi yönetilen bileşenlerden yararlanmaktır. Pipeline'daki `ENV_NAME` parametresi hem `TF_VAR_env_prefix` olarak Terraform'a hem de Helm values seçimine beslendiği için her ortam kendi VPC ve EKS cluster'ıyla ayağa kalkar; izolasyon tamdır, karşılığında maliyet yüksektir.

Gerçek bir production ortamında farklı yapacaklarım:

- **Veritabanı EKS içinde tutulmazdı.** Operasyonel yükü (yedekleme, patch, failover) devretmek için Amazon DocumentDB veya MongoDB Atlas kullanılırdı.
- **Frontend statik dosyaları pod'da servis edilmezdi.** Build çıktısı S3'e yüklenip CloudFront üzerinden dağıtılır, böylece hem maliyet hem gecikme düşerdi.
- **Ingress katmanı.** Classic LB yerine AWS Load Balancer Controller ile ALB kullanılır, TLS sonlandırma ACM sertifikasıyla ALB üzerinde yapılırdı.
- **İmaj kayıt defteri.** Docker Hub yerine, IAM ile entegre ve imaj taraması yerleşik olan Amazon ECR kullanılırdı.
- **Erişim.** EKS API endpoint'i private (veya IP allowlist'li) olur, pod'ların AWS servislerine erişimi IRSA ile en az ayrıcalık prensibine göre verilirdi.
- **Ortam ayrımı.** Ortam başına ayrı AWS hesabı ve ayrı Terraform state/workspace kullanılırdı.

---

## 5. MongoDB Yaklaşımı

MongoDB için kullandığınız deployment ve servis yaklaşımını neden seçtiniz? Değerlendirdiğiniz alternatifleri, avantajları, dezavantajları ve operasyonel trade-off’ları açıklayın.

**Cevap:**
MongoDB, `mern-stack-chart/templates/mongodb.yaml` içinde **`StatefulSet` + `volumeClaimTemplates` (gp2/EBS, 5Gi)** olarak, önünde **`ClusterIP` Service** ile çalıştırılmıştır.

**Workload tercihi.** StatefulSet seçilmesinin nedeni, pod yeniden yaratıldığında aynı PVC'ye deterministik şekilde yeniden bağlanması ve pod kimliğinin sabit kalmasıdır (`mern-dev-mongodb-0`). Bu sabitlik operasyonel olarak da işime yaradı: `scripts/mongo-backup.sh` ve `scripts/mongo-restore.sh` scriptleri yedek alırken pod adını deterministik olarak hedefleyebiliyor.

**Service tercihi.** MongoDB'nin küme dışından erişilmesi gereken hiçbir senaryo yok; bu nedenle `ClusterIP` seçilmiş, NodePort/LoadBalancer değerlendirilmemiştir bile. Tek replikalı kurulumda pod başına DNS kaydına ihtiyaç duyulmadığı için Service headless (`clusterIP: None`) yapılmamıştır; Replica Set'e geçildiğinde StatefulSet'in governing service'inin headless olması gerekir, bu bilinen bir teknik borçtur.

**Değerlendirilen alternatifler ve trade-off'lar:**

| Alternatif | Avantaj | Dezavantaj / neden seçilmedi |
| --- | --- | --- |
| `Deployment` + tek PVC | Daha basit şablon | ReadWriteOnce bir EBS diskinde rolling update sırasında iki pod aynı diske bağlanmaya çalışır; veri bütünlüğü riski |
| Bitnami MongoDB Helm chart'ı | Auth, Replica Set, metrics exporter hazır gelir | Chart'ın kendisi ek bağımlılık ve konfigürasyon yüzeyi; case'in amacı Kubernetes nesnelerini bilerek tanımlamak olduğu için tercih edilmedi |
| Managed servis (DocumentDB / Atlas) | Yedekleme, failover, patch yönetimi devredilir | Maliyet ve vendor bağımlılığı; ayrıca case'in "Kubernetes üzerinde veritabanı yönetimi" boyutunu ortadan kaldırırdı. Production tercihim budur (bkz. Soru 4) |

**İmaj tercihi.** MongoDB için ayrı bir Dockerfile yazmak yerine Docker Hub üzerindeki resmi `mongo` imajı kullanıldı. Avantajı, güvenlik yamalarının ve base konfigürasyonun hazır gelmesi; dezavantajı (trade-off) ise spesifik OS hardening, custom plugin veya şirket içi compliance gereksinimlerinde esnekliği kısıtlamasıdır. Bu projede standart CRUD operasyonları hedeflendiği için custom konfigürasyon esnekliği yerine stabilite tercih edilmiştir.

**Mevcut yaklaşımın operasyonel sınırları:** tek replika olduğu için node kaybında veri erişilemez hale gelir (veri PVC'de durur, kayıp yaşanmaz); authentication kapalıdır; bu iki eksik production'da ilk kapatılacak maddelerdir.

---

## 6. Helm veya Manifest Yönetimi

Çözümünüzde Helm kullandıysanız neden tercih ettiğinizi ve Helm’in bu projede hangi problemi çözdüğünü açıklayın.

Düz Kubernetes manifestleri veya Kustomize gibi alternatiflerle karşılaştırıldığında sağladığı avantajları ve oluşturduğu ek karmaşıklığı belirtin.

Helm kullanmadıysanız tercih ettiğiniz yöntemi ve seçim gerekçenizi açıklayın.

**Cevap:**
Projede Kubernetes nesnelerini yönetmek için Helm kullanılmıştır (`mern-stack-chart/`).

**Çözdüğü problem.** İki eksen var: (1) ortam farkları — `values.yaml` temel değerleri tutar, `values-dev.yaml`, `values-test.yaml`, `values-prod.yaml` yalnızca replika sayısı ve resource request/limit gibi ortama özgü farkları override eder; (2) her koşumda değişen değerler — Jenkins'in ürettiği imaj etiketi (`v1.0.${BUILD_NUMBER}`) pipeline'da `--set frontend.image.tag=... --set backend.image.tag=... --set etl.image.tag=...` ile enjekte edilir. Böylece ne manifest'e elle dokunmak ne de ortam başına manifest kopyası tutmak gerekir.

**Sağladığı ek avantajlar.** `--install` ile idempotent kurulum/güncelleme, `--wait --atomic --timeout 10m` ile başarısız sürümde otomatik geri alma, `helm history`/`helm rollback` ile sürüm geçmişi ve tek komutla geri dönüş, `post-install,post-upgrade` hook'u ile ETL'in ilk veri yüklemesinin release yaşam döngüsüne bağlanması.

**Alternatiflerle karşılaştırma.** Düz manifest'lerde ortam ayrımı ancak dosya kopyalamakla yapılabilirdi; imaj etiketinin her build'de değişmesi `sed`/`envsubst` gibi kırılgan çözümler gerektirirdi. Kustomize, overlay mantığıyla templating olmadan daha okunabilir bir ortam ayrımı sunar ve öğrenme eğrisi daha düşüktür; ancak release kavramı, sürüm geçmişi ve `--atomic` benzeri otomatik rollback semantiği yoktur — pipeline'da CI'dan gelen dinamik değerleri enjekte etmek de `kustomize edit set image` ile mümkün olsa da release bütünlüğü garantisi vermez. Bu case'de belirleyici olan `--atomic` ve `helm rollback` olduğu için Helm seçilmiştir.

**Getirdiği ek karmaşıklık.** Go template sözdizimi manifest'lerin okunabilirliğini düşürür ve hatalar ancak render aşamasında görülür; bu yüzden `helm template` / `--dry-run` ile doğrulama ek bir adım olarak sürece girer. Ayrıca release state'i küme içinde Secret olarak tutulduğundan, kümenin kendisi tek hakikat kaynağı olur; GitOps (Argo CD/Flux) kullanılmayan bir kurulumda "kümedeki sürüm ile repo'daki kod" arasında sürüklenme riski doğar.

---

## 7. Kubernetes Service Tipleri

Kubernetes Service tiplerini hangi kriterlere göre belirlediniz?

Her servis için neden `ClusterIP`, `NodePort`, `LoadBalancer`, `ExternalName` veya headless Service tercih ettiğinizi açıklayın. Hangi servislerin cluster dışından erişilebilir olması gerektiğini ve gereksiz dış erişimi nasıl engellediğinizi belirtin.

**Cevap:**
Kriter basit tutulmuştur: *bir Service'in dışarı açılması için, o bileşene tarayıcıdan doğrudan erişilmesi gerekliliği kanıtlanmalıdır.* Bu kanıt hiçbir uygulama bileşeni için oluşmadığından, en az ayrıcalık prensibiyle tamamı `ClusterIP` bırakılmıştır.

| Service | Tip | Gerekçe |
| --- | --- | --- |
| Frontend | `ClusterIP` | Dışarıdan erişilir ama **doğrudan değil**; trafik Ingress üzerinden gelir. Service'in kendisinin açılmasına gerek yoktur. |
| Backend | `ClusterIP` | Aynı şekilde `/record` ve `/healthcheck` path'leri Ingress üzerinden yayınlanır. |
| MongoDB | `ClusterIP` | Küme dışından erişilmesi gereken hiçbir senaryo yok; yalnızca backend, ETL ve backup Job'u erişir. |
| NGINX Ingress Controller | `LoadBalancer` | Kümenin tek uygulama giriş noktası. AWS'de otomatik olarak bir ELB provision eder. |

**Değerlendirilip kullanılmayanlar.** `NodePort`, node IP'lerini ve yüksek portları doğrudan internete açtığı, güvenlik grubu yönetimini zorlaştırdığı ve sabit bir giriş adresi vermediği için tercih edilmemiştir. Chart'ta frontend Service'i için `NodePort` desteği parametrik olarak bırakılmıştır (`values.yaml` → `frontend.service.nodePort`), ancak hiçbir ortamda aktif edilmemiştir — üç values dosyasında da tip `ClusterIP`'tir. `ExternalName` yalnızca küme dışındaki bir servise (ör. yönetilen bir veritabanına) CNAME vermek için anlamlıydı; managed DB'ye geçilseydi MongoDB Service'i `ExternalName` yapılırdı. **Headless Service** (`clusterIP: None`) ise StatefulSet'te pod başına sabit DNS kaydı gerektiğinde, yani Replica Set üyelerinin birbirini `<pod>.<service>` adıyla bulması gerektiğinde anlamlıdır; tek replikalı kurulumda bu ihtiyaç doğmadığı için standart `ClusterIP` bırakılmıştır.

**Gereksiz dış erişimin engellenmesi.** Uygulama trafiği için tek public uç ELB'dir. Bunun dışında EKS control plane API endpoint'i yönetim için public'tir; bu, Jenkins'in küme dışından `helm`/`kubectl` çalıştırabilmesi için bilinçli bir tercihtir ancak `public_access_cidrs` ile kısıtlanmamıştır (bkz. Soru 14). Küme içi doğu-batı trafiği NetworkPolicy ile kısıtlanmamıştır (bkz. Soru 3).

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

| Bileşen | Workload | Durum modeli | Kalıcı depolama | Pod kimliği | Çalışma sıklığı | Restart davranışı | Ölçeklenebilirlik |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Frontend | `Deployment` | Stateless | Yok | Önemsiz | Sürekli | `Always`, rolling update | Yatay, replika sayısı values ile (prod: 3) |
| Backend | `Deployment` | Stateless | Yok | Önemsiz | Sürekli | `Always`, rolling update | Yatay, replika sayısı values ile (prod: 3) |
| MongoDB | `StatefulSet` | Stateful | **Var** — `volumeClaimTemplates`, gp2/EBS 5Gi | **Gerekli** — `mern-dev-mongodb-0` | Sürekli | `Always`, sıralı (`OrderedReady`) | Yatayda ölçeklenmez; Replica Set olmadan tek replika |
| Python ETL | `CronJob` | Stateless, batch | Yok | Önemsiz | Saatte bir (`0 * * * *`) | `restartPolicy: OnFailure`, `backoffLimit: 2` | Gerekmez; `concurrencyPolicy: Forbid` ile tek koşum garantisi |
| ETL ilk yükleme | `Job` (Helm hook) | Tek seferlik | Yok | Önemsiz | `post-install,post-upgrade` | `restartPolicy: Never` | — |

**Kararların gerekçeleri:**

- **Frontend ve Backend** herhangi bir yerel durum tutmaz; oturum bilgisi yok, yüklenen dosya yok. Bu nedenle pod'lar birbirinin yerine geçebilir ve `Deployment` ile yatayda kolayca replike edilebilir. Yeniden başlatmada özel bir sıra gerekmez, rolling update kesintisiz güncelleme sağlar.
- **MongoDB** durumu diskte tutar; bu yüzden tek belirleyici kriter kalıcı depolama ve pod kimliğidir. `StatefulSet` + `volumeClaimTemplates`, pod yeniden yaratıldığında aynı PVC'nin aynı pod'a yeniden bağlanmasını garanti eder — `Deployment` bu garantiyi vermez. Sabit pod adı (`-0` soneki) ayrıca yedekleme scriptlerinin hedefi deterministik seçmesini sağlar.
- **Python ETL** arka planda sürekli çalışıp kaynak tüketmesi gereken bir süreç değil; saat başı GitHub'dan veri çekip işi bitince kapanması gereken bir batch iştir. Bu yüzden `CronJob` seçilmiştir. `concurrencyPolicy: Forbid` ile önceki koşum bitmeden yenisi başlamaz — bu aynı zamanda ETL'in upsert mantığında yarış durumu oluşmasını da engeller (bkz. Soru 15). Hata durumunda `backoffLimit: 2` ile sınırlı sayıda yeniden denenir, sonsuz döngüye girmez.
- **Kurulum anındaki ilk veri yüklemesi** için CronJob'ın ilk tetiklenmesini (en kötü senaryoda 1 saat) beklememek adına Helm `post-install,post-upgrade` hook'u ile tek seferlik bir `Job` kullanılmıştır; böylece her release sonrası veri tazedir.

---

## 9. Konfigürasyon ve Secret Yönetimi

Uygulama konfigürasyonlarını ve secret bilgilerini nasıl yönettiniz?

**Cevap:**
Konfigürasyon ve secret'ları iki ayrı katmanda ele aldım.

**Uygulama konfigürasyonu.** Tüm bağlantı adresleri ve ortam bağımlı değerler (`PORT`, `DB_NAME`, `ATLAS_URI`, `REACT_APP_API_URL`) koddan çıkarılarak ortam değişkenine taşındı. Runtime değerleri Helm şablonlarında Deployment/CronJob `env` bloğu ile veriliyor; `ATLAS_URI` release adından türetiliyor (`mongodb://{{ .Release.Name }}-mongodb:27017`), böylece aynı chart farklı namespace ve ortamlarda elle düzenleme olmadan çalışıyor. Frontend tarafında React değişkenleri build zamanında gömüldüğü için `REACT_APP_API_URL` Dockerfile'da `ARG`/`ENV` olarak alınıyor — bu, runtime'da değiştirilemeyen bir değer olması açısından bilinçli olarak farklı bir sınıfta değerlendirilmiştir.

**Secret'lar.** Bu çözümde gerçek secret'lar CI katmanındadır ve Jenkins Credentials ile yönetilmektedir: AWS erişim anahtarları (`jenkins_aws_access_key_id`, `jenkins_aws_access_secret_key`) ve Docker Hub kimlik bilgileri (`docker-hub-repo`) Jenkinsfile'a gömülmemiş, `credentials()` ve `withCredentials` ile enjekte edilmiştir; Docker login `--password-stdin` ile yapıldığından parola build log'una düşmez. Repository tarafında ise `.dockerignore` ile `.env` dosyaları build context'ten, `.gitignore` ile `*.tfvars` ve `*.tfstate` dosyaları versiyon kontrolünden izole edilmiştir; Terraform state'i S3 backend'inde `encrypt = true` ile şifreli tutulur. Repoda gerçek hiçbir credential bulunmamaktadır.

**Dürüst sınır:** Kubernetes tarafında `Secret` veya `ConfigMap` kaynağı tanımlanmamıştır. Bunun nedeni, MongoDB'nin bu ortamda authentication kapalı çalıştırılması ve Service'in `ClusterIP` ile küme dışına kapalı olmasıdır — dolayısıyla uygulamanın taşıdığı bir kimlik bilgisi oluşmamıştır; `ATLAS_URI` hassas olmayan bir servis adresidir ve düz `env` değeri olarak verilmiştir. Production'da bu yaklaşım kabul edilemez: MongoDB `--auth` ile çalıştırılır, kullanıcı adı/parola içeren bağlantı URI'si bir Kubernetes `Secret`'ında tutulur ve pod'a `envFrom.secretRef` ile verilir. Bir adım ötesi, secret'ları AWS Secrets Manager'da tutup External Secrets Operator ile küme içine IRSA üzerinden senkronlamak, böylece secret'ın hiçbir aşamada Git'e veya pipeline log'una yaklaşmamasını sağlamaktır.

Bir secret değeri değiştirildiğinde veya yenilendiğinde uygulamanın yeni değeri güvenli şekilde kullanmasını nasıl sağlarsınız?

**Cevap:**
Secret rotasyonu imajı yeniden derlemeyi gerektirmez; yalnızca konfigürasyonun güncellenmesi ve pod'ların yeni değeri okuması gerekir. Değerin pod'a nasıl verildiğine göre davranış değişir:

- **`env`/`envFrom` ile verilmişse** değer konteyner başlangıcında bir kez okunur; Secret güncellense bile çalışan pod eski değeri kullanmaya devam eder. Bu durumda `kubectl rollout restart deployment/<ad>` ile rolling restart yapılır — replika sayısı birden büyük olduğu için kesinti olmaz.
- **Volume olarak mount edilmişse** kubelet dosyayı kısa süre içinde günceller, ancak uygulamanın dosyayı yeniden okuması gerekir; uygulama bunu desteklemiyorsa yine restart şarttır.
- **Otomasyon** için Deployment'a Secret içeriğinin hash'ini taşıyan bir `checksum/secret` annotation'ı eklenir (Helm ile `{{ include ... | sha256sum }}`); Secret değiştiğinde pod template hash'i de değişeceği için Kubernetes rolling update'i kendiliğinden başlatır. Alternatif olarak Reloader gibi bir controller aynı işi yapar.
- **Rotasyon sırası** önemlidir: yeni credential eski credential geçerliyken oluşturulur (overlap), pod'lar yeni değerle restart edilir, doğrulama yapıldıktan sonra eski credential iptal edilir. Böylece rotasyon sırasında hiçbir anda geçersiz kimlik bilgisiyle çalışan pod kalmaz.

İstisna, build zamanında gömülen `REACT_APP_API_URL` gibi değerlerdir: bunlar imajın parçası olduğundan değişiklikleri ancak yeniden build ve yeni bir imaj etiketiyle deploy gerektirir. Bu nedenle bu tür değerlere asla secret konulmamalıdır.

---

## 10. MongoDB Erişim Problemi

MongoDB erişilemez hale gelirse backend uygulaması, readiness/liveness kontrolleri ve kullanıcı istekleri nasıl davranır?

Kullanıcı etkisini azaltmak ve servisin kontrollü şekilde toparlanmasını sağlamak için hangi önlemleri aldınız veya alırdınız?

**Cevap:**

**Mevcut davranış.** `db/conn.mjs` bağlantıyı modül import aşamasında kurar. MongoDB erişilemezse, başlangıç projesindeki yakalanmamış hata yerine artık `try-catch` devreye girer, hata loglanır ve süreç `process.exit(1)` ile kontrollü şekilde kapanır. Kubernetes bunu konteyner çıkışı olarak görür, `restartPolicy: Always` gereği yeniden başlatır ve başarısızlık tekrarladıkça `CrashLoopBackOff` durumuna alır. Pod `Ready` olmadığı için Service'in Endpoints listesinden düşer, dolayısıyla Ingress bu pod'a trafik göndermez. Tüm backend replikaları aynı durumdaysa kullanıcı Ingress'ten HTTP 502/503 alır; frontend statik olarak servis edilmeye devam ettiği için sayfa açılır ama veri listesi boş gelir.

**Probe durumu — dürüst tespit.** Helm şablonlarına `readinessProbe`/`livenessProbe` tanımı eklenmemiştir (bkz. Soru 3). Yukarıdaki davranış probe'lardan değil, sürecin kendini sonlandırmasından kaynaklanır. Bu, "pod trafik almasın" sonucunu verir ancak kontrollü toparlanma açısından ideal değildir: süreç ayakta kalamadığı için `/healthcheck` endpoint'i de cevap veremez ve backoff süresi büyüdükçe MongoDB geri geldiğinde toparlanma gecikir.

**Alınacak önlemler (production yaklaşımı):**

1. **Bağlantıyı import'tan ayırıp exponential backoff ile yeniden denemek.** Uygulama ayakta kalır, `/healthcheck` cevap vermeye devam eder; sadece DB'ye bağımlı uçlar hata döner.
2. **Readiness probe'u DB durumuna bağlamak.** `/healthcheck` DB ping'ini de kontrol eder; DB yokken pod `NotReady` olur ve Endpoints'ten düşer — ama *restart edilmez*. Liveness probe yalnızca process sağlığını kontrol eder, böylece geçici DB kesintisi gereksiz restart döngüsü yaratmaz.
3. **Kullanıcı etkisini azaltmak.** Ingress seviyesinde `custom-http-errors` ile anlamlı bir hata sayfası; frontend tarafında yeniden deneme ve "servis geçici olarak kullanılamıyor" mesajı; yazma isteklerinin kuyruğa alınması gereken senaryolarda ise geri basınç (backpressure) uygulanması.
4. **Kök nedeni azaltmak.** MongoDB Replica Set ile otomatik failover, PodDisruptionBudget ile bakım sırasında tüm replikaların aynı anda düşmemesi, `MongoDBUnavailable` alarmı (`monitoring/prometheus-rules.yaml`) ile 2 dakika içinde on-call bilgilendirmesi.

---

## 11. Hatalı Deployment ve Rollback

Hatalı bir sürüm deploy edildiğinde problemi nasıl tespit edersiniz?

Rollback işlemini hangi yöntemle gerçekleştirirsiniz ve önceki çalışan sürümün güvenli şekilde devreye alındığını nasıl doğrularsınız?

**Cevap:**

**Tespit — üç katman.** Jenkins pipeline'ı hatalı sürümü art arda üç noktada yakalar:

1. **`Deploy to EKS`** — `helm upgrade --install ... --wait --atomic --timeout 10m`. Pod'lar 10 dakika içinde hazır duruma gelmezse (ImagePullBackOff, CrashLoopBackOff, yetersiz kaynak vb.) Helm işlemi başarısız sayar.
2. **`Smoke Test`** — `kubectl rollout status deployment/... --timeout=120s` ile frontend ve backend rollout'larının tamamlandığı ayrıca doğrulanır.
3. **`E2E Test (Cypress)`** — ELB adresi üzerinden gerçek kullanıcı akışı koşulur: ana sayfa açılır, `/create` üzerinden kayıt oluşturulur, kayıt `/record/` API'sinden doğrulanır ve Record List sayfasında göründüğü kontrol edilir. Bu katman, deployment "sağlıklı" görünmesine rağmen uygulamanın fonksiyonel olarak bozulduğu durumları (ör. yanlış API adresi, kırık route) yakalar.

**Rollback.** İlk katmanda geri alma otomatiktir: `--atomic` başarısız upgrade'de release'i bir önceki çalışan revision'a kendiliğinden döndürür. Üçüncü katmanda ise E2E aşamasının `post { failure { ... } }` bloğunda `helm rollback mern-<env> -n <env> --wait --timeout 5m` çalıştırılır; Cypress test videoları ve ekran görüntüleri `archiveArtifacts` ile Jenkins'e yüklenir, böylece rollback sonrası kök neden analizi için kanıt kaybolmaz.

**Doğrulama.** Rollback sonrası önceki sürümün güvenle devrede olduğu şu adımlarla doğrulanır:

- `helm history mern-<env> -n <env>` → hedeflenen revision'ın `deployed` durumunda olduğu görülür.
- `kubectl rollout status deployment/... -n <env>` → tüm replikalar güncel ve hazır.
- `kubectl get pods -n <env> -o jsonpath='{..image}'` → çalışan imaj etiketinin beklenen önceki `v1.0.<BUILD_NUMBER>` olduğu doğrulanır.
- Smoke ve E2E adımları yeniden koşularak fonksiyonel doğrulama yapılır; ayrıca `docs/alerting.md`'deki alarmların söndüğü kontrol edilir.

**Bilinen risk.** ETL Job'ı `post-upgrade` hook'u olarak tanımlıdır; GitHub API rate limit'i gibi tamamen harici bir nedenle hook başarısız olursa `--atomic` sağlıklı bir deployment'ı da geri alabilir. Production'da hook'un release'in başarı kriterinden ayrıştırılması (bağımsız bir Job veya `hook-failed` politikasının gözden geçirilmesi) gerekir.

---

## 12. Ölçeklenebilirlik ve Darboğazlar

Trafik 10 kat arttığında ilk darboğazın nerede oluşmasını beklersiniz?

Hangi bileşenleri, hangi metriklere ve eşiklere göre ölçeklersiniz? Veritabanı bağlantıları, kaynak kullanımı ve bağımlı servisleri nasıl değerlendirirsiniz?

**Cevap:**

**İlk darboğaz.** Mevcut mimaride ilk darboğazın **MongoDB'de** oluşmasını beklerim, çünkü tek replikalı ve yatayda ölçeklenemeyen tek bileşen odur; üstelik disk tipi gp2'dir ve IOPS boyut bağımlıdır. Hemen ardından **backend Node.js süreci** gelir: tek thread'li event loop CPU'ya doyduğunda gecikme artar ve MongoDB connection pool (sürücü varsayılanı 100 bağlantı) tükenmeye başlar. Frontend statik içerik servis ettiği için en son sıradadır.

**Ölçekleme planı (bu çözümde uygulanmamıştır, uygulanma şekli):**

- **Önkoşul:** `metrics-server` kurulumu ve *tüm* ortamlar için CPU/memory `requests` tanımı. Şu an request/limit yalnızca `values-test.yaml` ve `values-prod.yaml` içinde tanımlıdır; `values.yaml` ve `values-dev.yaml`'da `resources: {}` olduğu için yüzdeye dayalı HPA dev ortamında çalışamaz.
- **Backend:** HPA ile `minReplicas: 3`, `maxReplicas: 20`, hedef CPU kullanımı **%70**. Eşik %70 seçilir çünkü yeni pod'un ayağa kalkması ~30 saniye sürer; %90'da ölçeklemek geç kalmak demektir. Daha doğrusu, gecikme (p95 latency) veya kuyruk derinliği gibi bir custom metric'e geçmektir.
- **Frontend:** HPA ile CPU %70; pratikte statik içerik olduğu için darboğaz olmaz — asıl çözüm S3 + CloudFront'a taşımaktır.
- **Node katmanı:** Cluster Autoscaler veya Karpenter; pod'lar `Pending` kalmaya başladığında node eklenir.
- **Veritabanı:** Okuma yükü için MongoDB Replica Set kurulur ve sürücüde `readPreference=secondaryPreferred` ile okumalar secondary'lere dağıtılır; yazma yükü artarsa sharding veya managed servise (DocumentDB/Atlas) geçiş değerlendirilir. Bağlantı tarafında `maxPoolSize` backend replika sayısıyla çarpılarak toplam bağlantının sunucu limitini aşmadığı doğrulanır.

**İzlenecek metrikler ve eşikler:**

| Metrik | Eşik | Aksiyon |
| --- | --- | --- |
| Backend CPU kullanımı | %70 | HPA ile pod ekle |
| HTTP p95 gecikme | > 500 ms | Ölçekle + profil çıkar |
| HTTP 5xx oranı | > %1 | Alarm, rollback değerlendirmesi |
| MongoDB aktif bağlantı / pool | > %80 | Pool boyutu ve replika sayısını gözden geçir |
| MongoDB disk IOPS / kuyruk derinliği | Sürekli doygunluk | gp3'e geçiş, IOPS artırımı |
| Pod `Pending` süresi | > 1 dk | Node ölçeklemesi |

Bağımlı servis tarafında GitHub API rate limit'i (kimliksiz 60 istek/saat) bir kırılganlıktır; trafik artışından etkilenmez ama ETL sıklığı artırılırsa token ile kimliklendirme zorunlu hale gelir.

---

## 13. Logging, Monitoring ve Alarm Yönetimi

Hangi logları, metrikleri ve alarmları oluşturdunuz?

Bir incident sırasında problemi teşhis etmek için ilk olarak hangi dashboard, log, metrik veya alarm kayıtlarını incelersiniz?

**Cevap:**

**Loglar.** Tüm bileşenler 12-factor prensibine uygun olarak stdout/stderr'e log yazar; konteyner içine dosya yazılmaz. Bu sayede loglar hem `kubectl logs` ile okunabilir hem de ileride merkezi bir toplayıcıya (Fluent Bit → CloudWatch Logs / Loki) yönlendirilebilir. ETL'in `print` çağrılarını `logging` modülüne taşıyarak zaman damgası, log seviyesi ve her repository için `INSERTED`/`UPDATED` ayrımı ekledim; ayrıca `raise_for_status()` ile API hatalarında sürecin sıfırdan farklı exit code ile durmasını ve Job'ın `Failed` olarak işaretlenmesini sağladım — bu, ETL alarmlarının çalışabilmesinin ön şartıdır.

**Metrikler ve alarmlar.** `monitoring/prometheus-rules.yaml` içinde Prometheus Operator `PrometheusRule` kaynağı olarak dört alarm tanımlıdır:

| Alarm | Koşul | Süre | Seviye |
| --- | --- | --- | --- |
| `BackendUnavailable` | Backend'de hazır replika = 0 | 2 dk | critical |
| `MongoDBUnavailable` | MongoDB pod'u Ready değil / yok | 2 dk | critical |
| `ETLJobFailed` | ETL Job'ı hata ile bitti | 1 dk | warning |
| `ETLNoSuccessfulRun` | 2 saattir başarılı ETL koşumu yok | 10 dk | warning |

Eşik gerekçeleri ve alarm başına runbook adımları `docs/alerting.md` içindedir. **Kapsam sınırı:** `kube-prometheus-stack` bu ortamda pipeline'ın parçası olarak değil, `docs/alerting.md`'deki komutlarla elle kurulmuştur; Alertmanager'ın Slack/PagerDuty receiver'ı harici bir hedef bulunmadığı için canlıya bağlanmamış, routing konfigürasyonu çalıştırılabilir şekilde dokümanda bırakılmıştır.

**Incident sırasında inceleme sırası.** Önce hangi alarmın tetiklendiğine bakarım, çünkü bu doğrudan katmanı söyler: MongoDB ve backend birlikte yanıyorsa kök neden veritabanındadır, tek başına backend yanıyorsa uygulama veya son deploy'dadır. Ardından `kubectl get pods` ile durum, `kubectl describe pod` ile olay kayıtları (OOMKilled, ImagePullBackOff, kaynak yetersizliği) ve `kubectl logs --previous` ile çökmeden önceki son satırlar incelenir. Alarm zamanı son Jenkins deploy'u ile örtüşüyorsa teşhisten önce `helm rollback` ile servisi ayağa kaldırır, kök neden analizini sonra yaparım — kullanıcı etkisini durdurmak teşhisten önce gelir.

---

## 14. Güvenlik Riskleri

Çözümünüzde gördüğünüz en önemli üç güvenlik riski nedir?

Bu riskleri azaltmak için uyguladığınız veya production ortamında uygulayacağınız kontrolleri açıklayın.

**Cevap:**

1. **MongoDB'nin kimlik doğrulamasız çalışması.** Bu çözümdeki en önemli risk budur: veritabanı `--auth` olmadan çalıştığı için küme içindeki *herhangi* bir pod `mongodb://mern-dev-mongodb:27017` adresine sınırsız okuma/yazma yapabilir. **Uygulanan kontroller:** Service `ClusterIP`'tir, küme dışına hiçbir şekilde açılmamıştır; yedek almak için `kubectl exec` yetkisi, yani Kubernetes RBAC izni gerekir. **Production'da:** kimlik doğrulama açılır, bağlantı URI'si Kubernetes `Secret`'ında (ideali External Secrets Operator + AWS Secrets Manager) tutulur, yalnızca backend ve ETL pod'larının 27017'ye erişebildiği bir `NetworkPolicy` yazılır ve at-rest şifreleme (KMS ile şifreli EBS) etkinleştirilir.

2. **Konteyner ve pod seviyesi ayrıcalıklar.** Konteynerlerin varsayılan olarak root yetkisiyle çalışması. **Uygulanan kontroller:** üç imajın tamamı non-root çalışacak şekilde hazırlanmıştır — ETL'de `useradd etluser` + `USER etluser`, backend'de `USER node`, frontend'de `nginxinc/nginx-unprivileged` temel imajı (8080 portu, root gerektirmez). **Eksik olan:** pod seviyesinde `securityContext` tanımlanmamıştır. Production'da `runAsNonRoot: true`, `allowPrivilegeEscalation: false`, `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]` eklenir, Pod Security Admission `restricted` seviyesine çekilir ve pipeline'a Trivy ile imaj taraması adımı konur.

3. **Yönetim düzlemi ve IaC state güvenliği.** EKS control plane API endpoint'i public'tir (`cluster_endpoint_public_access = true`) ve `public_access_cidrs` ile kısıtlanmamıştır; ayrıca `enable_cluster_creator_admin_permissions = true` ile cluster'ı oluşturan kimliğe admin yetkisi verilmiştir. Terraform state tarafında S3 backend'i `encrypt = true` ile şifrelidir ve `.gitignore` sayesinde state/tfvars dosyaları repoya girmez; ancak **state locking (DynamoDB tablosu / lockfile) yapılandırılmamıştır**, bu da eşzamanlı `apply` durumunda state bozulma riski doğurur. **Production'da:** private endpoint veya IP allowlist, IRSA ile en az ayrıcalıklı servis hesapları, insan erişiminin SSO + geçici rollerle verilmesi, state için DynamoDB lock ve S3 versiyonlama + object lock.

---

## 15. Python ETL Güncelleme Yaklaşımı

Python ETL aynı repository bilgisini tekrar aldığında mevcut kaydı nasıl bulup güncelliyor?
Benzersiz kayıt anahtarı olarak hangi alanı kullandınız ve duplicate oluşmadığını hangi ekran görüntüsü veya çıktı ile gösterdiniz?

**Cevap:**
Python ETL script'i (`python-project/ETL.py`), GitHub API'den dönen JSON yanıtındaki orijinal `id` değerini alıp MongoDB tarafında `github_id` alanında saklar ve bu alanı kaydın benzersiz iş anahtarı (business key) olarak kullanır. `name` veya `html_url` yerine `id` seçilmiştir, çünkü repository yeniden adlandırıldığında ad ve URL değişir ama `id` sabit kalır — ad üzerinden eşleştirme yapılsaydı yeniden adlandırılan her repo için duplicate oluşurdu.

Veritabanı operasyonu şu şekildedir:

```python
filter_query = {"github_id": repo["id"]}
update_data = {"$set": {"github_id": repo["id"], "name": repo["name"], "url": repo["html_url"]}}
result = collection.update_one(filter_query, update_data, upsert=True)
```

`upsert=True` sayesinde MongoDB önce `github_id` ile eşleşen dokümanı arar; kayıt yoksa yeni doküman oluşturur, varsa mevcut dokümanın alanlarını `$set` ile günceller. Ayrım `result.upserted_id` üzerinden okunup log'a `INSERTED` / `UPDATED` olarak yazılır ve koşum sonunda özet satırı basılır.

**Dürüst teknik not:** Tekillik şu an DB seviyesinde bir unique index ile değil, uygulama seviyesinde upsert mantığıyla sağlanmaktadır. Teorik olarak iki ETL koşumu aynı anda çalışırsa yarış durumu oluşabilir; bu risk CronJob'daki `concurrencyPolicy: Forbid` ayarıyla pratikte engellenmiştir. Kalıcı çözüm, koleksiyona `collection.create_index("github_id", unique=True)` ile bir unique index eklemek ve tekilliği veritabanı kısıtına devretmektir — bir sonraki iterasyonda eklenecek maddedir.

Duplicate oluşmadığına ve güncellemenin başarıyla yapıldığına dair kanıtlar `TESLIM_KANITLARI.md` bölüm 4.2'de şu görsellerle sunulmuştur:

- `docs/screenshots/11-etl-update-without-duplicate-1.png` — arayüzde bir kaydın alanı manuel olarak değiştirildiği an
- `docs/screenshots/11-etl-update-without-duplicate-2.png` — script ikinci kez koştuktan sonraki log çıktısı (`UPDATED existing repo ...`) ve arayüzdeki düzelme; toplam doküman sayısının değişmediği görülmektedir

---

## 16. Backup ve Restore Yaklaşımı

MongoDB için hangi yedekleme yöntemini ve saklama konumunu seçtiniz?

Yedekleme sıklığı, retention süresi, RPO ve RTO hedefleriniz nedir ve ölçtüğünüz gerçek geri yükleme süresi ne kadar oldu?

Yedeğin bozuk veya eksik olmasına karşı hangi doğrulamayı yaparsınız; gerçek bir production ortamında bu yaklaşımı nasıl farklılaştırırdınız?

Runbook’unuzu `docs/backup-restore.md` içinde paylaşın ve kanıtları `TESLIM_KANITLARI.md` dosyasından referanslayın.

**Cevap:**

**Yöntem ve konum.** MongoDB yedeklemesi için `mongodump` aracıyla tek dosyalık sıkıştırılmış arşiv (`--archive --gzip`) yöntemi seçilmiştir; tek dosya olduğu için taşınması ve bütünlüğünün doğrulanması kolaydır. Yedekler iki şekilde alınır: `scripts/mongo-backup.sh` ile operatör tarafından manuel, `k8s/backup/mongodb-backup-cronjob.yaml` ile küme içinde her gün 02:00 UTC'de otomatik. Manuel yedekler operatör makinesindeki `backups/` dizininde (`.gitignore` içinde, repoya girmez), zamanlanmış yedekler `dev` namespace'indeki `mongodb-backup` PersistentVolumeClaim'i (5Gi, gp2/EBS) üzerinde saklanır. Yedek kapsamı `sample_training` veritabanının tamamıdır; uygulama verisi (`records`) ve ETL verisi (`github_repos`) aynı arşivde yer alır.

**Sıklık, retention, hedefler.** Zamanlanmış yedekleme günlük, retention süresi 7 gündür; hem script hem CronJob her koşumda `find -mtime +7 -delete` ile eski arşivleri temizler. RPO hedefi 24 saat (günlük tam yedek), RTO hedefi 15 dakikadır. Uçtan uca senaryoda ölçülen gerçek geri yükleme süresi **0m1.490s** olmuştur (yedek boyutu 4.0K); mevcut veri hacminin küçük olması nedeniyle hedefin belirgin şekilde altında kalmıştır — bu süre veri hacmiyle birlikte büyüyeceğinden RTO hedefi veri büyüdükçe yeniden ölçülmelidir.

**Doğrulama.** Yedeğin bütünlüğü iki aşamada kontrol edilir: geri yükleme öncesinde arşiv, veriye dokunmadan `mongorestore --archive --gzip --dryRun --verbose` ile okunur — bozuk veya yarım kalmış arşiv bu aşamada hata verir; geri yükleme sonrasında `countDocuments()` sonucu yedek öncesi değerle karşılaştırılır ve kayıtların arayüzde eksiksiz render edildiği gözlenir. `--dryRun` adımı restore script'inin içine gömülmemiş, runbook'ta (`docs/backup-restore.md` §5) operatörün restore öncesi çalıştıracağı ayrı bir adım olarak tanımlanmıştır.

**Production'da farklı yapacaklarım.** Yedekler küme dışına, versiyonlama ve object-lock etkin bir S3 bucket'ına aktarılır ve yaşam döngüsü kuralıyla Glacier'a taşınır; KMS ile şifrelenir ve yalnızca yedekleme işine yetkili ayrı bir IAM rolüyle erişilir. RPO, `mongodump --oplog` ile oplog yedeği veya yönetilen bir servis (DocumentDB/Atlas continuous backup) kullanılarak dakikalar seviyesine çekilir. Restore doğrulaması günlük çalışan bir Job ile otomatikleştirilir: son yedek tek kullanımlık bir ortama geri yüklenir, kayıt sayısı kontrol edilir ve başarısızlıkta alarm üretilir. Çeyrek dönemde bir DR tatbikatı yapılarak ölçülen RTO kayıt altına alınır.

**Bilinen sınırlama.** Zamanlanmış yedek CronJob'ı Helm chart'ının dışında, `namespace: dev` ve `--host mern-dev-mongodb` değerleri sabit yazılmış halde durur ve pipeline tarafından değil elle `kubectl apply` ile devreye alınır; dolayısıyla test/prod ortamlarında otomatik yedek almaz. Chart'a taşınıp release adı ve namespace'ten türetilmesi gereken bir teknik borçtur. Diğer sınırlamalar `docs/backup-restore.md` §7'de listelenmiştir.

Runbook `docs/backup-restore.md` dosyasındadır. Kanıtlar `TESLIM_KANITLARI.md` bölüm 6'da 13-18 numaralı ekran görüntüleri olarak referanslanmıştır.

---

## Ek Notlar

Case kapsamında özellikle belirtmek istediğiniz ek kararlar, sınırlamalar veya sonraki geliştirme adımları varsa bu bölümde açıklayabilirsiniz.

**Cevap:**

**Altyapı (IaC).** AWS altyapısı Terraform ile, `vpc` ve `eks` yerel modülleri üzerinden kurulmuştur; modüller resmi `terraform-aws-modules` chart'larını sarmalar. Worker node'lar private subnet'lerde, dışarı çıkış tek NAT Gateway üzerindedir (maliyet için `single_nat_gateway = true`; production'da AZ başına NAT önerilir). `ENV_NAME` pipeline parametresi hem `TF_VAR_env_prefix` olarak Terraform'a hem Helm values seçimine beslenir; böylece altyapı ve uygulama dağıtımı tek parametreyle senkron ilerler ve her ortam kendi VPC/EKS cluster'ına sahip olur.

**CI/CD.** Jenkins pipeline'ında üç imajın derlenmesi `parallel` blok ile eşzamanlı yapılarak build süresi kısaltılmış, `failFast true` ile herhangi biri hata verdiğinde diğerleri iptal edilmiştir. Kimlik bilgileri Jenkins Credentials üzerinden enjekte edilir, Docker login `--password-stdin` ile yapılır. Dağıtım sonrası smoke test ve ELB üzerinden gerçek Cypress E2E testi koşulur; E2E başarısız olursa otomatik `helm rollback` devreye girer, test videoları ve ekran görüntüleri artifact olarak arşivlenir.

**Bilinen teknik borçlar (sonraki iterasyon).** Farkında olunan ve production'a geçişte kapatılması gereken maddeler:

1. **Terraform state anahtarı ortam bazlı değildir.** `terraform/backend.tf` içindeki `key = "eks-cluster/terraform.tfstate"` sabittir ve workspace kullanılmaz; farklı `ENV_NAME` değerleriyle koşulduğunda ortamlar aynı state dosyasını paylaşır. Çözüm: `terraform init -reconfigure -backend-config="key=eks-cluster/${ENV_NAME}/terraform.tfstate"` veya Terraform workspace kullanımı. Ayrıca state locking (DynamoDB tablosu) yapılandırılmalıdır.
2. **`terraform.tfvars` repoda yoktur** (`.gitignore` ile `*.tfvars` hariç tutulmuştur) ve değişkenlerin default değeri bulunmamaktadır; çalışmanın yeniden üretilebilmesi için bir `terraform.tfvars.example` dosyası eklenmelidir.
3. **EBS CSI driver elle kurulmuştur.** MongoDB'nin kalıcı diski için gereken `aws-ebs-csi-driver` addon'u ve `AmazonEBSCSIDriverPolicy` IAM politikası bu ortamda elle eklenmiştir; Terraform'da `cluster_addons` bloğu ile IRSA üzerinden yönetilmelidir.
4. **Liveness/readiness probe, `securityContext`, NetworkPolicy ve HPA** şablonlara eklenmemiştir (bkz. Soru 3, 10, 12, 14).
5. **MongoDB authentication kapalıdır** ve chart'ta `Secret`/`ConfigMap` kaynağı yoktur (bkz. Soru 9).
6. **Backup CronJob'ı `dev` ortamına özeldir** ve chart dışındadır (bkz. Soru 16).
7. **ETL'de `github_id` için unique index yoktur**; tekillik uygulama seviyesindedir (bkz. Soru 15).
8. **Pipeline'da imaj güvenlik taraması (Trivy) ve merkezi log toplama yoktur** (bkz. Soru 3, 13).
