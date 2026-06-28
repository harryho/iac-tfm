#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == --env ]] && { ENV=$2; shift 2; }
SITE_KEY="${1:?Usage: $0 [--env <env>] <site-key>}"
ENV="${ENV:-dev}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/envs/$ENV"

[ -d "$TF_DIR" ] || { echo "env dir not found: $TF_DIR" >&2; exit 1; }

SITES_JSON=$(terraform -chdir="$TF_DIR" output -json sites)
DOMAIN=$(echo "$SITES_JSON" | jq -r --arg k "$SITE_KEY" '.[$k].custom_domain // empty')
HOST=$(echo "$SITES_JSON" | jq -r --arg k "$SITE_KEY" '.[$k].domain // empty')

[ -n "$DOMAIN" ] || { echo "site '$SITE_KEY' not found in $ENV output" >&2; exit 1; }

check() {
  local name="$1" url="$2" expect="$3"
  local code
  code=$(curl -sS -o /dev/null -w "%{http_code}" "$url" || true)
  [[ "$code" =~ ^[0-9]{3}$ ]] || code="000"
  if [[ "$code" =~ ^($expect)$ ]]; then
    echo "OK $name ($code)"
  else
    echo "FAIL $name ($code)"
  fi
}

check "host"     "https://$HOST"     "200"
check "custom"   "https://$DOMAIN"   "200|301"
check "404"      "https://$HOST/nope-12345" "404"