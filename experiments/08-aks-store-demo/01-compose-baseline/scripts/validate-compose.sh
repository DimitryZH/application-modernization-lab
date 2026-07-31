#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-aks-store-demo-compose}"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:8080}"
ADMIN_URL="${ADMIN_URL:-http://127.0.0.1:8081}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASELINE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPORT_DIR="${BASELINE_DIR}/.local/validation"
REPORT_FILE="${REPORT_DIR}/latest-report.md"
EXPECTED_SERVICES=(documentdb rabbitmq order-service makeline-service product-service store-front store-admin virtual-customer virtual-worker)

cd "${BASELINE_DIR}"

log() { printf '[validate-compose] %s\n' "$*"; }
fail() { printf '[validate-compose] ERROR: %s\n' "$*" >&2; exit 1; }
require_command() { command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"; }
compose() { docker compose -p "${PROJECT_NAME}" "$@"; }
container_id() { compose ps -q "$1"; }
exec_service() { local service="$1"; shift; compose exec -T "$service" "$@"; }
record() { printf -- '- %s\n' "$*" >>"${REPORT_FILE}"; }

json_eval() {
  python3 -c "$1"
}

check_source_snapshot() {
  [[ -f upstream-source.sha256 ]] || fail "missing upstream-source.sha256 provenance manifest"
  sha256sum -c upstream-source.sha256 >/dev/null || fail "pinned upstream source snapshot hash check failed"
  [[ ! -d .git ]] || fail "nested upstream .git metadata must not be tracked in the baseline snapshot"
  record "Pinned source manifest verified for upstream commit 7ce10c5110d6a52d3517dfb6d7a7b7b2edf2e5a5."
}

check_effective_config() {
  local actual expected
  actual="$(compose config --services | sort)"
  expected="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | sort)"
  [[ "${actual}" == "${expected}" ]] || fail "unexpected default Compose service set: ${actual//$'\n'/, }"
  ! compose config | grep -q 'container_name:' || fail "fixed container_name values are not allowed in the Experiment 08A baseline"
  compose config | grep -q 'host_ip: 127.0.0.1' || fail "UI host bindings must use loopback host_ip 127.0.0.1"
  compose config | grep -q 'published: "8080"' || fail "store-front must publish loopback port 8080"
  compose config | grep -q 'published: "8081"' || fail "store-admin must publish loopback port 8081"
  if compose config | grep -Eq 'published: "?(3000|3001|3002|5672|10260)"?'; then
    fail "backend ports must remain internal in the default Compose profile"
  fi
  record "Rendered Compose configuration has the nine approved non-AI services, no fixed container names, and loopback-only UI host bindings."
}

assert_clean_project() {
  local existing
  existing="$(docker ps -a --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Names}}' | sort)"
  [[ -z "${existing}" ]] || fail "stale Experiment 08 containers exist for ${PROJECT_NAME}: ${existing//$'\n'/, }; run scripts/cleanup-compose.sh first"
}

assert_compose_identity() {
  local actual expected
  actual="$(docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Label "com.docker.compose.service"}}' | sort)"
  expected="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | sort)"
  [[ "${actual}" == "${expected}" ]] || fail "unexpected running services for project ${PROJECT_NAME}: ${actual//$'\n'/, }"

  for service in "${EXPECTED_SERVICES[@]}"; do
    local cid project_label service_label running
    cid="$(container_id "$service")"
    [[ -n "${cid}" ]] || fail "missing container for ${service}"
    project_label="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$cid")"
    service_label="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.service" }}' "$cid")"
    running="$(docker inspect -f '{{.State.Running}}' "$cid")"
    [[ "${project_label}" == "${PROJECT_NAME}" && "${service_label}" == "${service}" && "${running}" == "true" ]] || fail "container ${cid} is not the expected running ${PROJECT_NAME}/${service} resource"
  done
  record "Docker labels identify only the expected ${PROJECT_NAME} Compose resources."
}

wait_for_container_health() {
  local service="$1" deadline=$((SECONDS + 600)) status
  while true; do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$(container_id "$service")" 2>/dev/null || true)"
    [[ "${status}" == "healthy" || "${status}" == "none" ]] && break
    if (( SECONDS >= deadline )); then
      compose ps
      fail "${service} did not become healthy; last status=${status}"
    fi
    sleep 5
  done
}

wait_for_http() {
  local label="$1" url="$2" deadline=$((SECONDS + 300))
  until curl -fsS "${url}" >/dev/null; do
    if (( SECONDS >= deadline )); then
      fail "${label} did not become reachable at ${url}"
    fi
    sleep 5
  done
  record "${label} reachable at ${url}."
}

wait_for_stack() {
  for service in documentdb rabbitmq order-service makeline-service product-service store-front store-admin; do
    wait_for_container_health "$service"
  done
  wait_for_http "store-front health" "${FRONTEND_URL}/health"
  wait_for_http "store-admin health" "${ADMIN_URL}/health"
  wait_for_http "store-front product proxy" "${FRONTEND_URL}/api/products"
  wait_for_http "store-admin product proxy" "${ADMIN_URL}/api/products"
}

