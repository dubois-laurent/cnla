#!/usr/bin/env sh
#
# Compress application logs and upload to S3.
# Path: s3://<bucket>/<env>/YYYY/MM/DD/<hostname>.log.gz
#
# Examples:
#   ./archive_logs.sh s3_bucket=my-app-logs environment=prod hostname=web-01
#   ./archive_logs.sh --s3-bucket=my-app-logs --log-path=/var/log/nginx/access.log
