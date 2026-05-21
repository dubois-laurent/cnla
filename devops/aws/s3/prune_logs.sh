#!/usr/bin/env sh
#
# FinOps: delete archived log objects older than retention_days.
# Path layout: s3://<bucket>/<env>/YYYY/MM/DD/<hostname>.log.gz
#
# Examples:
#   ./prune_logs.sh s3_bucket=my-app-logs
#   ./prune_logs.sh dry_run=false confirm=yes retention_days=14

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/args.sh
. "$LIB_DIR/args.sh"
# shellcheck source=../lib/finops_common.sh
. "$LIB_DIR/finops_common.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${s3_bucket:=}"
: "${environment:=}"       # vide = tous les environnements
: "${retention_days:=30}"
: "${dry_run:=true}"
: "${confirm:=}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 s3_bucket=<bucket> [retention_days=30] [dry_run=true|false] [confirm=yes]" >&2
  exit 1
}

# ── Validate ──────────────────────────────────────────────────────────────────
if [ -z "$s3_bucket" ]; then
  echo "ERROR: s3_bucket is required." >&2
  exit 1
fi
if ! echo "$retention_days" | grep -qE '^[0-9]+$' || [ "$retention_days" -lt 1 ]; then
  echo "ERROR: retention_days doit être un entier positif (reçu : $retention_days)." >&2
  exit 1
fi

require_confirm

# Calcul de la date de coupure (GNU date ou BSD date)
cutoff_ts=$(date -u -d "-${retention_days} days" +%s 2>/dev/null \
  || date -u -v "-${retention_days}d" +%s 2>/dev/null || echo "")
if [ -z "$cutoff_ts" ]; then
  echo "ERROR: impossible de calculer la date de coupure." >&2 ; exit 1
fi
cutoff_date=$(date -u -d "@${cutoff_ts}" "+%Y-%m-%d" 2>/dev/null \
  || date -u -r "${cutoff_ts}" "+%Y-%m-%d")

# ── Summary ───────────────────────────────────────────────────────────────────
section "S3 Log Pruning"
echo "  Bucket          : $s3_bucket"
echo "  Environnement   : ${environment:-tous}"
echo "  Rétention       : $retention_days jours (avant $cutoff_date)"
echo "  Dry-run         : $dry_run"

# ── List objects older than cutoff ───────────────────────────────────────────
region_arg=""
[ -n "$aws_region" ] && region_arg="--region $aws_region"

# shellcheck disable=SC2086
all_keys=$(
  aws s3api list-objects-v2 \
    --bucket "$s3_bucket" \
    --prefix "${environment:-}" \
    $region_arg \
    --query "Contents[?LastModified<='${cutoff_date}T23:59:59Z'].Key" \
    --output text 2>/dev/null \
    | tr '\t' '\n' | grep -v '^$' | grep -v '^None$' || true
)

if [ -z "$all_keys" ]; then
  echo ""
  echo "  Aucun objet à supprimer (tous ont moins de $retention_days jours)."
  exit 0
fi

count=$(echo "$all_keys" | grep -c '.')
echo ""
echo "  $count objet(s) à supprimer :"
echo "$all_keys" | sed 's/^/    /'

# ── Delete ────────────────────────────────────────────────────────────────────
total_deleted=0
for key in $all_keys; do
  echo "  Suppression : $key"
  # shellcheck disable=SC2086
  dry_run_exec aws s3 rm "s3://${s3_bucket}/${key}" $region_arg
  total_deleted=$((total_deleted + 1))
done

section "S3 Pruning terminé"
if [ "$dry_run" = "false" ]; then
  echo "$total_deleted objet(s) supprimé(s) de s3://$s3_bucket."
else
  echo "Dry-run mode — aucun objet supprimé."
  echo "Re-run avec : dry_run=false confirm=yes"
fi