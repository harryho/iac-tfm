#!/usr/bin/env bash
set -euo pipefail

# deploy-site.sh — sync content to GCS and invalidate Cloud CDN cache
#
# Usage:
#   deploy-site.sh [--env <env>] [--url-map <url-map>] [--content-dir <dir>] [--no-invalidate] <site-key>
#
# Examples:
#   deploy-site.sh --env prod www_example_com
#   deploy-site.sh --env stage --url-map gcp-edge-stage-url-map stage_example_com

usage() {
  cat <<'EOF'
Usage: deploy-site.sh [--env <env>] [--url-map <url-map>] [--content-dir <dir>] [--no-invalidate] <site-key>

Options:
  --env <env>           Environment directory under envs/ (default: prod)
  --url-map <name>      URL map to invalidate (default: <project_name>-<env>-url-map)
  --content-dir <dir>   Override content directory (default: content/<env>/<site-key>/dist)
  --no-invalidate       Skip cache invalidation
  -h, --help            Show this help
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

ENV="prod"
URL_MAP=""
CONTENT_DIR=""
INVALIDATE="true"
SITE_KEY=""
PROJECT_NAME="gcp-edge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="${2:?Missing value for --env}"
      shift 2
      ;;
    --url-map)
      URL_MAP="${2:?Missing value for --url-map}"
      shift 2
      ;;
    --content-dir)
      CONTENT_DIR="${2:?Missing value for --content-dir}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:?Missing value for --project-name}"
      shift 2
      ;;
    --no-invalidate)
      INVALIDATE="false"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      if [[ -z "$SITE_KEY" ]]; then
        SITE_KEY="$1"
      else
        echo "Error: unexpected argument '$1'." >&2
        usage
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -z "$SITE_KEY" ]]; then
  echo "Error: site key is required." >&2
  usage
  exit 1
fi

for cmd in terraform jq; do
  require_cmd "$cmd"
done

if [[ "$INVALIDATE" == "true" ]]; then
  require_cmd gcloud
fi

ENV_DIR="$PROJECT_ROOT/envs/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: env directory '$ENV_DIR' not found." >&2
  exit 1
fi

if [[ -z "$CONTENT_DIR" ]]; then
  CONTENT_DIR="$PROJECT_ROOT/content/$ENV/$SITE_KEY/dist"
fi

if [[ ! -d "$CONTENT_DIR" ]]; then
  echo "Error: content directory '$CONTENT_DIR' not found." >&2
  exit 1
fi

cd "$ENV_DIR"

# Try to pick up project_name from the env's tfvars if it wasn't passed
if [[ -f terraform.tfvars ]]; then
  PN_FROM_TFVARS="$(grep -E '^project_name\s*=' terraform.tfvars | head -1 | sed 's/.*= *"//' | sed 's/"$//')"
  if [[ -n "$PN_FROM_TFVARS" ]]; then
    PROJECT_NAME="$PN_FROM_TFVARS"
  fi
fi

SITES_JSON="$(terraform output -json sites 2>/dev/null || true)"
if [[ -z "$SITES_JSON" || "$SITES_JSON" == "null" ]]; then
  echo "Error: terraform output 'sites' is unavailable. Run 'terraform apply' first." >&2
  exit 1
fi

DOMAIN="$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].domain // empty')"
BUCKET="$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].bucket_name // empty')"

if [[ -z "$DOMAIN" || -z "$BUCKET" ]]; then
  echo "Error: site '$SITE_KEY' not found in terraform output for env '$ENV'." >&2
  echo "Available sites:" >&2
  echo "$SITES_JSON" | jq -r 'keys[]' >&2
  exit 1
fi

PROJECT_ID="$(terraform output -raw project_id 2>/dev/null || true)"
if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: terraform output 'project_id' is unavailable." >&2
  exit 1
fi

echo "Deploying ${CONTENT_DIR} -> gs://${BUCKET}"
echo "Env: ${ENV} | Site: ${DOMAIN} | Project: ${PROJECT_ID}"
echo

gcloud storage rsync --delete-unmatched-destination-objects --recursive \
  "$CONTENT_DIR" "gs://${BUCKET}"

if [[ "$INVALIDATE" == "true" ]]; then
  if [[ -z "$URL_MAP" ]]; then
    URL_MAP="${PROJECT_NAME}-${ENV}-url-map"
  fi

  echo
  if gcloud compute url-maps describe "$URL_MAP" --global --project "$PROJECT_ID" >/dev/null 2>&1; then
    echo "Invalidating Cloud CDN cache for URL map '${URL_MAP}'..."
    gcloud compute url-maps invalidate-cdn-cache "$URL_MAP" \
      --global \
      --project "$PROJECT_ID" \
      --path '/*' \
      --async >/dev/null
    echo "Cache invalidation submitted."
  else
    echo "Warning: URL map '${URL_MAP}' not found in project '${PROJECT_ID}'." >&2
    echo "Skipping cache invalidation. Use --url-map to set the correct map name." >&2
  fi
fi

echo
echo "Done: https://${DOMAIN}"