#!/usr/bin/env bash
set -uo pipefail

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"

REQUIRED_APIS=(
  "compute.googleapis.com"
  "serviceusage.googleapis.com"
  "cloudresourcemanager.googleapis.com"
)

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf 'PASS: %s\n' "$1"
}

warn() {
  WARN_COUNT=$((WARN_COUNT + 1))
  printf 'WARN: %s\n' "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf 'FAIL: %s\n' "$1"
}

print_summary() {
  printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"
}

printf 'Checking local Google Cloud CLI readiness for project: %s\n\n' "$PROJECT_ID"

if ! command -v gcloud >/dev/null 2>&1; then
  fail "gcloud is not installed or is not on PATH."
  print_summary
  exit 1
fi

GCLOUD_VERSION="$(gcloud version --format='value(Google Cloud SDK)' 2>/dev/null || true)"
if [ -n "$GCLOUD_VERSION" ]; then
  pass "gcloud is installed: $GCLOUD_VERSION"
else
  pass "gcloud is installed."
fi

ACTIVE_ACCOUNT="$(gcloud auth list --filter='status:ACTIVE' --format='value(account)' 2>/dev/null || true)"
if [ -n "$ACTIVE_ACCOUNT" ]; then
  pass "Active authenticated account detected: $ACTIVE_ACCOUNT"
else
  fail "No active authenticated gcloud account detected. Run: gcloud auth login"
fi

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [ -n "$ACTIVE_PROJECT" ] && [ "$ACTIVE_PROJECT" != "(unset)" ]; then
  pass "Active gcloud project is visible: $ACTIVE_PROJECT"
else
  warn "No active gcloud project is configured. Run: gcloud config set project $PROJECT_ID"
fi

if gcloud projects describe "$PROJECT_ID" --format='value(projectId)' >/dev/null 2>&1; then
  pass "Project is accessible: $PROJECT_ID"
else
  fail "Project is not accessible: $PROJECT_ID. Confirm account permissions and project ID."
fi

if [ "$ACTIVE_PROJECT" = "$PROJECT_ID" ]; then
  pass "Active project already matches expected project."
else
  warn "Active project does not match expected project. To switch explicitly, run: gcloud config set project $PROJECT_ID"
fi

ENABLED_APIS="$(gcloud services list --enabled --project "$PROJECT_ID" --format='value(config.name)' 2>/dev/null || true)"
if [ -z "$ENABLED_APIS" ]; then
  warn "Could not list enabled APIs. Confirm Service Usage API permissions, then check APIs manually."
else
  for api in "${REQUIRED_APIS[@]}"; do
    if printf '%s\n' "$ENABLED_APIS" | grep -Fxq "$api"; then
      pass "Required API is enabled: $api"
    else
      warn "Required API may be missing: $api. Enable manually with: gcloud services enable $api --project $PROJECT_ID"
    fi
  done
fi

printf '\nRequired APIs for this experiment:\n'
for api in "${REQUIRED_APIS[@]}"; do
  printf -- '- %s\n' "$api"
done

printf '\nThis script does not enable APIs or create resources.\n'
print_summary

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
