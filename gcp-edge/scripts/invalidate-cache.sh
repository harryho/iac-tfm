#!/usr/bin/env bash
set -euo pipefail

# invalidate-cache.sh — invalidate Cloud CDN cache on a URL map
#
# Usage:
#   invalidate-cache.sh [--env <env>] [--project <project-id>] [--url-map <name>] [--path <glob>] [--sync] [--project-name <name>]

usage() {
  cat <<'EOF'
Usage: invalidate-cache.sh [--env <env>] [--project <project-id>] [--url-map <name>] [--path <glob>] [--sync] [--project-name <name>]

Options:
  --env <env>           Environment under envs/ (default: prod)
  --project <id>        Override GCP project ID (default: terraform output project_id)
  --url-map <name>      Override URL map name (default: <project_name>-<env>-url-map)
  --path <glob>         Cache invalidation path (default: /*)
  --sync                Run synchronously (default: async)
  --project-name <name> Project name for default URL map naming (default: gcp-edge)
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
PROJECT_ID=""
URL_MAP=""
PATH_GLOB='/*'
SYNC='false'
PROJECT_NAME="gcp-edge"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="${2:?Missing value for --env}"
      shift 2
      ;;
    --project)
      PROJECT_ID="${2:?Missing value for --project}"
      shift 2
      ;;
    --url-map)
      URL_MAP="${2:?Missing value for --url-map}"
      shift 2
      ;;
    --path)
      PATH_GLOB="${2:?Missing value for --path}"
      shift 2
      ;;
    --project-name)
      PROJECT_NAME="${2:?Missing value for --project-name}"
      shift 2
      ;;
    --sync)
      SYNC='true'
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Error: unexpected argument '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd terraform
require_cmd gcloud

ENV_DIR="$PROJECT_ROOT/envs/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: env directory '$ENV_DIR' not found." >&2
  exit 1
fi

# Try to pick up project_name from the env's tfvars
if [[ -f "$ENV_DIR/terraform.tfvars" ]]; then
  PN_FROM_TFVARS="$(grep -E '^project_name\s*=' "$ENV_DIR/terraform.tfvars" | head -1 | sed 's/.*= *"//' | sed 's/"$//')"
  if [[ -n "$PN_FROM_TFVARS" ]]; then
    PROJECT_NAME="$PN_FROM_TFVARS"
  fi
fi

cd "$ENV_DIR"

if [[ -z "$PROJECT_ID" ]]; then
  PROJECT_ID="$(terraform output -raw project_id 2>/dev/null || true)"
fi

if [[ -z "$PROJECT_ID" ]]; then
  echo "Error: unable to determine project_id (set --project or run terraform apply)." >&2
  exit 1
fi

if [[ -z "$URL_MAP" ]]; then
  URL_MAP="${PROJECT_NAME}-${ENV}-url-map"
fi

echo "Invalidating cache"
echo "Project: ${PROJECT_ID}"
echo "URL map: ${URL_MAP}"
echo "Path:    ${PATH_GLOB}"

if ! gcloud compute url-maps describe "$URL_MAP" --global --project "$PROJECT_ID" >/dev/null 2>&1; then
  echo "Error: URL map '${URL_MAP}' not found in project '${PROJECT_ID}'." >&2
  exit 1
fi

if [[ "$SYNC" == 'true' ]]; then
  gcloud compute url-maps invalidate-cdn-cache "$URL_MAP" \
    --global \
    --project "$PROJECT_ID" \
    --path "$PATH_GLOB"
else
  gcloud compute url-maps invalidate-cdn-cache "$URL_MAP" \
    --global \
    --project "$PROJECT_ID" \
    --path "$PATH_GLOB" \
    --async
fi

echo "Done."