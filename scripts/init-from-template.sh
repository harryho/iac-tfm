#!/usr/bin/env bash
# init-from-template.sh — substitute placeholders across the repo
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Idempotency check
if grep -rq "example\.com" --include="*.md" --include="*.tf" --include="*.tfvars*" --include="*.yml" . 2>/dev/null; then
  : # placeholders still present, proceed
else
  echo "Error: no example.com placeholders found. Already initialized?"
  exit 1
fi

prompt() {
  local _var_name="$1"
  local prompt_text="$2"
  local default="${3:-}"
  local value
  if [ -n "$default" ]; then
    read -r -p "$prompt_text [$default]: " value
    value="${value:-$default}"
  else
    while [ -z "${value:-}" ]; do
      read -r -p "$prompt_text: " value
    done
  fi
  echo "$value"
}

PROJECT_NAME=$(prompt project_name "Project name (lowercase, alphanumeric + hyphens)" "iac-tfm")
AWS_REGION=$(prompt aws_region "Primary AWS region" "ap-southeast-2")
GITHUB_ORG=$(prompt github_org "GitHub org/user (no YOUR_ prefix)")
PRIMARY_DOMAIN=$(prompt primary_domain "Primary domain (e.g. example.com)")
ALERT_EMAIL=$(prompt alert_email "SES alert email (or blank to skip)" "")

echo ""
echo "About to substitute placeholders across the repo:"
echo "  PROJECT_NAME  = $PROJECT_NAME"
echo "  AWS_REGION    = $AWS_REGION"
echo "  GITHUB_ORG    = $GITHUB_ORG"
echo "  PRIMARY_DOMAIN= $PRIMARY_DOMAIN"
echo "  ALERT_EMAIL   = ${ALERT_EMAIL:-<skipped>}"
echo ""
read -r -p "Proceed? [y/N] " confirm
[ "$confirm" = "y" ] || [ "$confirm" = "Y" ] || { echo "Aborted."; exit 1; }

# Substitute
find . -type f \( -name "*.md" -o -name "*.tf" -o -name "*.tfvars*" -o -name "*.yml" -o -name "*.yaml" -o -name "*.sh" \) \
  -not -path "./.git/*" \
  -exec sed -i '' \
    -e "s/example\.com/$PRIMARY_DOMAIN/g" \
    -e "s/YOUR_ORG/$GITHUB_ORG/g" \
    -e "s/YOUR_REPO/$PROJECT_NAME/g" \
    -e "s/ap-southeast-2/$AWS_REGION/g" \
    {} +

echo ""
echo "Done. Next steps:"
echo "  1. cd bootstrap && terraform init && terraform apply"
echo "  2. cd envs/prod && terraform init && terraform plan"
echo "  3. Drop the underscore prefix on envs/prod/sites/_*.tf to enable sites"
