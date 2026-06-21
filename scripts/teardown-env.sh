#!/usr/bin/env bash
# teardown-env.sh — safe destroy of a whole environment
#
# Usage: teardown-env.sh <env_name> [--force] [--remove-folder] [--no-state-cleanup]
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

ENV_NAME=""
FORCE=false
REMOVE_FOLDER=false
NO_STATE_CLEANUP=false

while [ $# -gt 0 ]; do
  case "$1" in
    --force) FORCE=true; shift ;;
    --remove-folder) REMOVE_FOLDER=true; shift ;;
    --no-state-cleanup) NO_STATE_CLEANUP=true; shift ;;
    -*) echo "Unknown option: $1"; exit 1 ;;
    *) ENV_NAME="$1"; shift ;;
  esac
done

if [ -z "$ENV_NAME" ]; then
  echo "Usage: $0 <env_name> [--force] [--remove-folder] [--no-state-cleanup]"
  echo ""
  echo "Available envs: $(find envs -maxdepth 1 -mindepth 1 -type d -exec basename {} \; 2>/dev/null | tr '\n' ' ')"
  exit 1
fi

if [ ! -d "envs/$ENV_NAME" ]; then
  echo "Error: envs/$ENV_NAME does not exist"
  exit 1
fi

if [ "$ENV_NAME" = "prod" ] && [ "$FORCE" = false ]; then
  echo "Refusing to teardown prod without --force"
  exit 1
fi

# Typed confirmation
echo ""
echo "WARNING: This will destroy ALL AWS resources for env '$ENV_NAME'."
echo "After this, the env is gone. The bootstrap state bucket is NOT touched."
echo ""
read -r -p "Type the env name to confirm: " confirm1
if [ "$confirm1" != "$ENV_NAME" ]; then
  echo "Confirmation failed. Aborting."
  exit 1
fi

if [ "$FORCE" = true ]; then
  read -r -p "Type the env name AGAIN (prod teardown): " confirm2
  if [ "$confirm2" != "$ENV_NAME" ]; then
    echo "Second confirmation failed. Aborting."
    exit 1
  fi
fi

# 1. Empty S3 buckets tagged with this env
echo ""
echo "Emptying S3 buckets tagged Env=$ENV_NAME ..."
BUCKETS=$(aws resourcegroupstaggingapi get-resources \
  --tag-filters "Key=Env,Values=$ENV_NAME" "Key=ManagedBy,Values=terraform" \
  --resource-type-filters "s3" \
  --query 'ResourceTagMappingList[].ResourceARN' --output text 2>/dev/null || true)

for arn in $BUCKETS; do
  bucket="${arn#arn:aws:s3:::}"
  echo "  emptying s3://$bucket"
  aws s3 rm "s3://$bucket" --recursive --quiet || true
done

# 2. terraform destroy
echo ""
echo "Running terraform destroy in envs/$ENV_NAME ..."
cd "envs/$ENV_NAME"
terraform init -upgrade -input=false >/dev/null
terraform destroy -auto-approve -input=false
cd "$REPO_ROOT"

# 3. Clean up state
if [ "$NO_STATE_CLEANUP" = false ]; then
  echo ""
  echo "Cleaning up state files for env '$ENV_NAME' ..."
  STATE_BUCKET=$(terraform -chdir=bootstrap output -raw state_bucket_arn 2>/dev/null | sed 's/.*:://' || echo "")
  if [ -n "$STATE_BUCKET" ]; then
    aws s3 rm "s3://$STATE_BUCKET/envs/$ENV_NAME/" --recursive --quiet || true
  else
    echo "  (could not determine state bucket — skipping)"
  fi
fi

# 4. Optional folder removal
if [ "$REMOVE_FOLDER" = true ]; then
  echo ""
  read -r -p "Also remove envs/$ENV_NAME/ folder? [y/N] " rm_confirm
  if [ "$rm_confirm" = "y" ] || [ "$rm_confirm" = "Y" ]; then
    rm -rf "envs/$ENV_NAME"
    echo "  removed envs/$ENV_NAME/"
  fi
fi

echo ""
echo "Teardown complete for env '$ENV_NAME'."
