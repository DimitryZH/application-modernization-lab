#!/usr/bin/env bash
set -uo pipefail

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

check_command() {
  local name="$1"
  local version_command="$2"

  if command -v "$name" >/dev/null 2>&1; then
    local version
    version="$(eval "$version_command" 2>/dev/null | head -n 1 || true)"
    if [ -n "$version" ]; then
      pass "$name is installed: $version"
    else
      pass "$name is installed."
    fi
  else
    fail "$name is not installed or is not on PATH."
  fi
}

printf 'Checking DevBox prerequisites\n\n'

if [ -r /etc/os-release ]; then
  OS_PRETTY_NAME="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-unknown}")"
  pass "OS detected: $OS_PRETTY_NAME"
else
  warn "Could not read /etc/os-release."
fi

CPU_COUNT="$(nproc 2>/dev/null || printf '0')"
if [ "$CPU_COUNT" -ge 2 ] 2>/dev/null; then
  pass "CPU count is sufficient: $CPU_COUNT"
else
  warn "CPU count is low: $CPU_COUNT"
fi

MEMORY_GB="$(awk '/MemTotal/ { printf "%.0f", $2 / 1024 / 1024 }' /proc/meminfo 2>/dev/null || printf '0')"
if [ "$MEMORY_GB" -ge 6 ] 2>/dev/null; then
  pass "Memory is sufficient: ${MEMORY_GB} GB"
else
  warn "Memory may be low for Aspire and Docker workloads: ${MEMORY_GB} GB"
fi

FREE_DISK_GB="$(df -BG / 2>/dev/null | awk 'NR == 2 { gsub("G", "", $4); print $4 }')"
if [ "${FREE_DISK_GB:-0}" -ge 20 ] 2>/dev/null; then
  pass "Free disk space is sufficient: ${FREE_DISK_GB} GB"
else
  warn "Free disk space may be low: ${FREE_DISK_GB:-unknown} GB"
fi

CURRENT_USER="$(id -un 2>/dev/null || whoami 2>/dev/null || printf 'unknown')"
if [ "$CURRENT_USER" = "root" ]; then
  warn "Current user is root. Routine validation should use a non-root user."
else
  pass "Current user is non-root: $CURRENT_USER"
fi

check_command "git" "git --version"
check_command "docker" "docker --version"

if command -v docker >/dev/null 2>&1; then
  if docker compose version >/dev/null 2>&1; then
    pass "Docker Compose plugin is available: $(docker compose version | head -n 1)"
  else
    fail "Docker Compose plugin is not available through 'docker compose'."
  fi

  if docker info >/dev/null 2>&1; then
    pass "Current user can access Docker."
  else
    fail "Current user cannot access Docker. Add the user to the docker group or use the approved local access model."
  fi
fi

check_command "dotnet" "dotnet --version"
check_command "curl" "curl --version"
check_command "jq" "jq --version"
check_command "bash" "bash --version"
check_command "unzip" "unzip -v"

if command -v chromium >/dev/null 2>&1; then
  pass "Optional Chromium is installed: $(chromium --version | head -n 1)"
elif command -v chromium-browser >/dev/null 2>&1; then
  pass "Optional Chromium is installed: $(chromium-browser --version | head -n 1)"
elif command -v google-chrome >/dev/null 2>&1; then
  pass "Optional Chrome is installed: $(google-chrome --version | head -n 1)"
else
  warn "Optional Chrome or Chromium is not installed."
fi

printf '\nSummary: PASS=%s WARN=%s FAIL=%s\n' "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT"

if [ "$FAIL_COUNT" -gt 0 ]; then
  exit 1
fi
