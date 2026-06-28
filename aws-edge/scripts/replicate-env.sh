#!/usr/bin/env bash
# replicate-env.sh — copy an existing env to a new one
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

NEW_ENV=""
SOURCE_ENV="prod"
COPY_CONTENT=true
ENABLE_SITES=false
CHANGE_ROLE_PREFIX=true
DRY_RUN=false

usage() {
  cat <<USAGE
Usage: $0 <new_env_name> [options]

Options:
  --source <env>          Source env to copy from (default: prod)
  --no-content            Skip copying the content/ directory
  --enable-sites          Drop underscore prefix on copied site files
  --no-role-prefix        Keep the source's role_name_prefix instead of changing it
  --dry-run               Print what would happen without changing files
  -h, --help              Show this help
USAGE
}

while [ $# -gt 0 ]; do
  case "$1" in
    --source) SOURCE_ENV="$2"; shift 2 ;;
    --no-content) COPY_CONTENT=false; shift ;;
    --enable-sites) ENABLE_SITES=true; shift ;;
    --no-role-prefix) CHANGE_ROLE_PREFIX=false; shift ;;
    --dry-run) DRY_RUN=true; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $1"; usage; exit 1 ;;
    *) NEW_ENV="$1"; shift ;;
  esac
done

if [ -z "$NEW_ENV" ]; then
  usage; exit 1
fi

# Validate env name
if ! [[ "$NEW_ENV" =~ ^[a-z0-9-]+$ ]]; then
  echo "Error: env name must match ^[a-z0-9-]+\$"
  exit 1
fi

# Source must exist
if [ ! -d "envs/$SOURCE_ENV" ]; then
  echo "Error: source env 'envs/$SOURCE_ENV' does not exist"
  echo "Available envs: $(find envs -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | tr '\n' ' ')"
  exit 1
fi

# Target must not exist
if [ -d "envs/$NEW_ENV" ]; then
  echo "Error: envs/$NEW_ENV already exists"
  exit 1
fi

echo "Replicating envs/$SOURCE_ENV -> envs/$NEW_ENV"
echo "  source:          $SOURCE_ENV"
echo "  target:          $NEW_ENV"
echo "  copy content:    $COPY_CONTENT"
echo "  enable sites:    $ENABLE_SITES"
echo "  rewrite prefix:  $CHANGE_ROLE_PREFIX"
echo "  dry run:         $DRY_RUN"
echo ""

if [ "$DRY_RUN" = true ]; then
  echo "(dry run — no files changed)"
  exit 0
fi

# Copy
cp -r "envs/$SOURCE_ENV" "envs/$NEW_ENV"

# Rewrite role_name_prefix
if [ "$CHANGE_ROLE_PREFIX" = true ]; then
  sed -i.bak "s/role_name_prefix = \"iac-$SOURCE_ENV\"/role_name_prefix = \"iac-$NEW_ENV\"/g" \
    "envs/$NEW_ENV/variables.tf" \
    "envs/$NEW_ENV/terraform.tfvars.example" 2>/dev/null || true

  sed -i.bak "s/# role_name_prefix = \"iac-$SOURCE_ENV\"/# role_name_prefix = \"iac-$NEW_ENV\"/g" \
    "envs/$NEW_ENV/variables.tf" \
    "envs/$NEW_ENV/terraform.tfvars.example" 2>/dev/null || true
  rm -f envs/$NEW_ENV/*.bak
fi

# Rewrite environment_name
sed -i.bak "s/^environment_name = \"$SOURCE_ENV\"/environment_name = \"$NEW_ENV\"/g" \
  "envs/$NEW_ENV/variables.tf" \
  "envs/$NEW_ENV/terraform.tfvars.example" 2>/dev/null || true
rm -f envs/$NEW_ENV/*.bak

# Handle content
if [ "$COPY_CONTENT" = false ]; then
  rm -rf "envs/$NEW_ENV/content"
  mkdir -p "envs/$NEW_ENV/content"
fi

# Handle sites — copied site files keep their underscore prefix unless
# --enable-sites was passed (handled below in the next-steps hint).

# Generate per-env GitHub Environment secret names
SECRET_PLAN="AWS_ROLE_ARN_PLAN_$(echo "$NEW_ENV" | tr '[:lower:]' '[:upper:]')"
SECRET_APPLY="AWS_ROLE_ARN_APPLY_$(echo "$NEW_ENV" | tr '[:lower:]' '[:upper:]')"

cat <<NEXT_STEPS

Done. Next steps:
  1. Edit envs/$NEW_ENV/terraform.tfvars — domains, SES emails, etc.
  2. cd envs/$NEW_ENV
  3. terraform init
  4. terraform plan -out=tfplan
  5. terraform apply tfplan
  6. In GitHub repo -> Settings -> Environments, create "$NEW_ENV" with:
       - $SECRET_PLAN
       - $SECRET_APPLY
NEXT_STEPS
