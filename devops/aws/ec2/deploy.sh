#!/usr/bin/env sh
#
# Manual deploy on an EC2 instance (SSH or SSM session).
# Run after: docker is available and instance role can pull from ECR.
#
# Examples:
#   ./deploy.sh aws_region=eu-west-3 aws_account_id=123456789012 ecr_repository_namespace=aws-ci image_tag=abc123def
#   ./deploy.sh --aws-region=eu-west-3 --image-tag=abc123 --container-name=prod-nginx --host-port=80
