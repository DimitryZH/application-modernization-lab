#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

log() { printf '[cleanup-aspire] %s\n' "$*"; }
fail() { printf '[cleanup-aspire] ERROR: %s\n' "$*" >&2; exit 1; }

creator_identity="$(load_verified_apphost_identity)"
# load_verified_apphost_identity sources the identity file while running in a
# command substitution, so source it again in the current shell for APPHOST_PID.
# shellcheck disable=SC1090
source "${IDENTITY_FILE}"
pid="${APPHOST_PID}"

log "stopping AppHost PID ${pid}"
stop_apphost_pid "${pid}"

unpause_owned_workloads "${creator_identity}"

for id in $(owned_container_ids "${creator_identity}" all); do
  name="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.name")"
  log "removing Aspire container ${id} (${name})"
  docker rm -f -v "${id}" >/dev/null 2>&1 || true
done

rm -f "${PID_FILE}" "${IDENTITY_FILE}"

if [[ "${1:-}" == "--full-reset" ]]; then
  rm -rf "${EXP_DIR}/.local/validation"
fi

log "cleanup complete"
