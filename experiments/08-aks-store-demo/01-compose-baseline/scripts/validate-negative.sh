#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-aks-store-demo-compose}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${BASELINE_DIR}/.local/validation"
NEGATIVE_FAILURE_OUT="${REPORT_DIR}/negative-rabbitmq-stopped.out"
NEGATIVE_RECOVERY_OUT="${REPORT_DIR}/negative-rabbitmq-recovery.out"

cd "${BASELINE_DIR}"
mkdir -p "${REPORT_DIR}"
rm -f "${NEGATIVE_FAILURE_OUT}" "${NEGATIVE_RECOVERY_OUT}"

log() { printf '[validate-negative] %s\n' "$*"; }
fail() { printf '[validate-negative] ERROR: %s\n' "$*" >&2; exit 1; }
compose() { docker compose -p "${PROJECT_NAME}" "$@"; }

if ! docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Label "com.docker.compose.service"}}' | grep -qx rabbitmq; then
  log "starting baseline before negative validation"
  compose up -d --build
fi

log "stopping Experiment 08 RabbitMQ dependency"
compose stop rabbitmq >/dev/null

if "${SCRIPT_DIR}/validate-compose.sh" --identity-only >${NEGATIVE_FAILURE_OUT} 2>&1; then
  compose up -d rabbitmq >/dev/null
  fail "identity validation unexpectedly passed while rabbitmq was stopped"
fi

if ! grep -Eq 'rabbitmq|expected running' ${NEGATIVE_FAILURE_OUT}; then
  compose up -d rabbitmq >/dev/null
  fail "negative failure did not identify the stopped RabbitMQ dependency"
fi

log "negative validation failed as expected with RabbitMQ stopped"
compose up -d rabbitmq >/dev/null
rabbitmq_deadline=$((SECONDS + 180))
while true; do
  rabbitmq_status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Running}}{{end}}' "$(compose ps -q rabbitmq)" 2>/dev/null || true)"
  [[ "${rabbitmq_status}" == "healthy" || "${rabbitmq_status}" == "true" ]] && break
  if (( SECONDS >= rabbitmq_deadline )); then
    fail "RabbitMQ did not become healthy after restore; last status=${rabbitmq_status}"
  fi
  sleep 5
done
compose restart order-service makeline-service >/dev/null
if ! "${SCRIPT_DIR}/validate-compose.sh" --recovery-order-only >"${NEGATIVE_RECOVERY_OUT}" 2>&1; then
  cat ${NEGATIVE_RECOVERY_OUT} >&2 || true
  fail "RabbitMQ restoration did not recover a fresh unique-order makeline/DocumentDB workflow"
fi
log "RabbitMQ restored and fresh unique-order makeline/DocumentDB workflow recovered"
