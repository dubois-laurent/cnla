#!/usr/bin/env sh
#
# Create or update a CloudWatch dashboard and two alarms (CPU + ALB 5xx).
#
# Examples:
#   ./watch_config.sh dashboard_name=aws-ci-prod alb_arn=arn:aws:elasticloadbalancing:...
#   ./watch_config.sh --cpu-threshold=80 --http-5xx-threshold=5