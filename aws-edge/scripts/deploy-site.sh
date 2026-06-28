#!/usr/bin/env bash
# deploy-site.sh — sync content to S3 and invalidate CloudFront
#
# Usage: deploy-site.sh <env_name> <site_key> [content_dir]
# Example: deploy-site.sh prod example-com ./envs/prod/content/example-com/dist
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_NAME="${1:?Usage: deploy-site.sh <env_name> <site_key> [content_dir]}"
SITE_KEY="${2:?Usage: deploy-site.sh <env_name> <site_key> [content_dir]}"
CONTENT_DIR="${3:-${REPO_ROOT}/envs/${ENV_NAME}/content/${SITE_KEY}/dist}"
TF_DIR="${REPO_ROOT}/envs/${ENV_NAME}"

if [ ! -d "$CONTENT_DIR" ]; then
  echo "Error: content directory '$CONTENT_DIR' not found" >&2
  exit 1
fi

if [ ! -d "$TF_DIR" ]; then
  echo "Error: terraform directory '$TF_DIR' not found" >&2
  exit 1
fi

cd "$TF_DIR"

SITES_JSON=$(terraform output -json sites 2>/dev/null || echo "")

if [ -z "$SITES_JSON" ] || [ "$SITES_JSON" = "null" ]; then
  echo "Error: terraform output not available. Run 'terraform apply' first." >&2
  exit 1
fi

DOMAIN=$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].domain // empty')
BUCKET=$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].bucket_name // empty')
DIST_ID=$(echo "$SITES_JSON" | jq -r --arg key "$SITE_KEY" '.[$key].distribution_id // empty')

if [ -z "$DOMAIN" ] || [ "$DOMAIN" = "null" ]; then
  echo "Error: site '$SITE_KEY' not found in terraform output." >&2
  echo "Available sites:" >&2
  echo "$SITES_JSON" | jq -r 'keys[]' >&2
  exit 1
fi

echo "Deploying ${CONTENT_DIR} -> s3://${BUCKET}"
echo "Site: ${DOMAIN}"
echo ""

aws s3 sync "$CONTENT_DIR" "s3://${BUCKET}" --delete

echo ""
echo "Invalidating CloudFront cache (${DIST_ID})..."
aws cloudfront create-invalidation \
  --distribution-id "$DIST_ID" \
  --paths "/*"

echo ""
echo "Done: https://${DOMAIN}"
