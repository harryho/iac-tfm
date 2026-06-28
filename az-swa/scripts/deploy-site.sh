#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == --env ]] && { ENV=$2; shift 2; }
SITE_KEY="${1:?Usage: $0 [--env <env>] <site-key>}"
ENV="${ENV:-dev}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TF_DIR="$REPO_ROOT/envs/$ENV"
CONTENT_DIR="$REPO_ROOT/content/$ENV/$SITE_KEY/dist"

[ -d "$TF_DIR" ] || { echo "env dir not found: $TF_DIR" >&2; exit 1; }
[ -d "$CONTENT_DIR" ] || { echo "content dir not found: $CONTENT_DIR" >&2; exit 1; }

SITES_JSON=$(terraform -chdir="$TF_DIR" output -json sites)
DOMAIN=$(echo "$SITES_JSON" | jq -r --arg k "$SITE_KEY" '.[$k].custom_domain // empty')
SWA_NAME=$(echo "$SITES_JSON" | jq -r --arg k "$SITE_KEY" '.[$k].static_site_name // empty')

if [ -z "$SWA_NAME" ]; then
  echo "site '$SITE_KEY' not found in $ENV output" >&2
  exit 1
fi

RG_NAME="$(terraform -chdir="$TF_DIR" output -raw resource_group_name 2>/dev/null || echo "${REPO_ROOT##*/}-${ENV}-rg")"
TOKEN=$(az staticwebapp secrets list --name "$SWA_NAME" --resource-group "$RG_NAME" --query properties.apiKey -o tsv)

command -v swa >/dev/null || npm install -g @azure/static-web-apps-cli
swa deploy "$CONTENT_DIR" --deployment-token "$TOKEN" --env production

echo "Deployed: https://${DOMAIN}"