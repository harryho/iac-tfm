#!/usr/bin/env bash
set -euo pipefail

ENV="${1:?Usage: $0 <env>}"
[[ "$ENV" == "prod" ]] && { echo "refuses to destroy prod" >&2; exit 1; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_DIR="$REPO_ROOT/envs/$ENV"
[ -d "$ENV_DIR" ] || { echo "env dir not found: $ENV_DIR" >&2; exit 1; }

read -rp "Type '$ENV' to confirm destroy: " CONFIRM
[[ "$CONFIRM" == "$ENV" ]] || { echo "aborted"; exit 1; }

terraform -chdir="$ENV_DIR" destroy -auto-approve