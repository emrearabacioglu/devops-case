#!/usr/bin/env bash
# Verilen arsiv dosyasindan MongoDB'yi geri yukler.
# Kullanim: ./scripts/mongo-restore.sh ./backups/mongodb-20260913-214500.archive.gz
set -euo pipefail

NAMESPACE="${NAMESPACE:-dev}"
RELEASE="${RELEASE:-mern-dev}"
FILE="${1:-}"

if [[ -z "${FILE}" ]]; then
  echo "usage: $0 <backup-file.archive.gz>" >&2
  exit 1
fi
if [[ ! -f "${FILE}" ]]; then
  echo "error: backup file not found: ${FILE}" >&2
  exit 1
fi

POD="${RELEASE}-mongodb-0"

echo "[restore] file=${FILE} -> pod=${POD} namespace=${NAMESPACE}"
kubectl exec -i -n "${NAMESPACE}" "${POD}" -- \
  mongorestore --archive --gzip --drop < "${FILE}"

echo "[restore] completed"
