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

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

log() { printf '[start-aspire] %s\n' "$*"; }
fail() { printf '[start-aspire] ERROR: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }

require_command dotnet
require_command docker

mkdir -p "${RUN_DIR}"
cd "${EXP_DIR}"

if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
  fail "AppHost already appears to be running as PID $(cat "${PID_FILE}"); run scripts/cleanup-aspire.sh first"
fi

sdk="$(dotnet --version)"
[[ "${sdk}" == "10.0.110" ]] || fail "expected .NET SDK 10.0.110, found ${sdk}"

log "building AppHost with .NET SDK ${sdk}"
dotnet build "${APPHOST_PROJECT}"

rm -f "${LOG_FILE}" "${ERR_FILE}" "${IDENTITY_FILE}"
log "starting AppHost"
ASPNETCORE_URLS="http://127.0.0.1:18888" \
ASPIRE_ALLOW_UNSECURED_TRANSPORT="true" \
DOTNET_ENVIRONMENT="Development" \
nohup dotnet "${APPHOST_DLL}" >"${LOG_FILE}" 2>"${ERR_FILE}" </dev/null &
pid=$!
printf '%s\n' "${pid}" >"${PID_FILE}"

sleep 5
if ! kill -0 "${pid}" >/dev/null 2>&1; then
  cat "${LOG_FILE}" >&2 || true
  cat "${ERR_FILE}" >&2 || true
  fail "AppHost exited during startup"
fi

capture_apphost_identity "${pid}"
log "AppHost PID ${pid}; identity captured in ${IDENTITY_FILE}; logs under ${RUN_DIR}"
