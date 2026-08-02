#!/usr/bin/env bash
set -euo pipefail

START_APPHOST=0
RECOVERY_ONLY=0
IDENTITY_ONLY=0
SKIP_CLEANUP=0
for arg in "$@"; do
  case "${arg}" in
    --start-apphost) START_APPHOST=1 ;;
    --recovery-order-only) RECOVERY_ONLY=1 ;;
    --identity-only) IDENTITY_ONLY=1 ;;
    --skip-cleanup) SKIP_CLEANUP=1 ;;
    *) printf '[validate-aspire] ERROR: unknown argument: %s\n' "${arg}" >&2; exit 1 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXP_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASELINE_DIR="$(cd "${EXP_DIR}/../01-compose-baseline" && pwd)"
APPHOST_PROJECT="${EXP_DIR}/src/AppHost/AksStore.AppHost.csproj"
APPHOST_DLL="${EXP_DIR}/src/AppHost/bin/Debug/net10.0/AksStore.AppHost.dll"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:8080}"
ADMIN_URL="${ADMIN_URL:-http://127.0.0.1:8081}"
REPORT_DIR="${EXP_DIR}/.local/validation"
REPORT_FILE="${REPORT_DIR}/latest-report.md"
RUN_DIR="${EXP_DIR}/.local/run"
PID_FILE="${RUN_DIR}/apphost.pid"
LOG_FILE="${RUN_DIR}/apphost.log"
ERR_FILE="${RUN_DIR}/apphost.err.log"
IDENTITY_FILE="${RUN_DIR}/apphost-identity.env"

# shellcheck source=aspire-run-state.sh
source "${SCRIPT_DIR}/aspire-run-state.sh"

APPHOST_PID=""
CURRENT_CREATOR=""
WORKLOAD_PAUSED=0
RABBITMQ_STOPPED_ID=""

log() { printf '[validate-aspire] %s\n' "$*"; }
fail() { printf '[validate-aspire] ERROR: %s\n' "$*" >&2; exit 1; }
record() { printf -- '- %s\n' "$*" >>"${REPORT_FILE}"; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }
json_eval() { python3 -c "$1"; }

start_apphost_for_validation() {
  mkdir -p "${RUN_DIR}"
  if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" >/dev/null 2>&1; then
    fail "AppHost already appears to be running as PID $(cat "${PID_FILE}"); run scripts/cleanup-aspire.sh first"
  fi
  rm -f "${LOG_FILE}" "${ERR_FILE}" "${IDENTITY_FILE}"
  log "starting AppHost for validation"
  ASPNETCORE_URLS="http://127.0.0.1:18888" \
  ASPIRE_ALLOW_UNSECURED_TRANSPORT="true" \
  DOTNET_ENVIRONMENT="Development" \
  dotnet "${APPHOST_DLL}" >"${LOG_FILE}" 2>"${ERR_FILE}" </dev/null &
  APPHOST_PID=$!
  printf '%s\n' "${APPHOST_PID}" >"${PID_FILE}"
  sleep 5
  if ! kill -0 "${APPHOST_PID}" >/dev/null 2>&1; then
    cat "${LOG_FILE}" >&2 || true
    cat "${ERR_FILE}" >&2 || true
    fail "AppHost exited during startup"
  fi
  capture_apphost_identity "${APPHOST_PID}"
  CURRENT_CREATOR="$(load_verified_apphost_identity)"
  record "AppHost started for validation as PID ${APPHOST_PID}; dashboard bound to loopback port 18888."
  record "Captured and persisted current AppHost DCP creator identity ${CURRENT_CREATOR}."
}

container_for() {
  local service="$1" creator="$2"
  container_for_identity "${service}" "${creator}" 0
}

creator_identity() {
  load_verified_apphost_identity
}

