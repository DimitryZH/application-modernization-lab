#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"
REPORT_DIR="${EXP_DIR}/.local/validation"
OUT_FILE="${REPORT_DIR}/cleanup-isolation.out"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

log() { printf '[validate-cleanup-isolation] %s\n' "$*"; }
fail() { printf '[validate-cleanup-isolation] ERROR: %s\n' "$*" >&2; exit 1; }

UNRELATED_NAME="aks-store-08b-unrelated-dcp-$$"
UNRELATED_ID=""
CURRENT_CREATOR=""

cleanup_unrelated() {
  [[ -n "${UNRELATED_ID}" ]] && docker rm -f -v "${UNRELATED_ID}" >/dev/null 2>&1 || true
}

safe_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  cleanup_unrelated
  if [[ -n "${CURRENT_CREATOR}" && -f "${IDENTITY_FILE}" ]]; then
    "${SCRIPT_DIR}/cleanup-aspire.sh" >/dev/null 2>&1 || true
  elif [[ -f "${PID_FILE}" ]]; then
    stop_apphost_pid "$(cat "${PID_FILE}")"
  fi
  exit "${status}"
}

mkdir -p "${REPORT_DIR}"
rm -f "${OUT_FILE}"
trap safe_cleanup EXIT INT TERM

if [[ -f "${PID_FILE}" || -f "${IDENTITY_FILE}" ]]; then
  fail "cleanup isolation requires a fresh Experiment 08B AppHost; run scripts/cleanup-aspire.sh first"
fi

log "starting current Experiment 08B AppHost for cleanup isolation"
"${SCRIPT_DIR}/validate-aspire.sh" --start-apphost --identity-only --skip-cleanup >"${OUT_FILE}" 2>&1
CURRENT_CREATOR="$(load_verified_apphost_identity)"

docker image inspect rabbitmq:4.3.2-management-alpine >/dev/null 2>&1 || fail "rabbitmq image is required for the unrelated DCP isolation container"
UNRELATED_ID="$(docker create \
  --name "${UNRELATED_NAME}" \
  --label "com.microsoft.developer.usvc-dev.group-version=${DCP_GROUP_VERSION}" \
  --label "com.microsoft.developer.usvc-dev.name=store-front-unrelated" \
  --label "com.microsoft.developer.usvc-dev.creatorProcessId=999999" \
  --label "com.microsoft.developer.usvc-dev.creatorProcessStartTime=unrelated-start" \
  rabbitmq:4.3.2-management-alpine)"

before_state="$(docker inspect -f '{{.State.Status}}' "${UNRELATED_ID}")"
before_identity="$(container_creator_identity "${UNRELATED_ID}")"

log "running cleanup against current AppHost identity ${CURRENT_CREATOR}"
"${SCRIPT_DIR}/cleanup-aspire.sh" >>"${OUT_FILE}" 2>&1
CURRENT_CREATOR=""

docker inspect "${UNRELATED_ID}" >/dev/null 2>&1 || fail "unrelated DCP-labeled container was removed"
after_state="$(docker inspect -f '{{.State.Status}}' "${UNRELATED_ID}")"
after_identity="$(container_creator_identity "${UNRELATED_ID}")"
[[ "${before_state}" == "${after_state}" ]] || fail "unrelated DCP-labeled container state changed from ${before_state} to ${after_state}"
[[ "${before_identity}" == "${after_identity}" ]] || fail "unrelated DCP-labeled container creator identity changed"

for id in $(owned_container_ids "${before_identity}" all); do
  [[ "${UNRELATED_ID}" == "${id}"* || "${id}" == "${UNRELATED_ID}"* ]] || fail "unexpected unrelated identity match ${id}"
done

cleanup_unrelated
UNRELATED_ID=""
trap - EXIT INT TERM
log "cleanup isolation passed; unrelated DCP-labeled container was preserved"
