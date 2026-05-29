#!/usr/bin/env bash
set -euo pipefail

API_URL="${API_URL:-http://localhost:8080}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:3000}"

echo "Checking API health at ${API_URL}/health"
curl -fsS "${API_URL}/health" | grep -q '"status":"ok"'

echo "Creating test todo"
curl -fsS -X POST "${API_URL}/todos" \
  -H "Content-Type: application/json" \
  -d '{"title":"codex migration smoke test"}' | grep -q 'codex migration smoke test'

echo "Reading todos"
curl -fsS "${API_URL}/todos" | grep -q 'codex migration smoke test'

echo "Checking frontend health at ${FRONTEND_URL}/health"
curl -fsS "${FRONTEND_URL}/health" | grep -q '"status":"ok"'

echo "Smoke tests passed"
