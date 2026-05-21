#!/usr/bin/env sh
#
# Compress application logs and upload to S3.
# Path: s3://<bucket>/<env>/YYYY/MM/DD/<hostname>.log.gz
#
# Examples:
#   ./archive_logs.sh s3_bucket=my-app-logs environment=prod hostname=web-01
#   ./archive_logs.sh --s3-bucket=my-app-logs --log-path=/var/log/nginx/access.log

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../lib" && pwd)"

# shellcheck source=../lib/args.sh
. "$LIB_DIR/args.sh"

# ── Defaults ─────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${s3_bucket:=}"
: "${environment:=prod}"
: "${hostname:=$(hostname -s 2>/dev/null || cat /etc/hostname 2>/dev/null || echo unknown)}"
: "${log_path:=/var/log/nginx/access.log}"
: "${rotate:=true}"   # truncate source log after upload

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 s3_bucket=<bucket> [environment=prod] [log_path=...] [rotate=true|false]" >&2
  exit 1
}

# ── Validate ──────────────────────────────────────────────────────────────────
if [ -z "$s3_bucket" ]; then
  echo "ERROR: s3_bucket is required." >&2
  exit 1
fi
if [ ! -f "$log_path" ]; then
  echo "ERROR: log_path '$log_path' introuvable." >&2
  exit 1
fi

# ── Compute S3 key ────────────────────────────────────────────────────────────
date_path=$(date -u "+%Y/%m/%d")
s3_key="${environment}/${date_path}/${hostname}.log.gz"
tmp_gz="/tmp/${hostname}-$(date -u +%Y%m%d%H%M%S).log.gz"

echo "=== [archive_logs] Archivage des logs ==="
echo "  Source   : $log_path"
echo "  Cible    : s3://$s3_bucket/$s3_key"

# ── Compress ─────────────────────────────────────────────────────────────────
echo "=== [archive_logs] Compression ==="
gzip -c "$log_path" > "$tmp_gz"
echo "  Taille compressée : $(du -sh "$tmp_gz" | cut -f1)"

# ── Upload ────────────────────────────────────────────────────────────────────
echo "=== [archive_logs] Upload vers S3 ==="
if [ -n "$aws_region" ]; then
  aws s3 cp "$tmp_gz" "s3://${s3_bucket}/${s3_key}" --region "$aws_region"
else
  aws s3 cp "$tmp_gz" "s3://${s3_bucket}/${s3_key}"
fi
echo "  Upload réussi : s3://$s3_bucket/$s3_key"

# ── Cleanup + rotate ──────────────────────────────────────────────────────────
rm -f "$tmp_gz"
if [ "$rotate" = "true" ]; then
  echo "=== [archive_logs] Rotation (truncate) ==="
  : > "$log_path"
  echo "  Log tronqué : $log_path"
fi

echo "=== [archive_logs] Terminé ==="
