#!/usr/bin/env sh
#
# Manual rollback to a previous image tag on the current EC2 instance (< 5 min target).
# Wraps deploy.sh with a previous SHA — run on the instance directly (SSH or SSM session).
#
# Examples:
#   ./rollback.sh image_tag=previous_sha aws_account_id=123456789012
#   ./rollback.sh --image-tag=abc123 --aws-account-id=123456789012
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "${SCRIPT_DIR}/../lib/args.sh"
load_args "$@"

: "${image_tag:?image_tag (previous SHA) required}"
: "${aws_account_id:?aws_account_id required}"

aws_region="${aws_region:-eu-central-1}"
ecr_repository_namespace="${ecr_repository_namespace:-grp2/aws-hetic}"

echo "=== [rollback] Rolling back to :${image_tag} ==="

"${SCRIPT_DIR}/deploy.sh" \
  aws_region="${aws_region}" \
  aws_account_id="${aws_account_id}" \
  image_tag="${image_tag}" \
  ecr_repository_namespace="${ecr_repository_namespace}"

echo "=== [rollback] OK ==="
