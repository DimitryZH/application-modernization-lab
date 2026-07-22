#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${COMPOSE_PROJECT_NAME:-bank-of-anthos-compose}"
FRONTEND_URL="${FRONTEND_URL:-http://127.0.0.1:8080}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
COOKIE_JAR="${EXPERIMENT_DIR}/.local/validation/cookies.txt"
PYTHON_READY='import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=5).read()'
EXPECTED_SERVICES=(accounts-db ledger-db userservice contacts balancereader transactionhistory ledgerwriter frontend)

cd "${EXPERIMENT_DIR}"

log() {
  printf '[validate-compose] %s\n' "$*"
}

fail() {
  printf '[validate-compose] ERROR: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "missing required command: $1"
}

compose() {
  docker compose -p "${PROJECT_NAME}" "$@"
}

container_id() {
  compose ps -q "$1"
}

exec_service() {
  local service="$1"
  shift
  compose exec -T "$service" "$@"
}

sql_scalar() {
  local service="$1"
  local user="$2"
  local database="$3"
  local sql="$4"
  exec_service "$service" env PGPASSWORD="$5" psql -X -A -t -v ON_ERROR_STOP=1 -U "$user" -d "$database" -c "$sql" | tr -d '[:space:]'
}

wait_for_http_from_frontend() {
  local label="$1"
  local url="$2"
  local deadline=$((SECONDS + 240))
  until timeout 10s docker compose -p "${PROJECT_NAME}" exec -T frontend python -c "${PYTHON_READY}" "$url" >/dev/null 2>&1; do
    if (( SECONDS >= deadline )); then
      fail "${label} did not become ready at ${url}"
    fi
    sleep 5
  done
  log "${label} ready"
}

wait_for_frontend_loopback() {
  local deadline=$((SECONDS + 240))
  until curl -fsS "${FRONTEND_URL}/ready" >/dev/null; do
    if (( SECONDS >= deadline )); then
      fail "frontend did not become reachable at ${FRONTEND_URL}/ready"
    fi
    sleep 5
  done
  log "frontend loopback endpoint ready"
}

assert_compose_identity() {
  local actual_services
  actual_services="$(docker ps --filter "label=com.docker.compose.project=${PROJECT_NAME}" --format '{{.Label "com.docker.compose.service"}}' | sort)"
  local expected_services
  expected_services="$(printf '%s\n' "${EXPECTED_SERVICES[@]}" | sort)"
  [[ "${actual_services}" == "${expected_services}" ]] || fail "unexpected Compose services for project ${PROJECT_NAME}: ${actual_services//$'\n'/, }"

  for service in "${EXPECTED_SERVICES[@]}"; do
    local cid
    cid="$(container_id "$service")"
    [[ -n "${cid}" ]] || fail "missing Compose container for ${service}"
    local project_label service_label
    project_label="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.project" }}' "$cid")"
    service_label="$(docker inspect -f '{{ index .Config.Labels "com.docker.compose.service" }}' "$cid")"
    [[ "${project_label}" == "${PROJECT_NAME}" && "${service_label}" == "${service}" ]] || fail "container ${cid} is not the expected ${PROJECT_NAME}/${service} resource"
  done
  log "Compose identity labels match expected service set"
}

assert_no_tracked_secrets() {
  git rev-parse --show-toplevel >/dev/null 2>&1 || return 0
  if git ls-files -- "${EXPERIMENT_DIR#$(git rev-parse --show-toplevel)/}/.local" | grep -q .; then
    fail "generated .local secret material is tracked by git"
  fi
  log "generated JWT material is local and untracked"
}

validate_ready_stack() {
  assert_compose_identity
  wait_for_http_from_frontend "userservice" "http://userservice:8080/ready"
  wait_for_http_from_frontend "contacts" "http://contacts:8080/ready"
  wait_for_http_from_frontend "balancereader" "http://balancereader:8080/ready"
  wait_for_http_from_frontend "transactionhistory" "http://transactionhistory:8080/ready"
  wait_for_http_from_frontend "ledgerwriter" "http://ledgerwriter:8080/ready"
  wait_for_frontend_loopback
}

login_and_fetch_home() {
  mkdir -p "$(dirname "${COOKIE_JAR}")"
  rm -f "${COOKIE_JAR}"
  curl -fsS -c "${COOKIE_JAR}" -b "${COOKIE_JAR}" \
    -X POST "${FRONTEND_URL}/login" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data 'username=testuser&password=bankofanthos' \
    -o /tmp/bank-of-anthos-login.html
  curl -fsS -b "${COOKIE_JAR}" "${FRONTEND_URL}/home" -o /tmp/bank-of-anthos-home.html
  grep -Eq 'Test|User|Balance|Transactions|Deposit|Payment' /tmp/bank-of-anthos-home.html || fail "authenticated home page did not contain expected account content"
  log "frontend login and authenticated home page succeeded"
}

