#!/usr/bin/env sh
# Rolling deploy via SSM + ALB — sourced by GitLab CI (deploy:preprod / deploy:prod).
# On-instance manual deploy: use deploy.sh instead.
#
# Usage in deploy.yml:
#   . ./devops/aws/ec2/rolling_deploy.sh
#   rolling_deploy
#
# Required env vars (exported by the CI job):
#   EC2_INSTANCE_ID, AWS_REGION, AWS_ACCOUNT_ID
#   ECR_REGISTRY, ECR_REPOSITORY, CI_COMMIT_SHORT_SHA
#   ALB_TARGET_GROUP_ARN   – ARN du target group ALB
#   HEALTH_CHECK_URL       – (optionnel) URL de santé à vérifier après deploy

# ── Attente de la fin d'une commande SSM ─────────────────────────────────────
_ssm_wait() {
  _cmd_id="$1"
  _instance="$2"
  _max="${3:-60}"
  _retries=0
  while true; do
    _status=$(aws ssm get-command-invocation \
      --command-id "$_cmd_id" \
      --instance-id "$_instance" \
      --query "Status" \
      --output text 2>/dev/null || echo "Pending")
    echo "  SSM status : $_status (tentative $_retries/$_max)"
    case "$_status" in
      Success) return 0 ;;
      Failed|Cancelled|TimedOut|Undeliverable|DeliveryTimedOut)
        echo "--- stdout EC2 ---"
        aws ssm get-command-invocation --command-id "$_cmd_id" \
          --instance-id "$_instance" --query "StandardOutputContent" --output text
        echo "--- stderr EC2 ---"
        aws ssm get-command-invocation --command-id "$_cmd_id" \
          --instance-id "$_instance" --query "StandardErrorContent" --output text
        echo "ERREUR : commande SSM échouée (status=$_status)." >&2
        return 1
        ;;
    esac
    _retries=$((_retries + 1))
    if [ "$_retries" -ge "$_max" ]; then
      echo "ERREUR : timeout SSM après $((_max * 5)) secondes." >&2
      return 1
    fi
    sleep 5
  done
}

# ── Drainage ALB (désenregistrer l'instance) ──────────────────────────────────
_alb_drain() {
  _iid="$1" ; _tg="$2"
  echo "=== [rolling_deploy] Drainage ALB — $_iid ==="
  aws elbv2 deregister-targets --target-group-arn "$_tg" --targets "Id=${_iid}"
  while true; do
    _state=$(aws elbv2 describe-target-health \
      --target-group-arn "$_tg" --targets "Id=${_iid}" \
      --query "TargetHealthDescriptions[0].TargetHealth.State" \
      --output text 2>/dev/null || echo "unknown")
    echo "  ALB target : $_state"
    [ "$_state" = "unused" ] && break
    sleep 5
  done
  echo "  Instance drainée."
}

# ── Ré-enregistrement ALB ─────────────────────────────────────────────────────
_alb_register() {
  _iid="$1" ; _tg="$2"
  echo "=== [rolling_deploy] Ré-enregistrement ALB — $_iid ==="
  aws elbv2 register-targets --target-group-arn "$_tg" --targets "Id=${_iid}"
  while true; do
    _state=$(aws elbv2 describe-target-health \
      --target-group-arn "$_tg" --targets "Id=${_iid}" \
      --query "TargetHealthDescriptions[0].TargetHealth.State" \
      --output text 2>/dev/null || echo "unknown")
    echo "  ALB target : $_state"
    [ "$_state" = "healthy" ] && break
    sleep 5
  done
  echo "  Instance healthy."
}

# ── Fonction principale ───────────────────────────────────────────────────────
rolling_deploy() {
  : "${EC2_INSTANCE_ID:?EC2_INSTANCE_ID is required}"
  : "${AWS_REGION:?AWS_REGION is required}"
  : "${ECR_REGISTRY:?ECR_REGISTRY is required}"
  : "${ECR_REPOSITORY:?ECR_REPOSITORY is required}"
  : "${CI_COMMIT_SHORT_SHA:?CI_COMMIT_SHORT_SHA is required}"
  : "${ALB_TARGET_GROUP_ARN:?ALB_TARGET_GROUP_ARN is required}"

  echo "=== [rolling_deploy] Démarrage — commit $CI_COMMIT_SHORT_SHA ==="
  echo "  Instance : $EC2_INSTANCE_ID"
  echo "  Région   : $AWS_REGION"
  echo "  TG ARN   : $ALB_TARGET_GROUP_ARN"

  # 1. Drain ALB (zero-downtime)
  _alb_drain "$EC2_INSTANCE_ID" "$ALB_TARGET_GROUP_ARN"

  # 2. Deploy via SSM
  echo "=== [rolling_deploy] Envoi de la commande SSM ==="
  cat > /tmp/ssm-rolling.json << ENDJSON
  {
    "InstanceIds": ["$EC2_INSTANCE_ID"],
    "DocumentName": "AWS-RunShellScript",
    "Comment": "rolling-deploy $CI_COMMIT_SHORT_SHA",
    "TimeoutSeconds": 300,
    "Parameters": {
      "commands": [
        "set -e",
        "aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY",
        "docker pull $ECR_REGISTRY/$ECR_REPOSITORY/backend:$CI_COMMIT_SHORT_SHA",
        "docker pull $ECR_REGISTRY/$ECR_REPOSITORY/frontend:$CI_COMMIT_SHORT_SHA",
        "docker pull $ECR_REGISTRY/$ECR_REPOSITORY/nginx:$CI_COMMIT_SHORT_SHA",
        "cd /srv/app && IMAGE_TAG=$CI_COMMIT_SHORT_SHA ECR_REGISTRY=$ECR_REGISTRY ECR_REPOSITORY=$ECR_REPOSITORY docker compose -f docker-compose.prod.yml up -d --remove-orphans backend frontend nginx"
      ]
    }
  }
ENDJSON

  _CMD_ID=$(aws ssm send-command \
    --cli-input-json file:///tmp/ssm-rolling.json \
    --query "Command.CommandId" \
    --output text)
  echo "  Command ID : $_CMD_ID"

  # 3. Attente résultat SSM — rollback ALB en cas d'échec
  if ! _ssm_wait "$_CMD_ID" "$EC2_INSTANCE_ID"; then
    echo "=== [rolling_deploy] ÉCHEC SSM — ré-enregistrement ALB avant abandon ==="
    _alb_register "$EC2_INSTANCE_ID" "$ALB_TARGET_GROUP_ARN"
    return 1
  fi

  # 4. Health check optionnel
  if [ -n "${HEALTH_CHECK_URL:-}" ]; then
    echo "=== [rolling_deploy] Health check : $HEALTH_CHECK_URL ==="
    _hc_retries=0
    while true; do
      _code=$(curl -sf -o /dev/null -w "%{http_code}" "$HEALTH_CHECK_URL" 2>/dev/null || echo "000")
      echo "  HTTP $_code"
      [ "$_code" = "200" ] && break
      _hc_retries=$((_hc_retries + 1))
      if [ "$_hc_retries" -ge 12 ]; then
        echo "ERREUR : health check échoué après 60s — rollback ALB." >&2
        _alb_register "$EC2_INSTANCE_ID" "$ALB_TARGET_GROUP_ARN"
        return 1
      fi
      sleep 5
    done
  fi

  # 5. Ré-enregistrement ALB
  _alb_register "$EC2_INSTANCE_ID" "$ALB_TARGET_GROUP_ARN"

  echo "=== [rolling_deploy] Succès — $CI_COMMIT_SHORT_SHA en production ==="
}