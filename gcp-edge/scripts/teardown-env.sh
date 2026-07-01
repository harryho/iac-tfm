#!/usr/bin/env bash
set -euo pipefail

# teardown-env.sh — safely destroy an environment
#
# Usage:
#   teardown-env.sh <env>
#
# Example:
#   teardown-env.sh stage
#
# Safety:
#   - Refuses to destroy prod
#   - Requires type-to-confirm

usage() {
  cat <<'EOF'
Usage: teardown-env.sh <env>

Refuses to destroy 'prod'.
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "Error: required command '$1' is not installed." >&2
    exit 1
  fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

ENV="${1:-}"
if [[ -z "$ENV" ]]; then
  usage
  exit 1
fi

if [[ "$ENV" == "prod" ]]; then
  echo "Error: teardown-env.sh refuses to destroy 'prod'." >&2
  exit 1
fi

for cmd in terraform jq gcloud grep sed; do
  require_cmd "$cmd"
done

ENV_DIR="$PROJECT_ROOT/envs/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: env directory '$ENV_DIR' not found." >&2
  exit 1
fi

echo "WARNING: This will DESTROY all resources for environment '${ENV}'."
echo "This includes: LB resources, managed certs, Firestore DB, GCS buckets, and objects."
echo
read -r -p "Type the environment name to confirm: " CONFIRM

if [[ "$CONFIRM" != "$ENV" ]]; then
  echo "Aborted: confirmation did not match '${ENV}'."
  exit 1
fi

cd "$ENV_DIR"

SITES_JSON="$(terraform output -json sites 2>/dev/null || echo '{}')"
BUCKETS="$(echo "$SITES_JSON" | jq -r 'to_entries[]?.value.bucket_name // empty')"

if [[ -n "$BUCKETS" ]]; then
  echo
  echo "Emptying site buckets..."
  while IFS= read -r bucket; do
    [[ -z "$bucket" ]] && continue
    echo " - gs://${bucket}"
    gcloud storage rm -r "gs://${bucket}/**" --quiet >/dev/null 2>&1 || true
  done <<< "$BUCKETS"
fi

echo
echo "Running terraform destroy..."
terraform destroy

STATE_BUCKET="$(grep -E 'bucket\s*=\s*"' main.tf | head -1 | sed 's/.*= *"//' | sed 's/"$//')"
STATE_PREFIX="$(grep -E 'prefix\s*=\s*"' main.tf | head -1 | sed 's/.*= *"//' | sed 's/"$//')"

if [[ -n "$STATE_BUCKET" && -n "$STATE_PREFIX" ]]; then
  echo
  echo "Removing state objects: gs://${STATE_BUCKET}/${STATE_PREFIX}/**"
  gcloud storage rm -r "gs://${STATE_BUCKET}/${STATE_PREFIX}/**" --quiet >/dev/null 2>&1 || true
fi

echo
echo "=== Manual cleanup steps ==="
echo "1) Remove DNS records for environment '${ENV}' at your DNS provider."
echo "2) Optionally remove local env dir:    rm -rf ${ENV_DIR}"
echo "3) Optionally remove local content dir: rm -rf ${PROJECT_ROOT}/content/${ENV}"
echo
echo "Teardown complete."