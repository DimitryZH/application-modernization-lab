#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"
REPORT_DIR="${EXP_DIR}/.local/validation"
OUT_FILE="${REPORT_DIR}/intentional-failure-cleanup.out"
REPORT_FILE="${REPORT_DIR}/latest-report.md"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

log() { printf '[validate-failure-cleanup] %s\n' "$*"; }
fail() { printf '[validate-failure-cleanup] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "${REPORT_DIR}"
rm -f "${OUT_FILE}"

if [[ -f "${PID_FILE}" || -f "${IDENTITY_FILE}" ]]; then
  fail "intentional failure cleanup requires a fresh Experiment 08B AppHost; run scripts/cleanup-aspire.sh first"
fi

set +e
FRONTEND_URL="http://127.0.0.1:1" "${SCRIPT_DIR}/validate-aspire.sh" --start-apphost >"${OUT_FILE}" 2>&1
status=$?
set -e

((status != 0)) || fail "intentional failure unexpectedly passed"

creator="$(grep -Eo 'creator identity [^.]+' "${REPORT_FILE}" 2>/dev/null | tail -n 1 | sed 's/^creator identity //' || true)"
[[ -n "${creator}" ]] || fail "intentional failure did not preserve captured creator identity evidence"

if [[ -f "${PID_FILE}" ]]; then
  pid="$(cat "${PID_FILE}")"
  ! kill -0 "${pid}" >/dev/null 2>&1 || fail "AppHost PID ${pid} still running after failed validation"
fi
[[ ! -f "${IDENTITY_FILE}" ]] || fail "identity file remained after failed validation cleanup"
[[ -z "$(owned_container_ids "${creator}" all)" ]] || fail "owned Experiment 08B containers remained after failed validation cleanup"

grep -q 'store-front health did not become reachable' "${OUT_FILE}" || fail "intentional failure output did not preserve the readiness failure evidence"
log "intentional failure cleanup passed; evidence preserved in ${OUT_FILE}"
