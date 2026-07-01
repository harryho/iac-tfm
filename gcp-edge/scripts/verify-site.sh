#!/usr/bin/env bash
set -euo pipefail

# verify-site.sh — smoke test a deployed site
#
# Usage:
#   verify-site.sh [--env <env>] [--site-url <url>] [--timeout <seconds>] <site-key>
#
# Example:
#   verify-site.sh --env prod www_example_com

usage() {
  cat <<'EOF'
Usage: verify-site.sh [--env <env>] [--site-url <url>] [--timeout <seconds>] <site-key>

Options:
  --env <env>           Environment under envs/ (default: prod)
  --site-url <url>      Override target URL (default: https://<domain from terraform output>)
  --timeout <seconds>   curl timeout in seconds (default: 15)
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
SITE_URL=""
TIMEOUT="15"
SITE_KEY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV="${2:?Missing value for --env}"
      shift 2
      ;;
    --site-url)
      SITE_URL="${2:?Missing value for --site-url}"
      shift 2
      ;;
    --timeout)
      TIMEOUT="${2:?Missing value for --timeout}"
      shift 2
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

for cmd in terraform jq curl openssl; do
  require_cmd "$cmd"
done

ENV_DIR="$PROJECT_ROOT/envs/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  echo "Error: env directory '$ENV_DIR' not found." >&2
  exit 1
fi

cd "$ENV_DIR"

SITES_JSON="$(terraform output -json sites 2>/dev/null || true)"
if [[ -z "$SITES_JSON" || "$SITES_JSON" == "null" ]]; then
  echo "Error: terraform output 'sites' is unavailable. Run 'terraform apply' first." >&2
  exit 1
fi

DOMAIN="$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].domain // empty')"
if [[ -z "$DOMAIN" ]]; then
  echo "Error: site '$SITE_KEY' not found in terraform output for env '$ENV'." >&2
  echo "Available sites:" >&2
  echo "$SITES_JSON" | jq -r 'keys[]' >&2
  exit 1
fi

if [[ -z "$SITE_URL" ]]; then
  SITE_URL="https://${DOMAIN}"
fi

SCHEME="${SITE_URL%%://*}"
if [[ "$SITE_URL" == "$SCHEME" ]]; then
  SCHEME="https"
fi
HOST_PORT_PATH="${SITE_URL#*://}"
HOST_PORT="${HOST_PORT_PATH%%/*}"
HOST="${HOST_PORT%%:*}"
TLS_PORT="${HOST_PORT#*:}"
if [[ "$TLS_PORT" == "$HOST_PORT" ]]; then
  TLS_PORT="443"
fi

http_status() {
  curl -sS -o /dev/null -w "%{http_code}" --max-time "$TIMEOUT" "$1" 2>/dev/null || echo "000"
}

echo "Verifying ${DOMAIN} (env: ${ENV})"
echo "Target URL: ${SITE_URL}"
echo "========================================="

echo -n "HTTP -> HTTPS redirect: "
HTTP_CODE="$(http_status "http://${HOST}/")"
if [[ "$HTTP_CODE" == "301" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "308" ]]; then
  echo "OK (${HTTP_CODE})"
else
  echo "CHECK (${HTTP_CODE})"
fi

echo -n "HTTPS response:        "
HTTPS_CODE="$(http_status "$SITE_URL")"
if [[ "$HTTPS_CODE" == "200" || "$HTTPS_CODE" == "301" || "$HTTPS_CODE" == "302" || "$HTTPS_CODE" == "308" ]]; then
  echo "OK (${HTTPS_CODE})"
else
  echo "FAIL (${HTTPS_CODE})"
fi

echo -n "TLS certificate:       "
CERT_END="$(
  echo | openssl s_client -connect "${HOST}:${TLS_PORT}" -servername "$HOST" 2>/dev/null \
    | openssl x509 -noout -enddate 2>/dev/null \
    | cut -d= -f2
)"
if [[ -n "$CERT_END" ]]; then
  echo "valid until ${CERT_END}"
else
  echo "unable to check"
fi

echo -n "404 response:          "
NOT_FOUND="$(http_status "${SITE_URL%/}/nonexistent-page-12345")"
if [[ "$NOT_FOUND" == "404" ]]; then
  echo "OK (404)"
elif [[ "$NOT_FOUND" == "200" ]]; then
  echo "WARN (200)"
else
  echo "CHECK (${NOT_FOUND})"
fi

echo -n "Contact form (400 = captcha/origin check working): "
CF_STATUS="$(http_status "$SITE_URL/api/contact")"
if [[ "$CF_STATUS" == "400" || "$CF_STATUS" == "403" ]]; then
  echo "OK (${CF_STATUS})"
elif [[ "$CF_STATUS" == "404" ]]; then
  echo "SKIPPED (404 — contact form not enabled for this site)"
else
  echo "CHECK (${CF_STATUS})"
fi

echo "========================================="
echo "Verification complete."