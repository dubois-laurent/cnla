#!/usr/bin/env sh
#
# Manual deploy on an EC2 instance (SSH or SSM session).
# Run after: docker is available and instance role can pull from ECR.
#
# Examples:
#   ./deploy.sh aws_region=eu-west-3 aws_account_id=123456789012 ecr_repository_namespace=aws-ci image_tag=abc123def
#   ./deploy.sh --aws-region=eu-west-3 --image-tag=abc123 --container-name=prod-nginx --host-port=80

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
: "${image_tag:=${IMAGE_TAG:-latest}}"
: "${compose_file:=/srv/app/docker-compose.prod.yml}"
: "${services:=backend frontend nginx}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 [aws_region=...] [aws_account_id=...] [ecr_repository_namespace=...] [image_tag=...]" >&2
  exit 1
}

# ── Validate ──────────────────────────────────────────────────────────────────
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
echo "=== [deploy] Déploiement manuel EC2 ==="
echo "  Région      : $aws_region"
echo "  Compte      : $aws_account_id"
echo "  Registry    : $ecr_registry"
echo "  Namespace   : $ecr_repository_namespace"
echo "  Image tag   : $image_tag"
echo "  Compose     : $compose_file"
echo "  Services    : $services"

# ── Authenticate to ECR ───────────────────────────────────────────────────────
echo "=== [deploy] Authentification ECR ==="
aws ecr get-login-password --region "$aws_region" \
  | docker login --username AWS --password-stdin "$ecr_registry"
echo "  Authentification réussie."

# ── Deploy ────────────────────────────────────────────────────────────────────
stack_up

echo "=== [deploy] Déploiement terminé ==="
