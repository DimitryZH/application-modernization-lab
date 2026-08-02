#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"
REPORT_DIR="${EXP_DIR}/.local/validation"
OUT_FILE="${REPORT_DIR}/ownership-guardrails.out"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

log() { printf '[validate-ownership-guardrails] %s\n' "$*"; }
fail() { printf '[validate-ownership-guardrails] ERROR: %s\n' "$*" >&2; exit 1; }

UNRELATED_ID=""

cleanup_fixture() {
  [[ -n "${UNRELATED_ID}" ]] && docker rm -f -v "${UNRELATED_ID}" >/dev/null 2>&1 || true
  rm -f "${PID_FILE}" "${IDENTITY_FILE}"
}

expect_cleanup_failure() {
  local label="$1"
  shift
  if "${SCRIPT_DIR}/cleanup-aspire.sh" >>"${OUT_FILE}" 2>&1; then
    fail "cleanup unexpectedly succeeded for ${label}"
  fi
  log "cleanup failed safely for ${label}"
  "$@"
}

mkdir -p "${RUN_DIR}" "${REPORT_DIR}"
rm -f "${OUT_FILE}"
trap cleanup_fixture EXIT INT TERM

if [[ -f "${PID_FILE}" || -f "${IDENTITY_FILE}" ]]; then
  fail "ownership guardrail validation requires no active Experiment 08B runtime state"
fi

expect_cleanup_failure "missing identity" true

printf '999999\n' >"${PID_FILE}"
printf 'APPHOST_PID=999999\n' >"${IDENTITY_FILE}"
expect_cleanup_failure "incomplete identity" true

cat >"${IDENTITY_FILE}" <<'EOF_ID'
APPHOST_PID=999999
APPHOST_PROCESS_START_TICKS=0
DCP_CREATOR_PROCESS_ID=999998
DCP_CREATOR_PROCESS_START_TIME=stale-start
DCP_CREATOR_IDENTITY=999998|stale-start
CAPTURED_AT_UTC=2026-08-02T00:00:00Z
EOF_ID
expect_cleanup_failure "stale AppHost PID" true

cleanup_fixture
mkdir -p "${RUN_DIR}"
docker image inspect rabbitmq:4.3.2-management-alpine >/dev/null 2>&1 || fail "rabbitmq image is required for ownership guardrail validation"
UNRELATED_ID="$(docker create \
  --name "aks-store-08b-partial-dcp-$$" \
  --label "com.microsoft.developer.usvc-dev.group-version=${DCP_GROUP_VERSION}" \
  --label "com.microsoft.developer.usvc-dev.name=rabbitmq-adversarial" \
  --label "com.microsoft.developer.usvc-dev.creatorProcessId=424242" \
  --label "com.microsoft.developer.usvc-dev.creatorProcessStartTime=adversarial-start" \
  rabbitmq:4.3.2-management-alpine)"

script_start="$(apphost_process_start_ticks "$$")"
printf '%s\n' "$$" >"${PID_FILE}"
cat >"${IDENTITY_FILE}" <<EOF_ID
APPHOST_PID=$$
APPHOST_PROCESS_START_TICKS=${script_start}
DCP_CREATOR_PROCESS_ID=424242
DCP_CREATOR_PROCESS_START_TIME=adversarial-start
DCP_CREATOR_IDENTITY=424242|adversarial-start
CAPTURED_AT_UTC=$(date -u +%Y-%m-%dT%H:%M:%SZ)
EOF_ID

expect_cleanup_failure "partial unrelated DCP identity" true
docker inspect "${UNRELATED_ID}" >/dev/null 2>&1 || fail "partial unrelated DCP container was removed"

cleanup_fixture
UNRELATED_ID=""
trap - EXIT INT TERM
log "ownership guardrails passed; evidence preserved in ${OUT_FILE}"
