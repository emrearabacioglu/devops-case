# Logging ve Alerting

## 1. Log erisimi

Tum bilesenler stdout/stderr'e log yazar (12-factor); container icine veya
dosyaya log yazilmaz. Boylece loglar hem `kubectl logs` ile hem de merkezi
bir log toplayici (Fluent Bit / CloudWatch Logs) ile toplanabilir.

| Bilesen | Komut |
|---------|-------|
| Frontend | `kubectl logs -n dev deploy/mern-dev-frontend -f` |
| Backend | `kubectl logs -n dev deploy/mern-dev-backend -f` |
| MongoDB | `kubectl logs -n dev -l app=mongodb -f` |
| ETL (son kosum) | `kubectl logs -n dev -l job-name=$(kubectl get jobs -n dev -o jsonpath='{.items[-1:].metadata.name}')` |
| Crash sonrasi onceki kosum | `kubectl logs -n dev <pod> --previous` |

### ETL log formati

ETL, Python `logging` modulu ile zaman damgali ve seviyeli log basar:

    2026-09-13 21:04:11 INFO [etl] Sending API request to: https://api.github.com/users/emrearabacioglu/repos
    2026-09-13 21:04:12 INFO [etl] Fetched 23 repositories from GitHub API
    2026-09-13 21:04:12 INFO [etl] INSERTED new repo: devops-case (github_id=812345678)
    2026-09-13 21:04:13 INFO [etl] UPDATED existing repo: java-maven-app (github_id=798765432)
    2026-09-13 21:04:13 INFO [etl] ETL run completed. Inserted: 1, Updated: 22, Total: 23

Her repo icin INSERTED/UPDATED ayrimi basilir; ayni repo tekrar islendiginde
yeni kayit olusmadiginin dogrudan kanitidir (bkz. CASE_END_ANSWERS.md Soru 15).

GitHub API hata donerse `raise_for_status()` istisna firlatir, script 1 exit
code ile durur ve Job "Failed" olarak isaretlenir. Bu, ETLJobFailed alarminin
calisabilmesinin on sartidir.

## 2. Alarmlar

Kurallar `monitoring/prometheus-rules.yaml` icinde Prometheus Operator
`PrometheusRule` kaynagi olarak tanimlidir.

| Alarm | Kosul | Sure | Seviye |
|-------|-------|------|--------|
| BackendUnavailable | Backend'de hazir replika = 0 | 2 dk | critical |
| MongoDBUnavailable | MongoDB pod'u Ready degil / yok | 2 dk | critical |
| ETLJobFailed | ETL Job'i hata ile bitti | 1 dk | warning |
| ETLNoSuccessfulRun | 2 saattir basarili ETL kosumu yok | 10 dk | warning |

### Esik gerekceleri

- **2 dakika (backend/mongo):** rolling update sirasinda pod'lar kisa sureli
  hazir olmayabilir; 2 dakika normal deploy gurultusunu eler, gercek kesintiyi
  yakalar.
- **1 dakika (ETL failed):** Job zaten terminal durumda, beklemeye gerek yok.
- **2 saat (ETL gecikmesi):** ETL saatlik calisir; tek kacirilmis kosum tolere
  edilir, iki ust uste kacirilmis kosum gercek sorundur.

### Devreye alma

    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
    helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
      --namespace monitoring --create-namespace --wait
    kubectl apply -f monitoring/prometheus-rules.yaml
    kubectl get prometheusrule -n monitoring

Dogrulama: `kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090`
-> http://localhost:9090/alerts

### Bildirim yonlendirmesi

Alertmanager `severity` label'ina gore yonlendirir:

- `severity: critical` -> on-call kanali (`#alerts-critical` / PagerDuty)
- `severity: warning` -> `#alerts`, is saatleri icinde

    route:
      group_by: ["alertname", "namespace"]
      group_wait: 30s
      repeat_interval: 4h
      receiver: default
      routes:
        - matchers: ['severity="critical"']
          receiver: oncall
    receivers:
      - name: default
        slack_configs:
          - api_url_file: /etc/alertmanager/secrets/slack-webhook
            channel: "#alerts"
      - name: oncall
        slack_configs:
          - api_url_file: /etc/alertmanager/secrets/slack-webhook
            channel: "#alerts-critical"

Webhook URL'i repoda tutulmaz; `alertmanager-slack` adli Kubernetes Secret'tan
mount edilir.

## 3. Alarm tetiklendiginde ne yapilir

### BackendUnavailable
1. `kubectl get pods -n dev -l app=backend`
2. `kubectl describe pod` - OOMKilled / ImagePullBackOff / probe hatasi?
3. `kubectl logs deploy/mern-dev-backend --previous`
4. MongoDB de down ise once MongoDBUnavailable ele alinir (kok neden orada)
5. Son deploy sonrasi basladiysa: `helm rollback mern-dev -n dev`

### MongoDBUnavailable
1. `kubectl describe pod -n dev -l app=mongodb` - PVC mount / disk dolu mu?
2. `kubectl get pvc -n dev` - PVC Bound mu?
3. Veri kaybi suphesi varsa docs/backup-restore.md izlenir

### ETLJobFailed
1. `kubectl logs -n dev -l job-name=<job>` - ERROR satiri
2. GitHub 403 -> rate limit; GITHUB_TOKEN Secret'i kontrol edilir
3. MongoDB baglanti hatasi -> MongoDBUnavailable ile birlikte degerlendirilir
4. Manuel tetikleme: `kubectl create job --from=cronjob/mern-dev-etl-job etl-manual -n dev`

### ETLNoSuccessfulRun
1. `kubectl get cronjob -n dev` - SUSPEND=True mi, LAST SCHEDULE ne zaman?
2. `kubectl get jobs -n dev` - Job olusuyor ama pod mu zamanlanamiyor?
3. `kubectl describe node` - kaynak yetersizligi

## 4. Kapsam disi birakilanlar

- **Merkezi log toplama** (Fluent Bit -> CloudWatch Logs / Loki) kurulmadi;
  loglar yalnizca `kubectl logs` ile erisiliyor ve pod silindiginde kaybolur.
  Production'da ilk eklenecek bilesen budur.
- **Alertmanager receiver'i canliya baglanmadi;** harici bir Slack/PagerDuty
  hedefi olmadigi icin kural ve routing tanimlari calistirilabilir sekilde
  repoda birakildi.
- **SLO/SLI ve error budget** tanimlanmadi; anlamli trafik gecmisi olmadigi
  icin esikler deneyimsel secildi.