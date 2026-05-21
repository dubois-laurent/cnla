#!/usr/bin/env sh
#
# Manual rollback to a previous image tag on the current EC2 instance (< 5 min target).
#
# Examples:
#   ./rollback.sh image_tag=previous_sha aws_account_id=123456789012
#   ./rollback.sh --image-tag=abc123 --container-name=prod-nginx

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/args.sh
. "$LIB_DIR/args.sh"
# shellcheck source=../lib/stack_deploy.sh
. "$LIB_DIR/stack_deploy.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${aws_account_id:=${AWS_ACCOUNT_ID:-}}"
: "${ecr_repository_namespace:=grp2/aws-hetic}"
: "${image_tag:=}"
: "${compose_file:=/srv/app/docker-compose.prod.yml}"
: "${services:=backend frontend nginx}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 image_tag=<sha_or_tag> [aws_region=...] [aws_account_id=...]" >&2
  exit 1
}

# ── Validate ──────────────────────────────────────────────────────────────────
if [ -z "$image_tag" ]; then
  echo "ERROR: image_tag is required — fournir le SHA ou le tag vers lequel revenir." >&2
  exit 1
fi
if [ -z "$aws_region" ]; then
  echo "ERROR: aws_region is required (or export AWS_REGION)." >&2
  exit 1
fi
if [ -z "$aws_account_id" ]; then
  echo "ERROR: aws_account_id is required (or export AWS_ACCOUNT_ID)." >&2
  exit 1
fi

ecr_registry="${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com"
ecr_repository="$ecr_repository_namespace"

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=== [rollback] Rollback vers : $image_tag ==="
echo "  Région    : $aws_region"
echo "  Compte    : $aws_account_id"
echo "  Namespace : $ecr_repository_namespace"
echo "  Compose   : $compose_file"
echo "  Services  : $services"

# ── Confirmation interactive (TTY seulement) ──────────────────────────────────
if [ -t 0 ]; then
  printf "Confirmer le rollback vers '%s' ? [oui/non] : " "$image_tag"
  read -r answer
  case "$answer" in
    oui|yes|y|o) ;;
    *) echo "Rollback annulé."; exit 0 ;;
  esac
fi

# ── Authenticate to ECR ───────────────────────────────────────────────────────
echo "=== [rollback] Authentification ECR ==="
aws ecr get-login-password --region "$aws_region" \
  | docker login --username AWS --password-stdin "$ecr_registry"
echo "  Authentification réussie."

# ── Rollback (réutilise stack_up avec le tag cible) ───────────────────────────
stack_up

echo "=== [rollback] Rollback terminé ==="