assert_container_set() {
  local creator actual expected
  creator="$(creator_identity)"
  actual=""
  for service in "${EXPECTED_SERVICES[@]}"; do
    local match id state
    match="$(container_for "${service}" "${creator}")" || fail "missing running Aspire-managed container for ${service}"
    id="$(printf '%s\n' "${match}" | cut -f1)"
    state="$(docker inspect -f '{{.State.Running}} {{.State.Restarting}} {{.RestartCount}} {{.State.ExitCode}}' "${id}")"
    read -r running restarting _ exit_code <<<"${state}"
    [[ "${running}" == "true" && "${restarting}" == "false" && "${exit_code}" == "0" ]] || fail "${service} container is not stable: ${state}"
    actual+="${service}"$'\n'
  done
  expected="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | sort)"
  [[ "$(printf '%s' "${actual}" | sort)" == "${expected}" ]] || fail "unexpected Aspire resource set"
  record "DCP labels identify the nine expected Aspire resources with one shared creator identity ${creator}."
  printf '%s\n' "${creator}"
}

id_for() {
  local service="$1" creator="$2" match
  match="$(container_for "${service}" "${creator}")" || fail "missing ${service}"
  printf '%s\n' "${match}" | cut -f1
}

assert_env() {
  local id="$1" service="$2"; shift 2
  local env
  env="$(docker inspect -f '{{range .Config.Env}}{{println .}}{{end}}' "${id}")"
  for expected in "$@"; do
    grep -Fxq "${expected}" <<<"${env}" || fail "${service} missing environment ${expected}"
  done
}

wait_for_http() {
  local label="$1" url="$2" deadline=$((SECONDS + 600))
  until curl -fsS "${url}" >/dev/null; do
    (( SECONDS < deadline )) || fail "${label} did not become reachable at ${url}"
    sleep 5
  done
  record "${label} reachable at ${url}."
}

assert_versions_and_source() {
  [[ "$(dotnet --version)" == "10.0.110" ]] || fail "expected .NET SDK 10.0.110, found $(dotnet --version)"
  grep -Fq 'Sdk="Aspire.AppHost.Sdk/13.4.6"' "${APPHOST_PROJECT}" || fail "AppHost SDK is not pinned to Aspire 13.4.6"
  (cd "${BASELINE_DIR}" && sha256sum -c upstream-source.sha256 >/dev/null) || fail "08A source hash check failed"
  record ".NET SDK 10.0.110, Aspire.AppHost.Sdk 13.4.6, and 08A upstream source hash were verified."
}

assert_endpoint_exposure() {
  local creator="$1" front admin
  front="$(id_for store-front "${creator}")"
  admin="$(id_for store-admin "${creator}")"
  docker port "${front}" 8080/tcp | grep -qE '^(127\.0\.0\.1|localhost):8080$' || fail "store-front is not bound to loopback 8080"
  docker port "${admin}" 8081/tcp | grep -qE '^(127\.0\.0\.1|localhost):8081$' || fail "store-admin is not bound to loopback 8081"
  for service in documentdb rabbitmq order-service makeline-service product-service virtual-customer virtual-worker; do
    id="$(id_for "${service}" "${creator}")"
    [[ -z "$(docker port "${id}")" ]] || fail "${service} unexpectedly exposes a host port"
  done
  record "Only store-front 8080 and store-admin 8081 are host-published, both on loopback."
}

assert_service_env() {
  local creator="$1"
  assert_env "$(id_for rabbitmq "${creator}")" rabbitmq "RABBITMQ_DEFAULT_USER=username" "RABBITMQ_DEFAULT_PASS=password"
  assert_env "$(id_for order-service "${creator}")" order-service "ORDER_QUEUE_HOSTNAME=rabbitmq" "ORDER_QUEUE_PORT=5672" "ORDER_QUEUE_USERNAME=username" "ORDER_QUEUE_PASSWORD=password" "ORDER_QUEUE_NAME=orders"
  assert_env "$(id_for makeline-service "${creator}")" makeline-service "ORDER_QUEUE_URI=amqp://rabbitmq:5672" "ORDER_QUEUE_USERNAME=username" "ORDER_QUEUE_PASSWORD=password" "ORDER_QUEUE_NAME=orders" "ORDER_DB_URI=mongodb://documentdb:10260/?tls=true&tlsAllowInvalidCertificates=true" "ORDER_DB_NAME=orderdb" "ORDER_DB_COLLECTION_NAME=orders" "ORDER_DB_USERNAME=username" "ORDER_DB_PASSWORD=password"
  assert_env "$(id_for product-service "${creator}")" product-service "AI_SERVICE_URL=http://ai-service:5001/"
  assert_env "$(id_for virtual-customer "${creator}")" virtual-customer "ORDER_SERVICE_URL=http://order-service:3000/" "ORDERS_PER_HOUR=1"
  assert_env "$(id_for virtual-worker "${creator}")" virtual-worker "MAKELINE_SERVICE_URL=http://makeline-service:3001" "ORDERS_PER_HOUR=1"
  record "Required environment contracts match the accepted Compose baseline."
}

