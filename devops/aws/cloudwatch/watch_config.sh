#!/usr/bin/env sh
#
# Create or update a CloudWatch dashboard and two alarms (CPU + ALB 5xx).
#
# Examples:
#   ./watch_config.sh dashboard_name=aws-ci-prod alb_arn=arn:aws:elasticloadbalancing:...
#   ./watch_config.sh --cpu-threshold=80 --http-5xx-threshold=5

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/args.sh
. "$LIB_DIR/args.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-eu-west-3}}"
: "${instance_id:=${EC2_INSTANCE_ID:-}}"
: "${dashboard_name:=aws-ci-prod}"
: "${alb_arn:=}"
: "${cpu_threshold:=80}"
: "${http_5xx_threshold:=5}"
: "${alarm_sns_arn:=}"   # optionnel : ARN SNS pour les notifications

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 [dashboard_name=...] [alb_arn=...] [instance_id=...] [cpu_threshold=80] [http_5xx_threshold=5]" >&2
  exit 1
}

if [ -z "$instance_id" ]; then
  echo "ERROR: instance_id est requis (ou export EC2_INSTANCE_ID)." >&2
  exit 1
fi

# Extrait le chemin court de l'ARN ALB pour les métriques CloudWatch
alb_suffix=""
if [ -n "$alb_arn" ]; then
  alb_suffix=$(echo "$alb_arn" | sed 's|.*:loadbalancer/||')
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo "=== [watch_config] Configuration CloudWatch ==="
echo "  Dashboard    : $dashboard_name"
echo "  Instance     : $instance_id"
echo "  Région       : $aws_region"
echo "  CPU seuil    : ${cpu_threshold}%"
echo "  5xx seuil    : $http_5xx_threshold erreurs/min"
[ -n "$alb_arn" ] && echo "  ALB          : $alb_suffix"

alarm_actions_arg=""
[ -n "$alarm_sns_arn" ] && alarm_actions_arg="--alarm-actions $alarm_sns_arn"

# ── Dashboard ─────────────────────────────────────────────────────────────────
echo "=== [watch_config] Création du dashboard ==="
cat > /tmp/cw-dashboard.json << ENDJSON
{
  "widgets": [
    {
      "type": "metric",
      "properties": {
        "title": "CPU Utilization",
        "metrics": [["AWS/EC2", "CPUUtilization", "InstanceId", "$instance_id"]],
        "period": 60, "stat": "Average", "region": "$aws_region", "view": "timeSeries"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "ALB HTTP 5xx",
        "metrics": [["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", "LoadBalancer", "${alb_suffix}"]],
        "period": 60, "stat": "Sum", "region": "$aws_region", "view": "timeSeries"
      }
    },
    {
      "type": "metric",
      "properties": {
        "title": "ALB Request Count",
        "metrics": [["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${alb_suffix}"]],
        "period": 60, "stat": "Sum", "region": "$aws_region", "view": "timeSeries"
      }
    }
  ]
}
ENDJSON

aws cloudwatch put-dashboard \
  --region "$aws_region" \
  --dashboard-name "$dashboard_name" \
  --dashboard-body "$(cat /tmp/cw-dashboard.json)"
echo "  Dashboard '$dashboard_name' mis à jour."

# ── Alarme CPU ─────────────────────────────────────────────────────────────────
echo "=== [watch_config] Alarme CPU > ${cpu_threshold}% ==="
# shellcheck disable=SC2086
aws cloudwatch put-metric-alarm \
  --region "$aws_region" \
  --alarm-name "${dashboard_name}-cpu-high" \
  --alarm-description "CPU > ${cpu_threshold}% on ${instance_id}" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --dimensions "Name=InstanceId,Value=${instance_id}" \
  --statistic Average \
  --period 60 \
  --evaluation-periods 3 \
  --threshold "$cpu_threshold" \
  --comparison-operator GreaterThanThreshold \
  --treat-missing-data notBreaching \
  $alarm_actions_arg
echo "  Alarme CPU '${dashboard_name}-cpu-high' créée/mise à jour."

# ── Alarme ALB 5xx (si alb_arn fourni) ──────────────────────────────────────
if [ -n "$alb_arn" ]; then
  echo "=== [watch_config] Alarme ALB 5xx > ${http_5xx_threshold}/min ==="
  # shellcheck disable=SC2086
  aws cloudwatch put-metric-alarm \
    --region "$aws_region" \
    --alarm-name "${dashboard_name}-alb-5xx" \
    --alarm-description "ALB HTTP 5xx > ${http_5xx_threshold}/min on ${dashboard_name}" \
    --metric-name HTTPCode_ELB_5XX_Count \
    --namespace AWS/ApplicationELB \
    --dimensions "Name=LoadBalancer,Value=${alb_suffix}" \
    --statistic Sum \
    --period 60 \
    --evaluation-periods 1 \
    --threshold "$http_5xx_threshold" \
    --comparison-operator GreaterThanThreshold \
    --treat-missing-data notBreaching \
    $alarm_actions_arg
  echo "  Alarme ALB '${dashboard_name}-alb-5xx' créée/mise à jour."
fi

rm -f /tmp/cw-dashboard.json
echo "=== [watch_config] Configuration CloudWatch terminée ==="