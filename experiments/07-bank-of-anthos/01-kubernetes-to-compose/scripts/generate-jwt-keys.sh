#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
experiment_dir="$(cd "${script_dir}/.." && pwd)"
jwt_dir="${experiment_dir}/.local/jwt"
private_key="${jwt_dir}/jwtRS256.key"
public_key="${jwt_dir}/jwtRS256.key.pub"

mkdir -p "${jwt_dir}"
chmod 700 "${experiment_dir}/.local" "${jwt_dir}"

if [[ -f "${private_key}" && -f "${public_key}" ]]; then
  echo "JWT key pair already exists under .local/jwt"
  exit 0
fi

umask 077
openssl genrsa -out "${private_key}" 4096 >/dev/null 2>&1
openssl rsa -in "${private_key}" -pubout -out "${public_key}" >/dev/null 2>&1
chmod 600 "${private_key}" "${public_key}"

echo "Generated local JWT key pair under .local/jwt"
