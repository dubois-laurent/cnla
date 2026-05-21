#!/usr/bin/env sh
#
# Manual deploy on an EC2 instance (SSH or SSM session).
# Run after: docker is available and instance role can pull from ECR.
#
# Examples:
#   ./deploy.sh aws_region=eu-central-1 aws_account_id=123456789012 image_tag=abc123
#   ./deploy.sh --aws-region=eu-central-1 --aws-account-id=123456789012 --image-tag=abc123
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "${SCRIPT_DIR}/../lib/args.sh"
load_args "$@"

: "${aws_region:?aws_region required}"
: "${aws_account_id:?aws_account_id required}"
: "${image_tag:?image_tag required}"

ecr_namespace="${ecr_repository_namespace:-grp2/aws-hetic}"
ECR_REGISTRY="${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com"

echo "=== [deploy] tag:${image_tag} — $(date '+%Y-%m-%d %H:%M:%S') ==="
echo "  Registry : ${ECR_REGISTRY}/${ecr_namespace}"

aws ecr get-login-password --region "${aws_region}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

for svc in backend frontend nginx; do
  echo "  Pull ${svc}:${image_tag}..."
  docker pull "${ECR_REGISTRY}/${ecr_namespace}/${svc}:${image_tag}"
done

docker stop  nginx frontend backend 2>/dev/null || true
docker rm    nginx frontend backend 2>/dev/null || true
docker network create app-net 2>/dev/null || true

docker run -d \
  --name backend \
  --network app-net \
  --restart unless-stopped \
  "${ECR_REGISTRY}/${ecr_namespace}/backend:${image_tag}"

docker run -d \
  --name frontend \
  --network app-net \
  --restart unless-stopped \
  "${ECR_REGISTRY}/${ecr_namespace}/frontend:${image_tag}"

docker run -d \
  --name nginx \
  --network app-net \
  --restart unless-stopped \
  -p 80:80 \
  "${ECR_REGISTRY}/${ecr_namespace}/nginx:${image_tag}"

echo "=== [deploy] OK — :${image_tag} running ==="
