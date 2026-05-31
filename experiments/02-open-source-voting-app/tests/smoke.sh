#!/usr/bin/env bash
set -euo pipefail

VOTE_URL="${VOTE_URL:-http://localhost:8080}"
RESULT_URL="${RESULT_URL:-http://localhost:8081}"
COMPOSE_DIR="${COMPOSE_DIR:-}"

wait_for_http() {
  local name="$1"
  local url="$2"
  local attempts="${3:-60}"
  for i in $(seq 1 "$attempts"); do
    if curl -fsS --max-time 3 "$url" >/tmp/${name}.html; then
      echo "PASS: $name responded at $url"
      return 0
    fi
    sleep 2
  done
  echo "FAIL: $name did not respond at $url" >&2
  return 1
}

assert_container_running() {
  local service="$1"
  if [[ -z "$COMPOSE_DIR" ]]; then
    return 0
  fi
  local cid
  cid=$(docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps -q "$service")
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

grep -Eiq 'cats|dogs|vote' /tmp/vote.html && echo "PASS: vote page contains expected voting text"
grep -Eiq 'cats|dogs|result|percent|votes' /tmp/result.html && echo "PASS: result page contains expected result text"

COOKIE_JAR=$(mktemp)
trap 'rm -f "$COOKIE_JAR"' EXIT
curl -fsS -c "$COOKIE_JAR" "$VOTE_URL" >/tmp/vote-before-post.html
curl -fsS -b "$COOKIE_JAR" -c "$COOKIE_JAR" -X POST -d 'vote=a' "$VOTE_URL" >/tmp/vote-post.html
sleep 5
curl -fsS "$RESULT_URL" >/tmp/result-after-vote.html
if grep -Eiq 'cats|dogs|a|b|percent|votes|result' /tmp/result-after-vote.html; then
  echo "PASS: basic vote flow submitted a vote and result endpoint remained readable"
else
  echo "FAIL: result page did not contain expected content after vote" >&2
  exit 1
fi
