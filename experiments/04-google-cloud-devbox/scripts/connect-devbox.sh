#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-compose-aspire-devbox-01}"
TUNNEL_THROUGH_IAP="${TUNNEL_THROUGH_IAP:-false}"

if ! command -v gcloud >/dev/null 2>&1; then
  printf 'ERROR: gcloud is not installed or is not on PATH.\n' >&2
  exit 1
fi

SSH_ARGS=(
  compute ssh "$VM_NAME"
  "--project=$PROJECT_ID"
  "--zone=$ZONE"
)

if [ "$TUNNEL_THROUGH_IAP" = "true" ]; then
  SSH_ARGS+=("--tunnel-through-iap")
fi

if [ "$#" -gt 0 ]; then
  SSH_ARGS+=("--" "$@")
fi

exec gcloud "${SSH_ARGS[@]}"
