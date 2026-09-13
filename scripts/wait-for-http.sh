#!/usr/bin/env bash
#
# Verilen bir HTTP endpoint'i basarili (2xx) bir cevap verene kadar bekler.
# Backend gibi servislerin CI icinde gercekten istek karsilayip
# karsilamadigini, sabit "sleep N" yerine gercek bir kontrolle dogrular.
#
# Kullanim:
#   ./scripts/wait-for-http.sh <url> [max_attempts] [sleep_seconds]
#
# Ornek:
#   ./scripts/wait-for-http.sh http://localhost:5050/record 30 2

set -euo pipefail

URL="${1:?Kullanim: wait-for-http.sh <url> [max_attempts] [sleep_seconds]}"
MAX_ATTEMPTS="${2:-30}"
SLEEP_SECONDS="${3:-2}"

echo "Bekleniyor: ${URL}"

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  if curl -sf "${URL}" > /dev/null; then
    echo "Hazir: ${URL}"
    exit 0
  fi
  echo "Hazir degil (${i}/${MAX_ATTEMPTS})..."
  sleep "${SLEEP_SECONDS}"
done

echo "HATA: ${URL} ${MAX_ATTEMPTS} denemede basarili cevap vermedi." >&2
exit 1