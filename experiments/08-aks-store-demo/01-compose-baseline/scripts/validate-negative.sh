#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-aks-store-demo-compose}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${BASELINE_DIR}"

log() { printf '[validate-negative] %s\n' "$*"; }
fail() { printf '[validate-negative] ERROR: %s\n' "$*" >&2; exit 1; }
compose() { docker compose -p "${PROJECT_NAME}" "$@"; }

if ! docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Label "com.docker.compose.service"}}' | grep -qx rabbitmq; then
  log "starting baseline before negative validation"
  compose up -d --build
fi

log "stopping Experiment 08 RabbitMQ dependency"
compose stop rabbitmq >/dev/null

if "${SCRIPT_DIR}/validate-compose.sh" --identity-only >/tmp/aks-store-negative.out 2>&1; then
  compose up -d rabbitmq >/dev/null
  fail "identity validation unexpectedly passed while rabbitmq was stopped"
fi

if ! grep -Eq 'rabbitmq|expected running' /tmp/aks-store-negative.out; then
  compose up -d rabbitmq >/dev/null
  fail "negative failure did not identify the stopped RabbitMQ dependency"
fi

log "negative validation failed as expected with RabbitMQ stopped"
compose up -d rabbitmq >/dev/null
"${SCRIPT_DIR}/validate-compose.sh" --identity-only >/dev/null
log "RabbitMQ restored and identity validation recovered"
