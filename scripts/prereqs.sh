#!/usr/bin/env bash
# prereqs.sh — check that required tools are installed
set -euo pipefail

required_ok=1

check() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "MISSING: $cmd (install: $2)"
    required_ok=0
  else
    local ver
    ver=$("$cmd" --version 2>/dev/null | head -1)
    echo "OK:      $cmd — $ver"
  fi
}

echo "Checking prerequisites..."
echo ""

check aws      "https://aws.amazon.com/cli/"
check terraform "https://developer.hashicorp.com/terraform/install"
check gh       "https://cli.github.com/"
check jq       "brew install jq  |  apt install jq"
check openssl  "brew install openssl  |  apt install openssl"
check bash     "macOS: brew install bash"

echo ""
if [ "$required_ok" -eq 0 ]; then
  echo "One or more prerequisites are missing. Install them and re-run."
  exit 1
fi
echo "All prerequisites met."
