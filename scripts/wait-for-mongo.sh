#!/usr/bin/env bash
#
# docker compose ile ayaga kaldirilan MongoDB servisinin gercekten
# baglanti kabul eder hale gelmesini bekler. Sabit "sleep N" yerine
# gercek bir "ping" kontrolu yapar; belirtilen deneme sayisi asilirsa
# ilgili servisin loglarini basip pipeline'i basarisiz olarak bitirir.
#
# Kullanim:
#   ./scripts/wait-for-mongo.sh <compose-service-name> [max_attempts] [sleep_seconds]
#
# Ornek:
#   ./scripts/wait-for-mongo.sh mongodb 30 2

set -euo pipefail

SERVICE_NAME="${1:-mongodb}"
MAX_ATTEMPTS="${2:-30}"
SLEEP_SECONDS="${3:-2}"

echo "MongoDB (${SERVICE_NAME}) hazir olmasi bekleniyor..."

for i in $(seq 1 "${MAX_ATTEMPTS}"); do
  if docker compose exec -T "${SERVICE_NAME}" mongosh --quiet --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
    echo "MongoDB hazir."
    exit 0
  fi
  echo "MongoDB bekleniyor (${i}/${MAX_ATTEMPTS})..."
  sleep "${SLEEP_SECONDS}"
done

echo "HATA: MongoDB ${MAX_ATTEMPTS} denemede hazir olmadi." >&2
docker compose logs "${SERVICE_NAME}" || true
exit 1