submit_deposit() {
  local uuid="$1"
  curl -fsS -b "${COOKIE_JAR}" -c "${COOKIE_JAR}" \
    -X POST "${FRONTEND_URL}/deposit" \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'account={"account_num": "9099791699", "routing_num": "808889588" }' \
    --data-urlencode 'amount=12.34' \
    --data-urlencode "uuid=${uuid}" \
    -o /tmp/bank-of-anthos-deposit-redirect.html
  curl -fsS -b "${COOKIE_JAR}" "${FRONTEND_URL}/home" -o /tmp/bank-of-anthos-after-deposit.html
  grep -Eq 'Deposit successful|Transactions|Balance' /tmp/bank-of-anthos-after-deposit.html || fail "post-deposit home page did not show authenticated transaction content"
}

wait_for_transaction_count() {
  local previous_count="$1"
  local deadline=$((SECONDS + 90))
  local count
  until count="$(sql_scalar ledger-db admin postgresdb "SELECT COUNT(*) FROM TRANSACTIONS WHERE FROM_ACCT='9099791699' AND FROM_ROUTE='808889588' AND TO_ACCT='1011226111' AND TO_ROUTE='883745000' AND AMOUNT=1234;" password)" && (( count > previous_count )); do
    if (( SECONDS >= deadline )); then
      fail "deposit transaction was not persisted in ledger-db"
    fi
    sleep 3
  done
  log "deposit transaction persisted in ledger-db"
}

assert_database_state() {
  local users tx_count
  users="$(sql_scalar accounts-db accounts-admin accounts-db "SELECT COUNT(*) FROM users WHERE username IN ('testuser','alice','bob','eve');" accounts-pwd)"
  [[ "${users}" == "4" ]] || fail "expected four seeded demo users, found ${users}"
  tx_count="$(sql_scalar ledger-db admin postgresdb "SELECT COUNT(*) FROM TRANSACTIONS;" password)"
  [[ "${tx_count}" =~ ^[0-9]+$ && "${tx_count}" -gt 0 ]] || fail "ledger-db did not contain seeded transactions"
  log "database initialization present: users=${users}, transactions=${tx_count}"
}

assert_persistence_after_restart() {
  local before_count="$1"
  compose down --remove-orphans
  compose up -d
  validate_ready_stack
  local after_count
  after_count="$(sql_scalar ledger-db admin postgresdb "SELECT COUNT(*) FROM TRANSACTIONS WHERE FROM_ACCT='9099791699' AND FROM_ROUTE='808889588' AND TO_ACCT='1011226111' AND TO_ROUTE='883745000' AND AMOUNT=1234;" password)"
  [[ "${after_count}" == "${before_count}" ]] || fail "controlled restart did not preserve validation transaction count (${before_count} -> ${after_count})"
  log "controlled restart preserved ledger transaction evidence"
}

assert_negative_missing_dependency() {
  compose stop ledger-db >/dev/null
  if bash -c "cd '${EXPERIMENT_DIR}' && COMPOSE_PROJECT_NAME='${PROJECT_NAME}' FRONTEND_URL='${FRONTEND_URL}' '${SCRIPT_DIR}/validate-compose.sh' --identity-only" >/tmp/bank-of-anthos-negative.out 2>&1; then
    fail "identity-only validation unexpectedly passed while ledger-db was stopped"
  fi
  compose up -d ledger-db >/dev/null
  log "negative dependency check failed as expected with ledger-db stopped"
}

identity_only() {
  assert_compose_identity
  for service in "${EXPECTED_SERVICES[@]}"; do
    local state
    state="$(docker inspect -f '{{.State.Running}}' "$(container_id "$service")")"
    [[ "${state}" == "true" ]] || fail "required service ${service} is not running"
  done
}

main() {
  require_command docker
  require_command curl
  require_command openssl
  require_command timeout

  if [[ "${1:-}" == "--identity-only" ]]; then
    identity_only
    exit 0
  fi

  "${SCRIPT_DIR}/generate-jwt-keys.sh"
  assert_no_tracked_secrets

  log "starting Compose project ${PROJECT_NAME}"
  compose up -d
  validate_ready_stack
  assert_database_state
  login_and_fetch_home

  local before_matching uuid after_matching
  before_matching="$(sql_scalar ledger-db admin postgresdb "SELECT COUNT(*) FROM TRANSACTIONS WHERE FROM_ACCT='9099791699' AND FROM_ROUTE='808889588' AND TO_ACCT='1011226111' AND TO_ROUTE='883745000' AND AMOUNT=1234;" password)"
  uuid="validate-$(date -u +%Y%m%d%H%M%S)-$$"
  submit_deposit "${uuid}"
  wait_for_transaction_count "${before_matching}"
  after_matching="$(sql_scalar ledger-db admin postgresdb "SELECT COUNT(*) FROM TRANSACTIONS WHERE FROM_ACCT='9099791699' AND FROM_ROUTE='808889588' AND TO_ACCT='1011226111' AND TO_ROUTE='883745000' AND AMOUNT=1234;" password)"
  assert_persistence_after_restart "${after_matching}"
  login_and_fetch_home
  assert_negative_missing_dependency

  compose down --remove-orphans
  log "validation completed successfully; use 'docker compose down -v' to reset persisted database volumes"
}

main "$@"
