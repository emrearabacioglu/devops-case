#!/usr/bin/env bash
#
# Verilen docker compose servisinin ICINE girip (docker compose exec),
# servisin kendi localhost'unda verilen URL'in basarili bir HTTP cevabi
# verip vermedigini kontrol eder.
#
# Neden boyle: Jenkins genelde kendi container'i icinde calisir. Duz
# "curl http://localhost:PORT" calistirilirsa bu Jenkins container'inin
# kendi network namespace'inde calisir ve backend'in host'a acilmis
# portuna hicbir zaman ulasamaz (connection refused/timeout). Kontrolu
# servisin kendi icinden yapmak bu network karmasasini tamamen ortadan
# kaldirir. Node zaten backend image'inin icinde oldugu icin ekstra bir
# bagimliliga (curl/wget vb.) ihtiyac yok.
#
# Kullanim:
#   ./scripts/wait-for-http.sh <compose-service> <url> [max_attempts] [sleep_seconds]
#
# Ornek:
#   ./scripts/wait-for-http.sh backend http://localhost:5050/record 30 2

set -euo pipefail

SERVICE_NAME="${1:?Kullanim: wait-for-http.sh <compose-service> <url> [max_attempts] [sleep_seconds]}"
URL="${2:?Kullanim: wait-for-http.sh <compose-service> <url> [max_attempts] [sleep_seconds]}"
MAX_ATTEMPTS="${3:-30}"
SLEEP_SECONDS="${4:-2}"

echo "Bekleniyor: ${URL} (servis: ${SERVICE_NAME} icinden kontrol)"

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  if docker compose exec -T "${SERVICE_NAME}" node -e "
    require('http').get('${URL}', res => process.exit(res.statusCode < 500 ? 0 : 1))
      .on('error', () => process.exit(1));
  " > /dev/null 2>&1; then
    echo "Hazir: ${URL}"
    exit 0
  fi
  echo "Hazir degil (${i}/${MAX_ATTEMPTS})..."
  sleep "${SLEEP_SECONDS}"
done

echo "HATA: ${URL} ${MAX_ATTEMPTS} denemede basarili cevap vermedi." >&2
docker compose logs "${SERVICE_NAME}" || true
exit 1