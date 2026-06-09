#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${PROJECT_ID:-ai-agent-host-497515}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
VM_NAME="${VM_NAME:-compose-aspire-devbox-01}"
MACHINE_TYPE="${MACHINE_TYPE:-e2-standard-2}"
BOOT_DISK_SIZE_GB="${BOOT_DISK_SIZE_GB:-80}"
BOOT_DISK_TYPE="${BOOT_DISK_TYPE:-pd-balanced}"
IMAGE_FAMILY="${IMAGE_FAMILY:-ubuntu-2404-lts-amd64}"
IMAGE_PROJECT="${IMAGE_PROJECT:-ubuntu-os-cloud}"
NETWORK="${NETWORK:-default}"
SUBNET="${SUBNET:-default}"
NETWORK_TAGS="${NETWORK_TAGS:-devbox-iap-ssh}"
CREATE_EXTERNAL_IP="${CREATE_EXTERNAL_IP:-true}"
IAP_ALLOW_FIREWALL_RULE="${IAP_ALLOW_FIREWALL_RULE:-devbox-allow-iap-ssh}"
PUBLIC_SSH_DENY_FIREWALL_RULE="${PUBLIC_SSH_DENY_FIREWALL_RULE:-devbox-deny-public-ssh}"
ENABLE_OS_LOGIN="${ENABLE_OS_LOGIN:-true}"
NO_SERVICE_ACCOUNT="${NO_SERVICE_ACCOUNT:-true}"
LABELS="${LABELS:-experiment=exp04,purpose=compose-aspire-devbox}"

printf 'Google Cloud DevBox configuration\n'
printf 'Project:           %s\n' "$PROJECT_ID"
printf 'Region:            %s\n' "$REGION"
printf 'Zone:              %s\n' "$ZONE"
printf 'VM name:           %s\n' "$VM_NAME"
printf 'Machine type:      %s\n' "$MACHINE_TYPE"
printf 'Boot disk:         %s GB %s\n' "$BOOT_DISK_SIZE_GB" "$BOOT_DISK_TYPE"
printf 'Image:             %s/%s\n' "$IMAGE_PROJECT" "$IMAGE_FAMILY"
printf 'Network/subnet:    %s/%s\n' "$NETWORK" "$SUBNET"
printf 'Network tags:      %s\n' "$NETWORK_TAGS"
printf 'External IP:       %s\n' "$CREATE_EXTERNAL_IP"
printf 'IAP allow rule:    %s\n' "$IAP_ALLOW_FIREWALL_RULE"
printf 'Public SSH deny:   %s\n' "$PUBLIC_SSH_DENY_FIREWALL_RULE"
printf 'OS Login metadata: %s\n' "$ENABLE_OS_LOGIN"
printf 'Service account:   %s\n' "$([ "$NO_SERVICE_ACCOUNT" = "true" ] && printf 'none' || printf 'default')"
printf 'Labels:            %s\n' "$LABELS"
printf '\n'

if ! command -v gcloud >/dev/null 2>&1; then
  printf 'ERROR: gcloud is not installed or is not on PATH.\n' >&2
  exit 1
fi

if gcloud compute instances describe "$VM_NAME" --project "$PROJECT_ID" --zone "$ZONE" >/dev/null 2>&1; then
  printf 'ERROR: VM already exists: %s in %s/%s\n' "$VM_NAME" "$PROJECT_ID" "$ZONE" >&2
  printf 'This script will not modify or replace an existing VM.\n' >&2
  exit 1
fi

for firewall_rule in "$IAP_ALLOW_FIREWALL_RULE" "$PUBLIC_SSH_DENY_FIREWALL_RULE"; do
  if ! gcloud compute firewall-rules describe "$firewall_rule" --project "$PROJECT_ID" >/dev/null 2>&1; then
    printf 'ERROR: Required hardened SSH firewall rule does not exist: %s\n' "$firewall_rule" >&2
    printf 'Create and review both tagged SSH rules before creating the DevBox.\n' >&2
    exit 1
  fi
done

printf 'This will create a new development VM and may incur Google Cloud charges.\n'
printf 'No destructive action will be performed by this script.\n'
read -r -p "Type 'create' to continue: " CONFIRMATION

if [ "$CONFIRMATION" != "create" ]; then
  printf 'Canceled. No resources were created.\n'
  exit 0
fi

CREATE_ARGS=(
  compute instances create "$VM_NAME"
  "--project=$PROJECT_ID"
  "--zone=$ZONE"
  "--machine-type=$MACHINE_TYPE"
  "--image-family=$IMAGE_FAMILY"
  "--image-project=$IMAGE_PROJECT"
  "--boot-disk-size=${BOOT_DISK_SIZE_GB}GB"
  "--boot-disk-type=$BOOT_DISK_TYPE"
  "--network=$NETWORK"
  "--subnet=$SUBNET"
  "--metadata=enable-oslogin=$ENABLE_OS_LOGIN"
  "--labels=$LABELS"
  "--maintenance-policy=MIGRATE"
  "--provisioning-model=STANDARD"
  "--shielded-secure-boot"
  "--shielded-vtpm"
  "--shielded-integrity-monitoring"
)

if [ -n "$NETWORK_TAGS" ]; then
  CREATE_ARGS+=("--tags=$NETWORK_TAGS")
fi

if [ "$CREATE_EXTERNAL_IP" != "true" ]; then
  CREATE_ARGS+=("--no-address")
fi

if [ "$NO_SERVICE_ACCOUNT" = "true" ]; then
  CREATE_ARGS+=("--no-service-account" "--no-scopes")
fi

gcloud "${CREATE_ARGS[@]}"

printf '\nDevBox creation requested successfully.\n'
printf 'Next step: bash ./scripts/connect-devbox.sh\n'
