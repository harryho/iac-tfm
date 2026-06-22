#!/usr/bin/env bash
# verify-site.sh — smoke test a deployed site
#
# Usage: verify-site.sh [--with-contact-form] <env_name> <site_key>
# Example: verify-site.sh prod example-com
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WITH_CONTACT_FORM=false

while [ $# -gt 0 ]; do
  case "$1" in
    --with-contact-form) WITH_CONTACT_FORM=true; shift ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) break ;;
  esac
done

ENV_NAME="${1:?Usage: verify-site.sh [--with-contact-form] <env_name> <site_key>}"
SITE_KEY="${2:?Usage: verify-site.sh [--with-contact-form] <env_name> <site_key>}"
TF_DIR="${REPO_ROOT}/envs/${ENV_NAME}"

if [ ! -d "$TF_DIR" ]; then
  echo "Error: terraform directory '$TF_DIR' not found" >&2
  exit 1
fi

cd "$TF_DIR"

SITES_JSON=$(terraform output -json sites 2>/dev/null || echo "")
CFORMS_JSON=$(terraform output -json contact_forms 2>/dev/null || echo "{}")

DOMAIN=$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].domain // empty')

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
  echo "Error: site '$SITE_KEY' not found in terraform output." >&2
  exit 1
fi

DIST_DOMAIN=$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].distribution_domain // empty')
CF_URL=$(echo "$CFORMS_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].function_url // empty')

echo "Verifying ${DOMAIN} (via ${DIST_DOMAIN})"
echo "========================================="

echo -n "HTTPS (CloudFront):  "
CF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DIST_DOMAIN}" 2>/dev/null || echo "000")
if [ "$CF_STATUS" = "200" ]; then
  echo "OK (200)"
else
  echo "FAIL (${CF_STATUS})"
fi

echo -n "HTTPS (custom domain): "
CUSTOM_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://${DOMAIN}" 2>/dev/null || echo "000")
if [ "$CUSTOM_STATUS" = "200" ] || [ "$CUSTOM_STATUS" = "301" ]; then
  echo "OK (${CUSTOM_STATUS})"
else
  echo "PENDING (${CUSTOM_STATUS}) — DNS may not be configured yet"
fi

echo -n "TLS certificate:      "
CERT_END=$(echo | openssl s_client -connect "${DIST_DOMAIN}:443" -servername "${DIST_DOMAIN}" 2>/dev/null \
  | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
if [ -n "$CERT_END" ]; then
  echo "valid until ${CERT_END}"
else
  echo "unable to check (CloudFront may still be deploying)"
fi

echo -n "404 response:         "
NOT_FOUND=$(curl -s -o /dev/null -w "%{http_code}" "https://${DIST_DOMAIN}/nonexistent-page-12345" 2>/dev/null || echo "000")
if [ "$NOT_FOUND" = "404" ]; then
  echo "OK (404)"
elif [ "$NOT_FOUND" = "200" ]; then
  echo "WARN (200) — CloudFront returning 200 for missing pages, check custom error response"
else
  echo "${NOT_FOUND}"
fi

if [ "$WITH_CONTACT_FORM" = true ] && [ -n "$CF_URL" ] && [ "$CF_URL" != "null" ]; then
  echo -n "Contact form:         "
  CF_STATUS=$(curl -s -o /dev/null -w "%{http_code}" \
    -X POST -H "Content-Type: application/json" \
    -H "Origin: https://${DOMAIN}" \
    -d '{"name":"test","email":"test@test.com","message":"verify script"}' \
    "$CF_URL" 2>/dev/null || echo "000")
  if [ "$CF_STATUS" = "200" ]; then
    echo "OK (200)"
  elif [ "$CF_STATUS" = "403" ]; then
    echo "OK (403 = captcha/origin check working)"
  else
    echo "CHECK (${CF_STATUS})"
  fi
else
  echo "Contact form:         skipped (use --with-contact-form to enable; sends email + writes to DynamoDB)"
fi

echo "========================================="
echo "Verification complete."