assert_products() {
  local products count
  products="$(curl -fsS "${FRONTEND_URL}/api/products")"
  count="$(printf '%s' "${products}" | json_eval 'import json,sys; data=json.load(sys.stdin); print(len(data))')"
  [[ "${count}" =~ ^[0-9]+$ && "${count}" -gt 0 ]] || fail "product workflow returned no products"
  record "Product workflow returned ${count} seeded products through the storefront proxy."
}

rabbitmq_queue_state() {
  exec_service rabbitmq rabbitmqctl list_queues name messages_ready messages_unacknowledged --formatter json
}

assert_rabbitmq_queue() {
  local state found
  state="$(rabbitmq_queue_state)"
  found="$(printf '%s' "${state}" | json_eval 'import json,sys; data=json.load(sys.stdin); print(any(row.get("name") == "orders" for row in data))')"
  [[ "${found}" == "True" ]] || fail "RabbitMQ queue 'orders' was not present"
  record "RabbitMQ queue 'orders' exists in the Experiment 08 rabbitmq container."
}

pause_virtual_workload() {
  compose pause virtual-customer virtual-worker >/dev/null
  record "Paused virtual-customer and virtual-worker during unique current-run evidence collection."
}

unpause_virtual_workload() {
  compose unpause virtual-customer virtual-worker >/dev/null || true
}

submit_unique_order() {
  local customer_id="$1"
  curl -fsS -o /tmp/aks-store-order-response.txt -w '%{http_code}' \
    -X POST "${FRONTEND_URL}/api/orders" \
    -H 'Content-Type: application/json' \
    --data "{\"customerId\":\"${customer_id}\",\"items\":[{\"productId\":1,\"quantity\":1,\"price\":9.99}]}"
}

find_order_id_for_customer() {
  local customer_id="$1" orders
  orders="$(curl -fsS "${ADMIN_URL}/api/makeline/order/fetch" || true)"
  if [[ -z "${orders}" ]]; then
    printf ''
    return 0
  fi
  printf '%s' "${orders}" | CUSTOMER_ID="${customer_id}" json_eval 'import json,os,sys; data=json.load(sys.stdin); matches=[o for o in data if o.get("customerId") == os.environ["CUSTOMER_ID"]]; print(matches[0].get("orderId", "") if matches else "")'
}

wait_for_order() {
  local customer_id="$1" deadline=$((SECONDS + 180)) order_id
  while true; do
    order_id="$(find_order_id_for_customer "${customer_id}")"
    if [[ -n "${order_id}" ]]; then
      printf '%s' "${order_id}"
      return 0
    fi
    if (( SECONDS >= deadline )); then
      fail "current-run order for ${customer_id} was not visible through admin/makeline DocumentDB-backed workflow"
    fi
    sleep 3
  done
}

fetch_order() {
  local order_id="$1"
  curl -fsS "${ADMIN_URL}/api/makeline/order/${order_id}"
}

assert_order_visible() {
  local order_id="$1" customer_id="$2" order_customer order_json
  order_json="$(fetch_order "${order_id}" || true)"
  [[ -n "${order_json}" ]] || fail "DocumentDB-backed order ${order_id} was not fetchable"
  order_customer="$(printf '%s' "${order_json}" | json_eval 'import json,sys; print(json.load(sys.stdin).get("customerId", ""))')"
  [[ "${order_customer}" == "${customer_id}" ]] || fail "DocumentDB-backed order ${order_id} did not contain customerId ${customer_id}"
}

assert_service_restart_persistence() {
  local order_id="$1" customer_id="$2"
  compose restart makeline-service >/dev/null
  wait_for_container_health makeline-service
  wait_for_http "makeline after restart" "${ADMIN_URL}/api/makeline/order/fetch"
  assert_order_visible "${order_id}" "${customer_id}"
  record "Makeline-service restart preserved access to current-run order ${order_id}."
}

classify_stop_start_expected_failure() {
  local order_id="$1" customer_id="$2" documentdb_id deadline status logs
  documentdb_id="$(container_id documentdb)"
  [[ -n "${documentdb_id}" ]] || fail "missing documentdb container before stop/start classification"

  compose stop >/dev/null
  compose start >/dev/null || true

  deadline=$((SECONDS + 180))
  status=""
  while (( SECONDS < deadline )); do
    status="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' "${documentdb_id}" 2>/dev/null || true)"
    [[ "${status}" == "unhealthy" || "${status}" == "exited" || "${status}" == "restarting" ]] && break
    sleep 5
  done

  logs="$(docker logs "${documentdb_id}" 2>&1 || true)"
  if ! grep -Eiq 'duplicate key|duplicate _id|01-users\.js|MongoBulkWriteError' <<<"${logs}"; then
    fail "DocumentDB stop/start did not produce the approved duplicate seed-data failure signature"
  fi

  record "Compose stop/start with the existing DocumentDB container produced the approved EXPECTED FAILURE signature for duplicate upstream seed data after order ${order_id} for ${customer_id}; durable persistence is not claimed."
  compose down --remove-orphans -v >/dev/null
}

