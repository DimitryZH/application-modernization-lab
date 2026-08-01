#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"

log() { printf '[cleanup-aspire] %s\n' "$*"; }

creator_identity=""
if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}")"
  if kill -0 "${pid}" >/dev/null 2>&1; then
    log "stopping AppHost PID ${pid}"
    kill "${pid}" >/dev/null 2>&1 || true
    for _ in {1..30}; do
      kill -0 "${pid}" >/dev/null 2>&1 || break
      sleep 1
    done
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi
  rm -f "${PID_FILE}"
fi

for id in $(docker ps -aq); do
  name="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' "${id}" 2>/dev/null || true)"
  group="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.group-version" }}' "${id}" 2>/dev/null || true)"
  pid_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' "${id}" 2>/dev/null || true)"
  start_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' "${id}" 2>/dev/null || true)"
  [[ "${group}" == "usvc-dev.developer.microsoft.com/v1" ]] || continue
  [[ "${name}" =~ ^(documentdb|rabbitmq|order-service|makeline-service|product-service|store-front|store-admin|virtual-customer|virtual-worker|ai-service)-[a-z0-9]+$ ]] || continue
  current_identity="${pid_label}|${start_label}"
  if [[ -z "${creator_identity}" ]]; then
    creator_identity="${current_identity}"
  fi
  [[ "${current_identity}" == "${creator_identity}" ]] || continue
  log "removing Aspire container ${id} (${name})"
  docker rm -f -v "${id}" >/dev/null 2>&1 || true
done

if [[ "${1:-}" == "--full-reset" ]]; then
  rm -rf "${EXP_DIR}/.local/validation"
fi

log "cleanup complete"
