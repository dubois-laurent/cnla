#!/usr/bin/env sh
#
# Set CloudWatch Logs retention on any log group (usage général).
# Pour le log group GitLab CI spécifiquement : voir logs_retention.sh
#
# Examples:
#   ./log_retention.sh log_group=/app/prod retention_days=30
#   ./log_retention.sh log_group=/app/prod retention_days=7 dry_run=false confirm=yes

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

. "$LIB_DIR/args.sh"
. "$LIB_DIR/finops_common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${log_group:=}"
: "${retention_days:=30}"
: "${dry_run:=true}"
: "${confirm:=}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 log_group=<name> [retention_days=30] [dry_run=true|false] [confirm=yes]" >&2
  exit 1
}

if [ -z "$log_group" ]; then
  echo "ERROR: log_group est requis." >&2
  exit 1
fi

require_confirm

# ── Summary ───────────────────────────────────────────────────────────────────
section "CloudWatch Logs Retention"
echo "  Log group  : $log_group"
echo "  Rétention  : $retention_days jours"
echo "  Dry-run    : $dry_run"

region_arg=""
[ -n "$aws_region" ] && region_arg="--region $aws_region"

# ── Apply ─────────────────────────────────────────────────────────────────────
# shellcheck disable=SC2086
dry_run_exec aws logs put-retention-policy \
  --log-group-name "$log_group" \
  --retention-in-days "$retention_days" \
  $region_arg

if [ "$dry_run" = "false" ]; then
  echo "  Rétention de $retention_days jours appliquée sur $log_group."
else
  echo "  Dry-run — aucune modification."
fi
