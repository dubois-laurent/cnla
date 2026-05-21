#!/usr/bin/env sh
#
# FinOps: prune CI/CD artifacts (ECR images, S3 archived logs, CloudWatch Logs retention).
# Safe by default — dry_run=true. To apply: dry_run=false confirm=yes
#
# Examples:
#   ./finops-cleanup.sh
#   ./finops-cleanup.sh dry_run=false confirm=yes
#   ./finops-cleanup.sh skip_ecr=true s3_retention_days=7

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/lib" && pwd)"
ECR_DIR="$(cd "$SCRIPT_DIR/ecr" && pwd)"
S3_DIR="$(cd "$SCRIPT_DIR/s3" && pwd)"
CW_DIR="$(cd "$SCRIPT_DIR/cloudwatch" && pwd)"

# shellcheck source=lib/args.sh
. "$LIB_DIR/args.sh"
# shellcheck source=lib/finops_common.sh
. "$LIB_DIR/finops_common.sh"

# ── Defaults globaux ────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${aws_account_id:=${AWS_ACCOUNT_ID:-}}"
: "${dry_run:=true}"
: "${confirm:=}"
# ECR
: "${skip_ecr:=false}"
: "${ecr_namespace:=grp2/aws-hetic}"
: "${ecr_keep_count:=10}"
# S3 (opt-in : bucket doit être fourni explicitement)
: "${skip_s3:=true}"
: "${s3_bucket:=}"
: "${s3_retention_days:=30}"
# CloudWatch
: "${skip_cw:=false}"
: "${cw_log_group:=/aws/codebuild/gitlab-runner}"
: "${cw_retention_days:=14}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 [dry_run=true|false] [confirm=yes] [skip_ecr=true] [skip_s3=true] [skip_cw=true] ..." >&2
  exit 1
}

require_confirm

# ── Résumé ───────────────────────────────────────────────────────────────────
section "FinOps Cleanup — Résumé"
echo "  Dry-run      : $dry_run"
echo "  Région       : ${aws_region:-non définie}"
echo ""
echo "  ECR prune    : $([ "$skip_ecr" = "true" ] && echo IGNORÉ || echo "namespace=$ecr_namespace keep=$ecr_keep_count")"
echo "  S3 prune     : $([ "$skip_s3" = "true" ] && echo IGNORÉ || echo "bucket=${s3_bucket:-?} retention=${s3_retention_days}j")"
echo "  CloudWatch   : $([ "$skip_cw" = "true" ] && echo IGNORÉ || echo "log_group=$cw_log_group retention=${cw_retention_days}j")"

# ── ECR ─────────────────────────────────────────────────────────────────────
if [ "$skip_ecr" != "true" ]; then
  section "ECR Image Pruning"
  if [ -z "$aws_account_id" ]; then
    echo "  WARN: aws_account_id non défini — ECR ignoré."
  else
    sh "$ECR_DIR/prune_image.sh" \
      aws_region="$aws_region" \
      aws_account_id="$aws_account_id" \
      ecr_namespace="$ecr_namespace" \
      keep_count="$ecr_keep_count" \
      dry_run="$dry_run" \
      confirm="$confirm"
  fi
fi

# ── S3 ─────────────────────────────────────────────────────────────────────
if [ "$skip_s3" != "true" ]; then
  section "S3 Log Pruning"
  if [ -z "$s3_bucket" ]; then
    echo "  WARN: s3_bucket non défini — S3 ignoré."
  else
    sh "$S3_DIR/prune_logs.sh" \
      aws_region="$aws_region" \
      s3_bucket="$s3_bucket" \
      retention_days="$s3_retention_days" \
      dry_run="$dry_run" \
      confirm="$confirm"
  fi
fi

# ── CloudWatch ──────────────────────────────────────────────────────────────
if [ "$skip_cw" != "true" ]; then
  section "CloudWatch Logs Retention"
  sh "$CW_DIR/logs_retention.sh" \
    aws_region="$aws_region" \
    log_group="$cw_log_group" \
    retention_days="$cw_retention_days" \
    dry_run="$dry_run" \
    confirm="$confirm"
fi

# ── Fin ─────────────────────────────────────────────────────────────────────
section "FinOps Cleanup terminé"
if [ "$dry_run" = "true" ]; then
  echo "Dry-run mode — aucune ressource supprimée."
  echo "Pour appliquer : $0 dry_run=false confirm=yes"
fi