rabbitmq_queue_state() {
  docker exec "$(id_for rabbitmq "$1")" rabbitmqctl list_queues name messages_ready messages_unacknowledged --formatter json
}

assert_rabbitmq_queue() {
  local state found
  state="$(rabbitmq_queue_state "$1")"
  found="$(printf '%s' "${state}" | json_eval 'import json,sys; print(any(row.get("name") == "orders" for row in json.load(sys.stdin)))')"
  [[ "${found}" == "True" ]] || fail "RabbitMQ queue 'orders' was not present"
  record "RabbitMQ queue 'orders' exists in the current Aspire rabbitmq resource."
}

pause_workload() {
  local creator="$1"
  docker pause "$(id_for virtual-customer "${creator}")" "$(id_for virtual-worker "${creator}")" >/dev/null || true
  WORKLOAD_PAUSED=1
  record "Paused virtual-customer and virtual-worker while collecting deterministic order evidence."
}

unpause_workload() {
  local creator="$1"
  docker unpause "$(id_for virtual-customer "${creator}")" "$(id_for virtual-worker "${creator}")" >/dev/null 2>&1 || true
  WORKLOAD_PAUSED=0
}

safe_failure_cleanup() {
  local status=$?
  trap - EXIT INT TERM
  if ((status != 0)); then
    if [[ -n "${CURRENT_CREATOR}" ]]; then
      if [[ -n "${RABBITMQ_STOPPED_ID}" ]]; then
        docker start "${RABBITMQ_STOPPED_ID}" >/dev/null 2>&1 || true
      fi
      if ((WORKLOAD_PAUSED == 1)); then
        unpause_owned_workloads "${CURRENT_CREATOR}"
      fi
      if ((SKIP_CLEANUP == 0)); then
        "${SCRIPT_DIR}/cleanup-aspire.sh" >/dev/null 2>&1 || true
      fi
    elif ((START_APPHOST == 1)) && [[ -f "${PID_FILE}" ]]; then
      stop_apphost_pid "$(cat "${PID_FILE}")"
    fi
  fi
  exit "${status}"
}

submit_unique_order() {
  local customer_id="$1"
  curl -fsS -o /tmp/aks-store-aspire-order-response.txt -w '%{http_code}' \
    -X POST "${FRONTEND_URL}/api/orders" \
    -H 'Content-Type: application/json' \
    --data "{\"customerId\":\"${customer_id}\",\"items\":[{\"productId\":1,\"quantity\":1,\"price\":9.99}]}"
}

find_order_id_for_customer() {
  local customer_id="$1" orders
  orders="$(curl -fsS "${ADMIN_URL}/api/makeline/order/fetch" || true)"
  [[ -n "${orders}" ]] || { printf ''; return 0; }
  printf '%s' "${orders}" | CUSTOMER_ID="${customer_id}" json_eval 'import json,os,sys; data=json.load(sys.stdin); matches=[o for o in data if o.get("customerId")==os.environ["CUSTOMER_ID"]]; print(matches[0].get("orderId","") if matches else "")'
}

wait_for_order() {
  local customer_id="$1" deadline=$((SECONDS + 240)) order_id
  while true; do
    order_id="$(find_order_id_for_customer "${customer_id}")"
    [[ -n "${order_id}" ]] && { printf '%s' "${order_id}"; return 0; }
    (( SECONDS < deadline )) || fail "current-run order for ${customer_id} was not visible through admin/makeline"
    sleep 3
  done
}

assert_order_visible() {
  local order_id="$1" customer_id="$2" order_json order_customer
  order_json="$(curl -fsS "${ADMIN_URL}/api/makeline/order/${order_id}" || true)"
  [[ -n "${order_json}" ]] || fail "DocumentDB-backed order ${order_id} was not fetchable"
  order_customer="$(printf '%s' "${order_json}" | json_eval 'import json,sys; print(json.load(sys.stdin).get("customerId",""))')"
  [[ "${order_customer}" == "${customer_id}" ]] || fail "order ${order_id} did not contain customerId ${customer_id}"
}

