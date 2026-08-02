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
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"
REPORT_DIR="${EXP_DIR}/.local/validation"
FAIL_OUT="${REPORT_DIR}/negative-rabbitmq-stopped.out"
RECOVERY_OUT="${REPORT_DIR}/negative-rabbitmq-recovery.out"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

CURRENT_CREATOR=""
RABBIT_ID=""

log() { printf '[validate-negative] %s\n' "$*"; }
fail() { printf '[validate-negative] ERROR: %s\n' "$*" >&2; exit 1; }

start_apphost() {
  mkdir -p "${RUN_DIR}"
  log "building AppHost for negative validation"
  dotnet build "${APPHOST_PROJECT}" >/dev/null
  rm -f "${LOG_FILE}" "${ERR_FILE}" "${IDENTITY_FILE}"
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
  capture_apphost_identity "${pid}"
}

safe_failure_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if [[ -n "${RABBIT_ID}" ]]; then
    docker start "${RABBIT_ID}" >/dev/null 2>&1 || true
  fi
  if [[ -n "${CURRENT_CREATOR}" ]]; then
    unpause_owned_workloads "${CURRENT_CREATOR}"
    "${SCRIPT_DIR}/cleanup-aspire.sh" >/dev/null 2>&1 || true
  elif [[ -f "${PID_FILE}" ]]; then
    stop_apphost_pid "$(cat "${PID_FILE}")"
  fi
  exit "${status}"
}

mkdir -p "${REPORT_DIR}"
rm -f "${FAIL_OUT}" "${RECOVERY_OUT}"
trap safe_failure_cleanup EXIT INT TERM

if [[ -f "${PID_FILE}" || -f "${IDENTITY_FILE}" ]]; then
  fail "negative validation requires a fresh Experiment 08B AppHost; run scripts/cleanup-aspire.sh first"
fi

log "starting fresh Aspire stack before negative validation"
start_apphost
"${SCRIPT_DIR}/validate-aspire.sh" --identity-only --skip-cleanup >/dev/null
CURRENT_CREATOR="$(load_verified_apphost_identity)"

match="$(container_for_identity rabbitmq "${CURRENT_CREATOR}" 0)" || fail "current-run Aspire rabbitmq resource was not found"
RABBIT_ID="$(printf '%s\n' "${match}" | cut -f1)"

log "stopping current-run Aspire RabbitMQ dependency ${RABBIT_ID}"
docker stop "${RABBIT_ID}" >/dev/null

if "${SCRIPT_DIR}/validate-aspire.sh" --recovery-order-only --skip-cleanup >"${FAIL_OUT}" 2>&1; then
  docker start "${RABBIT_ID}" >/dev/null || true
  fail "validation unexpectedly passed while the current-run RabbitMQ resource was stopped"
fi
grep -Eiq 'rabbitmq|order-service|queue|order' "${FAIL_OUT}" || fail "negative failure did not identify RabbitMQ/order workflow failure"

log "restoring RabbitMQ and dependent services"
docker start "${RABBIT_ID}" >/dev/null
RABBIT_ID=""
sleep 10
for service in order-service makeline-service; do
  match="$(container_for_identity "${service}" "${CURRENT_CREATOR}" 0)" || continue
  docker restart "$(printf '%s\n' "${match}" | cut -f1)" >/dev/null
done

if ! "${SCRIPT_DIR}/validate-aspire.sh" --recovery-order-only --skip-cleanup >"${RECOVERY_OUT}" 2>&1; then
  cat "${RECOVERY_OUT}" >&2 || true
  fail "RabbitMQ restoration did not recover a fresh unique-order makeline/DocumentDB workflow"
fi

"${SCRIPT_DIR}/cleanup-aspire.sh"
CURRENT_CREATOR=""
trap - EXIT INT TERM
log "RabbitMQ negative failure and fresh-order recovery passed"
