#!/usr/bin/env sh
#
# FinOps: prune CI/CD artifacts (ECR images, S3 archived logs, CloudWatch Logs retention).
# Safe by default — dry_run=true. To apply: dry_run=false confirm=yes
#
# Examples:
#   ./finops-cleanup.sh
#   ./finops-cleanup.sh dry_run=false confirm=yes
#   ./finops-cleanup.sh skip_ecr=true s3_retention_days=7