classify_container_recreation() {
  local order_id="$1" customer_id="$2" documentdb_id volume_names missing_volume=0
  documentdb_id="$(container_id documentdb)"
  [[ -n "${documentdb_id}" ]] || fail "missing documentdb container before recreation classification"
  mapfile -t volume_names < <(docker inspect -f '{{range .Mounts}}{{if eq .Type "volume"}}{{.Name}}{{"\n"}}{{end}}{{end}}' "${documentdb_id}" | sed "/^$/d")
  [[ "${#volume_names[@]}" -gt 0 ]] || fail "documentdb did not expose an anonymous volume to classify"

  compose stop makeline-service documentdb >/dev/null
  compose rm -sfv documentdb >/dev/null

  for volume_name in "${volume_names[@]}"; do
    if ! docker volume inspect "${volume_name}" >/dev/null 2>&1; then
      missing_volume=1
    fi
  done
  [[ "${missing_volume}" == "1" ]] || fail "documentdb anonymous volume survived container removal; update persistence assessment before passing"

  record "DocumentDB anonymous volume was removed with the container after order ${order_id} for ${customer_id}; durable persistence across container recreation is not claimed."
  compose down --remove-orphans -v >/dev/null
}
run_current_order_flow() {
  local run_id customer_id status order_id
  run_id="$(date -u +%Y%m%d%H%M%S)-$$"
  customer_id="aml08-${run_id}"
  pause_virtual_workload
  status="$(submit_unique_order "${customer_id}" || true)"
  [[ "${status}" == "201" ]] || fail "order-service returned HTTP ${status:-curl-failed} for current-run order"
  order_id="$(wait_for_order "${customer_id}")"
  assert_order_visible "${order_id}" "${customer_id}"
  record "Submitted unique current-run order for ${customer_id}; makeline assigned orderId ${order_id} and stored it in DocumentDB."
  unpause_virtual_workload
  printf '%s:%s\n' "${order_id}" "${customer_id}"
}

fresh_repeat_smoke() {
  local run_id customer_id status order_id
  run_id="repeat-$(date -u +%Y%m%d%H%M%S)-$$"
  customer_id="aml08-${run_id}"
  compose down --remove-orphans >/dev/null
  compose up -d --build >/dev/null
  assert_compose_identity
  wait_for_stack
  pause_virtual_workload
  status="$(submit_unique_order "${customer_id}" || true)"
  [[ "${status}" == "201" ]] || fail "fresh repeat order-service returned HTTP ${status:-curl-failed}"
  order_id="$(wait_for_order "${customer_id}")"
  assert_order_visible "${order_id}" "${customer_id}"
  record "Fresh repeat run accepted and stored order ${order_id} for ${customer_id}."
  unpause_virtual_workload
}

assert_no_tracked_runtime_artifacts() {
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    local top rel
    top="$(git rev-parse --show-toplevel)"
    rel="${BASELINE_DIR#${top}/}"
    if git -C "${top}" ls-files -- "${rel}/.local" | grep -q .; then
      fail "runtime validation artifacts under .local are tracked"
    fi
  fi
  record "Runtime validation artifacts are ignored and untracked."
}

main() {
  require_command docker
  require_command curl
  require_command python3
  require_command sha256sum
  mkdir -p "${REPORT_DIR}"
  printf '# AKS Store Demo Compose Validation Report\n\nGenerated: %s UTC\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"${REPORT_FILE}"

  if [[ "${1:-}" == "--identity-only" ]]; then
    assert_compose_identity
    exit 0
  fi

  if [[ "${1:-}" == "--recovery-order-only" ]]; then
    assert_compose_identity
    wait_for_stack
    assert_rabbitmq_queue
    IFS=: read -r recovery_order_id recovery_customer_id < <(run_current_order_flow)
    record "RabbitMQ restoration recovery accepted and stored fresh order ${recovery_order_id} for ${recovery_customer_id} through makeline/DocumentDB."
    exit 0
  fi

  check_source_snapshot
  check_effective_config
  assert_no_tracked_runtime_artifacts
  assert_clean_project

  log "building and starting Compose project ${PROJECT_NAME}"
  compose up -d --build
  assert_compose_identity
  wait_for_stack
  assert_products
  assert_rabbitmq_queue

  IFS=: read -r order_id customer_id < <(run_current_order_flow)
  assert_service_restart_persistence "${order_id}" "${customer_id}"
  classify_stop_start_expected_failure "${order_id}" "${customer_id}"
  fresh_repeat_smoke

  compose down --remove-orphans >/dev/null
  record "Normal cleanup completed with docker compose down --remove-orphans."
  log "validation completed successfully; evidence: ${REPORT_FILE}"
}

main "$@"