run_current_order_flow() {
  local creator="$1" suffix customer_id status order_id count deadline
  suffix="$(date -u +%Y%m%d%H%M%S)-$$"
  customer_id="aml08b-${suffix}"
  pause_workload "${creator}"
  deadline=$((SECONDS + 240))
  status=""
  while true; do
    status="$(submit_unique_order "${customer_id}" || true)"
    [[ "${status}" == "201" ]] && break
    (( SECONDS < deadline )) || fail "order-service returned HTTP ${status:-curl-failed} for current-run order"
    sleep 5
  done
  order_id="$(wait_for_order "${customer_id}")"
  assert_order_visible "${order_id}" "${customer_id}"
  count="$(curl -fsS "${FRONTEND_URL}/api/products" | json_eval 'import json,sys; print(len(json.load(sys.stdin)))')"
  [[ "${count}" =~ ^[0-9]+$ && "${count}" -gt 0 ]] || fail "product workflow returned no products"
  record "Product workflow returned ${count} products; unique order ${order_id} for ${customer_id} reached makeline/DocumentDB."
  unpause_workload "${creator}"
  printf '%s:%s\n' "${order_id}" "${customer_id}"
}

assert_makeline_restart_persistence() {
  local creator="$1" order_id="$2" customer_id="$3"
  docker restart "$(id_for makeline-service "${creator}")" >/dev/null
  wait_for_http "store-admin makeline after makeline restart" "${ADMIN_URL}/api/makeline/order/fetch"
  assert_order_visible "${order_id}" "${customer_id}"
  record "Makeline-service restart preserved access to current-run order ${order_id}; DocumentDB state remained container-local."
}

assert_no_tracked_runtime_artifacts() {
  local top rel
  top="$(git rev-parse --show-toplevel)"
  rel="${EXP_DIR#${top}/}"
  ! git -C "${top}" ls-files -- "${rel}/.local" | grep -q . || fail "runtime artifacts under .local are tracked"
  record "Runtime validation artifacts are ignored and untracked."
}

main() {
  trap safe_failure_cleanup EXIT INT TERM
  require_command dotnet
  require_command docker
  require_command curl
  require_command python3
  require_command sha256sum
  mkdir -p "${REPORT_DIR}"
  printf '# AKS Store Demo Aspire Developer Validation Report\n\nGenerated: %s UTC\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${REPORT_FILE}"

  assert_versions_and_source
  assert_no_tracked_runtime_artifacts
  log "building AppHost"
  (cd "${EXP_DIR}" && dotnet build "${APPHOST_PROJECT}")

  if (( START_APPHOST == 1 )); then
    start_apphost_for_validation
  fi

  wait_for_http "store-front health" "${FRONTEND_URL}/health"
  wait_for_http "store-admin health" "${ADMIN_URL}/health"
  wait_for_http "store-front product proxy" "${FRONTEND_URL}/api/products"
  wait_for_http "store-admin product proxy" "${ADMIN_URL}/api/products"

  CURRENT_CREATOR="$(assert_container_set)"
  assert_endpoint_exposure "${CURRENT_CREATOR}"
  assert_service_env "${CURRENT_CREATOR}"
  assert_rabbitmq_queue "${CURRENT_CREATOR}"

  if (( IDENTITY_ONLY == 1 )); then
    exit 0
  fi

  IFS=: read -r order_id customer_id < <(run_current_order_flow "${CURRENT_CREATOR}")
  if (( RECOVERY_ONLY == 1 )); then
    record "RabbitMQ recovery accepted and stored fresh order ${order_id} for ${customer_id}."
    exit 0
  fi

  assert_makeline_restart_persistence "${CURRENT_CREATOR}" "${order_id}" "${customer_id}"
  record "DocumentDB restart/AppHost stop-start/container recreation durability are not claimed; no named volume was added."

  if (( SKIP_CLEANUP == 0 )); then
    "${SCRIPT_DIR}/cleanup-aspire.sh"
    record "Cleanup removed only current Experiment 08B Aspire resources."
  fi
  log "validation completed successfully; evidence: ${REPORT_FILE}"
}

main "$@"
