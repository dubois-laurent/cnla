#!/usr/bin/env sh
#
# FinOps: prune old ECR images (keep N most recent digests per repository).
#
# Arguments:
#   aws_region          AWS region (default: $AWS_REGION)
#   aws_account_id      AWS account ID (default: $AWS_ACCOUNT_ID)
#   ecr_namespace       ECR repository prefix (default: grp2/aws-hetic)
#   repositories        Space-separated list of services (default: backend frontend nginx)
#   keep_count          Number of most-recent digests to keep per repo (default: 10)
#   dry_run             true = print only, false = delete (default: true)
#   confirm             Must be "yes" when dry_run=false (safety gate)
#
# Examples:
#   ./prune_image.sh dry_run=true
#   ./prune_image.sh dry_run=false confirm=yes keep_count=15
#   ./prune_image.sh aws_region=eu-west-3 aws_account_id=123456789012 keep_count=5 dry_run=false confirm=yes

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="$(cd "$SCRIPT_DIR/../../lib" && pwd)"

# shellcheck source=../lib/args.sh
. "$LIB_DIR/args.sh"
# shellcheck source=../lib/finops_common.sh
. "$LIB_DIR/finops_common.sh"

# ── Defaults ──────────────────────────────────────────────────────────────────
: "${aws_region:=${AWS_REGION:-}}"
: "${aws_account_id:=${AWS_ACCOUNT_ID:-}}"
: "${ecr_namespace:=grp2/aws-hetic}"
: "${repositories:=backend frontend nginx}"
: "${keep_count:=10}"
: "${dry_run:=true}"
: "${confirm:=}"

# ── Parse CLI args ────────────────────────────────────────────────────────────
load_args "$@" || {
  echo "Usage: $0 [aws_region=...] [aws_account_id=...] [keep_count=N] [dry_run=true|false] [confirm=yes]" >&2
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
if ! echo "$keep_count" | grep -qE '^[0-9]+$' || [ "$keep_count" -lt 1 ]; then
  echo "ERROR: keep_count must be a positive integer (got: $keep_count)." >&2
  exit 1
fi

require_confirm

# ── Summary ───────────────────────────────────────────────────────────────────
section "ECR Image Pruning — Summary"
echo "  Region       : $aws_region"
echo "  Account      : $aws_account_id"
echo "  Namespace    : $ecr_namespace"
echo "  Repositories : $repositories"
echo "  Keep (N)     : $keep_count most recent digests"
echo "  Dry-run      : $dry_run"

# ── Per-repository pruning ────────────────────────────────────────────────────
for service in $repositories; do
  repo="${ecr_namespace}/${service}"
  section "Repository: $repo"

  # Fetch all image digests sorted oldest → newest (one per line)
  all_digests=$(
    aws ecr describe-images \
      --region "$aws_region" \
      --repository-name "$repo" \
      --query 'sort_by(imageDetails, &imagePushedAt)[*].imageDigest' \
      --output text 2>/dev/null | tr '\t' '\n'
  ) || {
    echo "  WARN: cannot describe images for '$repo' — skipping."
    continue
  }

  if [ -z "$all_digests" ]; then
    echo "  No images found — skipping."
    continue
  fi

  total=$(echo "$all_digests" | grep -c '.')
  echo "  Total images : $total"
  echo "  To keep      : $keep_count"

  if [ "$total" -le "$keep_count" ]; then
    echo "  Nothing to delete ($total <= $keep_count) — skipping."
    continue
  fi

  to_delete_count=$((total - keep_count))
  echo "  To delete    : $to_delete_count"

  # Oldest digests are at the top — take the first to_delete_count lines
  to_delete=$(echo "$all_digests" | head -n "$to_delete_count")

  echo "  Digests scheduled for deletion:"
  echo "$to_delete" | sed 's/^/    /'

  # Delete one digest at a time to keep error handling granular
  deleted=0
  for digest in $to_delete; do
    echo "  Deleting $digest ..."
    dry_run_exec aws ecr batch-delete-image \
      --region "$aws_region" \
      --repository-name "$repo" \
      --image-ids "imageDigest=${digest}" \
      --output json
    deleted=$((deleted + 1))
  done

  if [ "$dry_run" = "false" ]; then
    echo "  Done — deleted $deleted image(s) from $repo."
  fi
done

# ── Footer ────────────────────────────────────────────────────────────────────
section "Pruning complete"
if [ "$dry_run" = "true" ]; then
  echo "Dry-run mode — no images were deleted."
  echo "To apply for real: $0 dry_run=false confirm=yes keep_count=$keep_count"
fi