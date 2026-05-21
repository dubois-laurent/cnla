#!/usr/bin/env sh
#
# Manual rollback to a previous image tag on the current EC2 instance (< 5 min target).
#
# Examples:
#   ./rollback.sh image_tag=previous_sha aws_account_id=123456789012
#   ./rollback.sh --image-tag=abc123 --container-name=prod-nginx