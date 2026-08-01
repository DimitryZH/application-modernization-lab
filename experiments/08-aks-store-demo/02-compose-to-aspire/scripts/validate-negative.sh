#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APPHOST_PROJECT="${EXP_DIR}/src/AppHost/AksStore.AppHost.csproj"
APPHOST_DLL="${EXP_DIR}/src/AppHost/bin/Debug/net10.0/AksStore.AppHost.dll"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
LOG_FILE="${RUN_DIR}/apphost.log"
ERR_FILE="${RUN_DIR}/apphost.err.log"
REPORT_DIR="${EXP_DIR}/.local/validation"
FAIL_OUT="${REPORT_DIR}/negative-rabbitmq-stopped.out"
RECOVERY_OUT="${REPORT_DIR}/negative-rabbitmq-recovery.out"

log() { printf '[validate-negative] %s\n' "$*"; }
fail() { printf '[validate-negative] ERROR: %s\n' "$*" >&2; exit 1; }

start_apphost() {
  mkdir -p "${RUN_DIR}"
  log "building AppHost for negative validation"
  dotnet build "${APPHOST_PROJECT}" >/dev/null
  rm -f "${LOG_FILE}" "${ERR_FILE}"
  log "starting AppHost for negative validation"
  ASPNETCORE_URLS="http://127.0.0.1:18888" \
  ASPIRE_ALLOW_UNSECURED_TRANSPORT="true" \
  DOTNET_ENVIRONMENT="Development" \
  dotnet "${APPHOST_DLL}" >"${LOG_FILE}" 2>"${ERR_FILE}" </dev/null &
  pid=$!
  printf '%s\n' "${pid}" >"${PID_FILE}"
  sleep 5
  if ! kill -0 "${pid}" >/dev/null 2>&1; then
    cat "${LOG_FILE}" >&2 || true
    cat "${ERR_FILE}" >&2 || true
    fail "AppHost exited during negative validation startup"
  fi
}

mkdir -p "${REPORT_DIR}"
rm -f "${FAIL_OUT}" "${RECOVERY_OUT}"

existing_creator=""
for id in $(docker ps -q); do
  name="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' "${id}" 2>/dev/null || true)"
  pid_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' "${id}" 2>/dev/null || true)"
  start_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' "${id}" 2>/dev/null || true)"
  [[ "${name}" =~ ^store-front-[a-z0-9]+$ && -n "${pid_label}" && -n "${start_label}" ]] || continue
  existing_creator="${pid_label}|${start_label}"
done

if [[ -z "${existing_creator}" ]]; then
  log "starting Aspire stack before negative validation"
  start_apphost
  "${SCRIPT_DIR}/validate-aspire.sh" --identity-only --skip-cleanup >/dev/null
else
  "${SCRIPT_DIR}/validate-aspire.sh" --identity-only --skip-cleanup >/dev/null
fi

creator=""
for id in $(docker ps -q); do
  name="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' "${id}" 2>/dev/null || true)"
  pid_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' "${id}" 2>/dev/null || true)"
  start_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' "${id}" 2>/dev/null || true)"
  [[ "${name}" =~ ^store-front-[a-z0-9]+$ && -n "${pid_label}" && -n "${start_label}" ]] || continue
  creator="${pid_label}|${start_label}"
done
if [[ -z "${creator}" ]]; then
  fail "could not determine current Aspire creator identity"
fi

rabbit_id=""
for id in $(docker ps -q); do
  name="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' "${id}" 2>/dev/null || true)"
  pid_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' "${id}" 2>/dev/null || true)"
  start_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' "${id}" 2>/dev/null || true)"
  [[ "${name}" =~ ^rabbitmq-[a-z0-9]+$ && "${pid_label}|${start_label}" == "${creator}" ]] || continue
  rabbit_id="${id}"
done
[[ -n "${rabbit_id}" ]] || fail "current-run Aspire rabbitmq resource was not found"

log "stopping current-run Aspire RabbitMQ dependency ${rabbit_id}"
docker stop "${rabbit_id}" >/dev/null

if "${SCRIPT_DIR}/validate-aspire.sh" --recovery-order-only --skip-cleanup >"${FAIL_OUT}" 2>&1; then
  docker start "${rabbit_id}" >/dev/null || true
  fail "validation unexpectedly passed while the current-run RabbitMQ resource was stopped"
fi
grep -Eiq 'rabbitmq|order-service|queue|order' "${FAIL_OUT}" || fail "negative failure did not identify RabbitMQ/order workflow failure"

log "restoring RabbitMQ and dependent services"
docker start "${rabbit_id}" >/dev/null
sleep 10
for service in order-service makeline-service; do
  for id in $(docker ps -q); do
    name="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' "${id}" 2>/dev/null || true)"
    pid_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' "${id}" 2>/dev/null || true)"
    start_label="$(docker inspect -f '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' "${id}" 2>/dev/null || true)"
    [[ "${name}" =~ ^${service}-[a-z0-9]+$ && "${pid_label}|${start_label}" == "${creator}" ]] || continue
    docker restart "${id}" >/dev/null
  done
done

if ! "${SCRIPT_DIR}/validate-aspire.sh" --recovery-order-only --skip-cleanup >"${RECOVERY_OUT}" 2>&1; then
  cat "${RECOVERY_OUT}" >&2 || true
  fail "RabbitMQ restoration did not recover a fresh unique-order makeline/DocumentDB workflow"
fi

"${SCRIPT_DIR}/cleanup-aspire.sh"
log "RabbitMQ negative failure and fresh-order recovery passed"
