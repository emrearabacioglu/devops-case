#!/usr/bin/env bash
# MongoDB yedegi alir: mongodump ciktisini tek bir sikistirilmis arsiv dosyasina yazar.
# Kullanim: ./scripts/mongo-backup.sh
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
RELEASE="${RELEASE:-mern-dev}"
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

POD="${RELEASE}-mongodb-0"
TS="$(date +%Y%m%d-%H%M%S)"
FILE="${BACKUP_DIR}/mongodb-${TS}.archive.gz"

mkdir -p "${BACKUP_DIR}"

echo "[backup] pod=${POD} namespace=${NAMESPACE}"
kubectl exec -n "${NAMESPACE}" "${POD}" -- \
  mongodump --archive --gzip > "${FILE}"

echo "[backup] created: ${FILE} ($(du -h "${FILE}" | cut -f1))"

echo "[backup] applying retention: deleting backups older than ${RETENTION_DAYS} days"
find "${BACKUP_DIR}" -name 'mongodb-*.archive.gz' -mtime "+${RETENTION_DAYS}" -print -delete

echo "[backup] current backups:"
ls -lh "${BACKUP_DIR}"
