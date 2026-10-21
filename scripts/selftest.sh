#!/usr/bin/env bash
# Checks the toolbox is complete. Run by verify.ps1 / verify.sh on the host.
set -uo pipefail

ok=1

check() {
  local name=$1
  shift
  local out
  if out=$("$@" 2>&1 | head -n1) && [ -n "$out" ]; then
    printf '  %-10s %s\n' "$name" "$out"
  else
    printf '  %-10s MISSING\n' "$name"
    ok=0
  fi
}

echo "Toolbox self-test"
check git      git --version
check gitleaks gitleaks version
check bandit   bandit --version
check checkov  checkov --version

if [ "$ok" -eq 1 ]; then
  echo "READY"
else
  echo "NOT READY"
  exit 1
fi
