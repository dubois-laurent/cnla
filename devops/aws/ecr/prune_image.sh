#!/usr/bin/env sh
#
# FinOps: prune old ECR images (keep N most recent digests per repository).
#
# Examples:
#   ./prune_images.sh dry_run=true
#   ./prune_images.sh dry_run=false confirm=yes keep_count=15