#!/usr/bin/env bash

EXPECTED_SERVICES=(documentdb rabbitmq order-service makeline-service product-service store-front store-admin virtual-customer virtual-worker)
DCP_GROUP_VERSION="usvc-dev.developer.microsoft.com/v1"
RUN_DIR="${RUN_DIR:-${EXP_DIR}/.local/run}"
PID_FILE="${PID_FILE:-${RUN_DIR}/apphost.pid}"
IDENTITY_FILE="${IDENTITY_FILE:-${RUN_DIR}/apphost-identity.env}"

aspire_state_log() { printf '[aspire-run-state] %s\n' "$*"; }
aspire_state_fail() { printf '[aspire-run-state] ERROR: %s\n' "$*" >&2; exit 1; }

expected_resource_regex() {
  printf '^(documentdb|rabbitmq|order-service|makeline-service|product-service|store-front|store-admin|virtual-customer|virtual-worker|ai-service)-[a-z0-9]+$'
}

dcp_label() {
  local id="$1" label="$2"
  docker inspect -f "{{ index .Config.Labels \"${label}\" }}" "${id}" 2>/dev/null || true
}

container_creator_identity() {
  local id="$1" pid_label start_label
  pid_label="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.creatorProcessId")"
  start_label="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.creatorProcessStartTime")"
  [[ -n "${pid_label}" && -n "${start_label}" ]] || return 1
  printf '%s|%s\n' "${pid_label}" "${start_label}"
}

apphost_process_start_ticks() {
  local pid="$1"
  [[ -r "/proc/${pid}/stat" ]] || return 1
  awk '{ print $22 }' "/proc/${pid}/stat"
}

is_experiment08b_dcp_container() {
  local id="$1" name group
  name="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.name")"
  group="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.group-version")"
  [[ "${group}" == "${DCP_GROUP_VERSION}" ]] || return 1
  [[ "${name}" =~ $(expected_resource_regex) ]] || return 1
  container_creator_identity "${id}" >/dev/null || return 1
}

verify_owned_resource_set() {
  local creator="$1" service match id name current owned_names
  [[ -n "${creator}" ]] || aspire_state_fail "cannot verify owned resources without a creator identity"
  owned_names=""
  for service in "${EXPECTED_SERVICES[@]}"; do
    match="$(container_for_identity "${service}" "${creator}" 1 || true)"
    [[ -n "${match}" ]] || aspire_state_fail "stored AppHost identity ${creator} is missing expected resource ${service}"
    id="$(printf '%s\n' "${match}" | cut -f1)"
    name="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.name")"
    current="$(container_creator_identity "${id}")"
    [[ "${current}" == "${creator}" ]] || aspire_state_fail "resource ${service} has inconsistent creator identity ${current}"
    owned_names+="${name}"$'\n'
  done

  while read -r id; do
    [[ -n "${id}" ]] || continue
    name="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.name")"
    [[ "${name}" =~ ^(documentdb|rabbitmq|order-service|makeline-service|product-service|store-front|store-admin|virtual-customer|virtual-worker|ai-service)-[a-z0-9]+$ ]] ||
      aspire_state_fail "owned container ${id} has unexpected Experiment 08B resource name ${name}"
  done < <(owned_container_ids "${creator}" all)

  printf '%s' "${owned_names}" | sort
}

complete_resource_identity_candidates() {
  local identity service ok
  while read -r identity; do
    [[ -n "${identity}" ]] || continue
    ok=1
    for service in "${EXPECTED_SERVICES[@]}"; do
      if ! container_for_identity "${service}" "${identity}" 1 >/dev/null; then
        ok=0
        break
      fi
    done
    [[ "${ok}" == "1" ]] && printf '%s\n' "${identity}"
  done < <(
    for id in $(docker ps -aq); do
      is_experiment08b_dcp_container "${id}" || continue
      container_creator_identity "${id}"
    done | sort -u
  )
}

