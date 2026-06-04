#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPERIMENT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
REPORTS_DIR="${REPORTS_DIR:-$EXPERIMENT_DIR/reports}"
VALIDATION_LOG_DIR="${VALIDATION_LOG_DIR:-}"
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
EVIDENCE_FILE="$REPORTS_DIR/devbox-evidence-$TIMESTAMP.txt"

mkdir -p "$REPORTS_DIR"

section() {
  printf '\n## %s\n\n' "$1"
}

run_or_note() {
  local executable="$1"
  shift

  if command -v "$executable" >/dev/null 2>&1; then
    "$executable" "$@" 2>&1 || true
  else
    printf '%s is not installed or is not on PATH.\n' "$executable"
  fi
}

{
  printf '# Google Cloud DevBox Evidence\n\n'
  printf 'Collected at: %s\n' "$TIMESTAMP"
  printf 'Hostname: %s\n' "$(hostname 2>/dev/null || printf 'unknown')"
  printf 'User: %s\n' "$(id -un 2>/dev/null || whoami 2>/dev/null || printf 'unknown')"

  section "OS Information"
  if [ -r /etc/os-release ]; then
    cat /etc/os-release
  else
    printf '/etc/os-release is not readable.\n'
  fi
  run_or_note uname -a

  section "Compute Resources"
  run_or_note nproc
  run_or_note free -h
  run_or_note df -h

  section "Tool Versions"
  run_or_note git --version
  run_or_note docker --version
  if command -v docker >/dev/null 2>&1; then
    docker compose version 2>&1 || true
  fi
  run_or_note dotnet --info
  run_or_note curl --version
  run_or_note jq --version
  run_or_note bash --version
  run_or_note unzip -v

  section "Docker Information"
  if command -v docker >/dev/null 2>&1; then
    docker info 2>&1 || true
    printf '\n### Docker Disk Usage\n\n'
    docker system df 2>&1 || true
    printf '\n### Docker Containers\n\n'
    docker ps -a 2>&1 || true
  else
    printf 'Docker is not installed.\n'
  fi

  section "Repository Status"
  if git rev-parse --show-toplevel >/dev/null 2>&1; then
    printf 'Repository root: %s\n\n' "$(git rev-parse --show-toplevel 2>/dev/null || true)"
    git rev-parse HEAD 2>&1 || true
    git status --short 2>&1 || true
  else
    printf 'Current directory is not inside a Git repository.\n'
  fi

  section "Validation Logs"
  if [ -n "$VALIDATION_LOG_DIR" ] && [ -d "$VALIDATION_LOG_DIR" ]; then
    find "$VALIDATION_LOG_DIR" -maxdepth 2 -type f \( -name '*.log' -o -name '*.txt' \) | sort | while IFS= read -r log_file; do
      printf '\n### %s\n\n' "$log_file"
      tail -n 200 "$log_file" 2>&1 || true
    done
  else
    printf 'No validation log directory was configured. Set VALIDATION_LOG_DIR to include log tails.\n'
  fi
} > "$EVIDENCE_FILE"

printf 'Evidence saved to: %s\n' "$EVIDENCE_FILE"
