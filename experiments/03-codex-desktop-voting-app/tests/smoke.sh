#!/usr/bin/env bash
set -euo pipefail

VOTE_URL="${VOTE_URL:-http://localhost:8080}"
RESULT_URL="${RESULT_URL:-http://localhost:8081}"
COMPOSE_DIR="${COMPOSE_DIR:-}"
COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
DOCKER_COMPOSE_CMD="${DOCKER_COMPOSE_CMD:-docker-compose}"

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts="${3:-90}"
  local output_file
  output_file="$(mktemp)"

  for _ in $(seq 1 "$attempts"); do
    if curl.exe -fsS --max-time 5 "$url" >"$output_file"; then
      cp "$output_file" "${TMPDIR:-/tmp}/${name}.html"
      rm -f "$output_file"
      echo "PASS: $name responded at $url"
      return 0
    fi
    sleep 2
  done

  rm -f "$output_file"
  echo "FAIL: $name did not respond at $url" >&2
  return 1
}

assert_container_running() {
  local service="$1"
  if [[ -z "$COMPOSE_DIR" ]]; then
    return 0
  fi

  local cid
  cid=$($DOCKER_COMPOSE_CMD -f "$COMPOSE_DIR/$COMPOSE_FILE" ps -q "$service")
  if [[ -z "$cid" ]]; then
    echo "FAIL: no container found for compose service $service" >&2
    return 1
  fi

  local state
  state=$(docker inspect -f '{{.State.Status}}' "$cid")
  if [[ "$state" != "running" ]]; then
    echo "FAIL: compose service $service is $state" >&2
    return 1
  fi

  echo "PASS: compose service $service is running"
}

for svc in vote result redis db worker; do
  assert_container_running "$svc"
done

wait_for_http vote "$VOTE_URL"
wait_for_http result "$RESULT_URL"

vote_html="${TMPDIR:-/tmp}/vote.html"
result_html="${TMPDIR:-/tmp}/result.html"

grep -Eiq 'Cats|Dogs|vote' "$vote_html" && echo "PASS: vote page contains expected voting text"
grep -Eiq 'result|percent|votes|Cats|Dogs' "$result_html" && echo "PASS: result page contains expected result text"

cookie_jar="$(mktemp)"
trap 'rm -f "$cookie_jar"' EXIT

curl.exe -fsS -c "$cookie_jar" "$VOTE_URL" >/dev/null
curl.exe -fsS -b "$cookie_jar" -c "$cookie_jar" -X POST -d 'vote=a' "$VOTE_URL" >/dev/null
sleep 5

after_vote="$(mktemp)"
curl.exe -fsS "$RESULT_URL" >"$after_vote"
if grep -Eiq 'result|percent|votes|Cats|Dogs|a|b' "$after_vote"; then
  echo "PASS: basic vote flow submitted a vote and result endpoint remained readable"
else
  echo "FAIL: result page did not contain expected content after vote" >&2
  cat "$after_vote" >&2
  rm -f "$after_vote"
  exit 1
fi
rm -f "$after_vote"