capture_apphost_identity() {
  local pid="$1" deadline=$((SECONDS + 180)) identity_count creator_pid creator_start process_start selected_identity
  local candidate_identities
  [[ -n "${pid}" ]] || aspire_state_fail "cannot capture AppHost identity without an AppHost PID"
  process_start="$(apphost_process_start_ticks "${pid}")" || aspire_state_fail "cannot read AppHost process start ticks for PID ${pid}"
  while true; do
    if ! kill -0 "${pid}" >/dev/null 2>&1; then
      aspire_state_fail "AppHost PID ${pid} exited before DCP identity capture completed"
    fi

    mapfile -t candidate_identities < <(complete_resource_identity_candidates)
    identity_count="${#candidate_identities[@]}"
    if ((identity_count > 0)); then
      if ((identity_count == 1)); then
        mkdir -p "${RUN_DIR}"
        selected_identity="${candidate_identities[0]}"
        IFS='|' read -r creator_pid creator_start <<<"${selected_identity}"
        {
          printf 'APPHOST_PID=%q\n' "${pid}"
          printf 'APPHOST_PROCESS_START_TICKS=%q\n' "${process_start}"
          printf 'DCP_CREATOR_PROCESS_ID=%q\n' "${creator_pid}"
          printf 'DCP_CREATOR_PROCESS_START_TIME=%q\n' "${creator_start}"
          printf 'DCP_CREATOR_IDENTITY=%q\n' "${selected_identity}"
          printf 'CAPTURED_AT_UTC=%q\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        } >"${IDENTITY_FILE}"
        verify_owned_resource_set "${selected_identity}" >/dev/null
        return 0
      fi
      aspire_state_fail "ambiguous complete DCP creator identities for Experiment 08B AppHost PID ${pid}: ${candidate_identities[*]}"
    fi

    ((SECONDS < deadline)) || aspire_state_fail "timed out waiting for DCP containers owned by AppHost PID ${pid}"
    sleep 3
  done
}

load_verified_apphost_identity() {
  local stored_pid current_process_start matches id current
  [[ -f "${IDENTITY_FILE}" ]] || aspire_state_fail "missing AppHost identity file ${IDENTITY_FILE}; refusing global Aspire cleanup"
  # shellcheck disable=SC1090
  source "${IDENTITY_FILE}"
  [[ -n "${APPHOST_PID:-}" && -n "${APPHOST_PROCESS_START_TICKS:-}" && -n "${DCP_CREATOR_PROCESS_ID:-}" && -n "${DCP_CREATOR_PROCESS_START_TIME:-}" && -n "${DCP_CREATOR_IDENTITY:-}" ]] || aspire_state_fail "AppHost identity file is incomplete"
  [[ -f "${PID_FILE}" ]] || aspire_state_fail "missing AppHost PID file ${PID_FILE}; refusing to use stale creator identity"
  stored_pid="$(cat "${PID_FILE}")"
  [[ "${stored_pid}" == "${APPHOST_PID}" ]] || aspire_state_fail "PID file ${stored_pid} does not match stored AppHost identity ${APPHOST_PID}"
  kill -0 "${APPHOST_PID}" >/dev/null 2>&1 || aspire_state_fail "stored AppHost PID ${APPHOST_PID} is not running; refusing stale cleanup"
  current_process_start="$(apphost_process_start_ticks "${APPHOST_PID}")" || aspire_state_fail "cannot read AppHost process start ticks for PID ${APPHOST_PID}"
  [[ "${current_process_start}" == "${APPHOST_PROCESS_START_TICKS}" ]] || aspire_state_fail "stored AppHost PID ${APPHOST_PID} was reused by another process"

  matches=()
  for id in $(docker ps -aq); do
    is_experiment08b_dcp_container "${id}" || continue
    current="$(container_creator_identity "${id}")"
    [[ "${current}" == "${DCP_CREATOR_IDENTITY}" ]] || continue
    matches+=("${id}")
  done
  ((${#matches[@]} > 0)) || aspire_state_fail "no containers verify stored AppHost identity ${DCP_CREATOR_IDENTITY}; refusing stale cleanup"
  verify_owned_resource_set "${DCP_CREATOR_IDENTITY}" >/dev/null

  printf '%s\n' "${DCP_CREATOR_IDENTITY}"
}

container_for_identity() {
  local service="$1" creator="$2" include_stopped="${3:-0}" matches=() ids name current
  if [[ "${include_stopped}" == "1" ]]; then
    ids="$(docker ps -aq)"
  else
    ids="$(docker ps -q)"
  fi
  for id in ${ids}; do
    is_experiment08b_dcp_container "${id}" || continue
    name="$(dcp_label "${id}" "com.microsoft.developer.usvc-dev.name")"
    current="$(container_creator_identity "${id}")"
    [[ "${name}" =~ ^${service}-[a-z0-9]+$ ]] || continue
    [[ "${current}" == "${creator}" ]] || continue
    matches+=("${id}"$'\t'"${current}"$'\t'"${name}")
  done
  [[ "${#matches[@]}" -le 1 ]] || aspire_state_fail "multiple containers matched ${service} for stored AppHost identity: ${matches[*]}"
  [[ "${#matches[@]}" -eq 1 ]] || return 1
  printf '%s\n' "${matches[0]}"
}

owned_container_ids() {
  local creator="$1" ids="${2:-all}" id current
  if [[ "${ids}" == "running" ]]; then
    ids="$(docker ps -q)"
  else
    ids="$(docker ps -aq)"
  fi
  for id in ${ids}; do
    is_experiment08b_dcp_container "${id}" || continue
    current="$(container_creator_identity "${id}")"
    [[ "${current}" == "${creator}" ]] || continue
    printf '%s\n' "${id}"
  done
}

unpause_owned_workloads() {
  local creator="$1" id match
  for service in virtual-customer virtual-worker; do
    match="$(container_for_identity "${service}" "${creator}" 1 || true)"
    [[ -n "${match}" ]] || continue
    id="$(printf '%s\n' "${match}" | cut -f1)"
    docker unpause "${id}" >/dev/null 2>&1 || true
  done
}

stop_apphost_pid() {
  local pid="${1:-}"
  [[ -n "${pid}" ]] || return 0
  if kill -0 "${pid}" >/dev/null 2>&1; then
    kill "${pid}" >/dev/null 2>&1 || true
    for _ in {1..30}; do
      kill -0 "${pid}" >/dev/null 2>&1 || return 0
      sleep 1
    done
    kill -9 "${pid}" >/dev/null 2>&1 || true
  fi
}
