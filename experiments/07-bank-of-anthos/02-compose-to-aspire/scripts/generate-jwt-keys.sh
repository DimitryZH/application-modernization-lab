#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
JWT_DIR="${EXPERIMENT_DIR}/.local/jwt"
PRIVATE_KEY="${JWT_DIR}/jwtRS256.key"
PUBLIC_KEY="${JWT_DIR}/jwtRS256.key.pub"

mkdir -p "${JWT_DIR}"

if [[ ! -s "${PRIVATE_KEY}" ]]; then
  openssl genrsa -out "${PRIVATE_KEY}" 2048 >/dev/null 2>&1
  chmod 600 "${PRIVATE_KEY}"
fi

if [[ ! -s "${PUBLIC_KEY}" || "${PRIVATE_KEY}" -nt "${PUBLIC_KEY}" ]]; then
  openssl rsa -in "${PRIVATE_KEY}" -pubout -out "${PUBLIC_KEY}" >/dev/null 2>&1
  chmod 644 "${PUBLIC_KEY}"
fi

printf 'JWT keys ready under %s\n' "${JWT_DIR}"
