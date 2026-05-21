#!/usr/bin/env sh
#
# Rolling deploy via SSM + ALB — sourced by GitLab CI (deploy:preprod / deploy:prod).
# On-instance manual deploy: use deploy.sh instead.
#
# For each instance (one at a time):
#   1. Deregister from ALB  →  no more traffic
#   2. Wait for connection drain
#   3. Deploy new image via SSM send-command
#   4. Re-register in ALB  →  wait for health check
#
# Required GitLab CI variables: AWS_ACCOUNT_ID, AWS_REGION, PROD_TG_ARN,
#   PROD_INSTANCE_1_ID, PROD_INSTANCE_2_ID, CI_COMMIT_SHORT_SHA
#
# Examples (manual):
#   ./rolling_deploy.sh \
#     aws_region=eu-central-1 \
#     aws_account_id=123456789012 \
#     image_tag=abc123 \
#     target_group_arn=arn:aws:elasticloadbalancing:... \
#     instance_ids="i-0abc123 i-0def456"
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
. "${SCRIPT_DIR}/../lib/args.sh"
load_args "$@"

: "${aws_region:?aws_region required}"
: "${aws_account_id:?aws_account_id required}"
: "${image_tag:?image_tag required}"
: "${target_group_arn:?target_group_arn required}"
: "${instance_ids:?instance_ids required (space-separated)}"

ecr_namespace="${ecr_repository_namespace:-grp2/aws-hetic}"
drain_wait="${drain_wait:-30}"

ECR_REGISTRY="${aws_account_id}.dkr.ecr.${aws_region}.amazonaws.com"
export AWS_DEFAULT_REGION="${aws_region}"

echo "=== [rolling-deploy] tag:${image_tag} ==="
echo "  Instances : ${instance_ids}"
echo "  TG ARN    : ${target_group_arn}"

for instance_id in ${instance_ids}; do
  echo ""
  echo "--- [${instance_id}] 1/4 : Deregister from ALB ---"
  aws elbv2 deregister-targets \
    --target-group-arn "${target_group_arn}" \
    --targets "Id=${instance_id}"

  echo "--- [${instance_id}] 2/4 : Drain connections (${drain_wait}s) ---"
  sleep "${drain_wait}"

  echo "--- [${instance_id}] 3/4 : Deploy :${image_tag} via SSM ---"

  # Build the on-instance deploy script and base64-encode it to avoid quoting issues
  SSM_SCRIPT=$(printf '%s\n' \
    "set -e" \
    "aws ecr get-login-password --region ${aws_region} | docker login --username AWS --password-stdin ${ECR_REGISTRY}" \
    "for svc in backend frontend nginx; do docker pull ${ECR_REGISTRY}/${ecr_namespace}/\${svc}:${image_tag}; done" \
    "docker stop nginx frontend backend 2>/dev/null || true" \
    "docker rm   nginx frontend backend 2>/dev/null || true" \
    "docker network create app-net 2>/dev/null || true" \
    "docker run -d --name backend  --network app-net --restart unless-stopped ${ECR_REGISTRY}/${ecr_namespace}/backend:${image_tag}" \
    "docker run -d --name frontend --network app-net --restart unless-stopped ${ECR_REGISTRY}/${ecr_namespace}/frontend:${image_tag}" \
    "docker run -d --name nginx    --network app-net --restart unless-stopped -p 80:80 ${ECR_REGISTRY}/${ecr_namespace}/nginx:${image_tag}" \
  )

  B64=$(printf '%s' "${SSM_SCRIPT}" | base64 | tr -d '\n')

  COMMAND_ID=$(aws ssm send-command \
    --region "${aws_region}" \
    --instance-ids "${instance_id}" \
    --document-name "AWS-RunShellScript" \
    --parameters "commands=[\"echo ${B64} | base64 -d | sh\"]" \
    --comment "rolling-deploy ${image_tag}" \
    --query 'Command.CommandId' --output text)

  echo "  CommandId: ${COMMAND_ID} — waiting..."
  aws ssm wait command-executed \
    --region "${aws_region}" \
    --command-id "${COMMAND_ID}" \
    --instance-id "${instance_id}"

  STATUS=$(aws ssm get-command-invocation \
    --region "${aws_region}" \
    --command-id "${COMMAND_ID}" \
    --instance-id "${instance_id}" \
    --query 'Status' --output text)

  if [ "${STATUS}" != "Success" ]; then
    echo "ERREUR sur ${instance_id} (status: ${STATUS}) — logs:" >&2
    aws ssm get-command-invocation \
      --region "${aws_region}" \
      --command-id "${COMMAND_ID}" \
      --instance-id "${instance_id}" \
      --query 'StandardErrorContent' --output text >&2
    exit 1
  fi

  echo "--- [${instance_id}] 4/4 : Re-register in ALB ---"
  aws elbv2 register-targets \
    --target-group-arn "${target_group_arn}" \
    --targets "Id=${instance_id},Port=80"

  echo "  Waiting for ALB health check..."
  aws elbv2 wait target-in-service \
    --target-group-arn "${target_group_arn}" \
    --targets "Id=${instance_id},Port=80"

  echo "  [${instance_id}] healthy in ALB"
done

echo ""
echo "=== [rolling-deploy] OK — all instances on :${image_tag} ==="
