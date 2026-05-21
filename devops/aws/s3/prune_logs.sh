#!/usr/bin/env sh
#
# FinOps: delete archived log objects older than retention_days.
# Path layout: s3://<bucket>/<env>/YYYY/MM/DD/<hostname>.log.gz
#
# Examples:
#   ./prune_logs.sh s3_bucket=my-app-logs
#   ./prune_logs.sh dry_run=false confirm=yes retention_days=14