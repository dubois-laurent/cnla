#!/usr/bin/env sh
# Deploy aws-ci stack on the current host (EC2). Sourced by deploy.sh / rollback.sh.
#
# Exposes one function: stack_up
# Required vars (set by the caller before sourcing):
#   ecr_registry      – e.g. 123456789012.dkr.ecr.eu-west-3.amazonaws.com
#   ecr_repository    – e.g. grp2/aws-hetic
#   image_tag         – Docker image tag to deploy
#   compose_file      – path to the production compose file (default: /srv/app/docker-compose.prod.yml)
#   services          – space-separated list of services (default: backend frontend nginx)

stack_up() {
  : "${ecr_registry:?ecr_registry is required}"
  : "${ecr_repository:?ecr_repository is required}"
  : "${image_tag:?image_tag is required}"
  : "${compose_file:=/srv/app/docker-compose.prod.yml}"
  : "${services:=backend frontend nginx}"

  echo "=== [stack_deploy] Image tag  : $image_tag ==="
  echo "=== [stack_deploy] Compose    : $compose_file ==="
  echo "=== [stack_deploy] Services   : $services ==="

  # Pull each image individually for granular error reporting
  for svc in $services; do
    image="${ecr_registry}/${ecr_repository}/${svc}:${image_tag}"
    echo "  Pulling $image ..."
    docker pull "$image"
  done

  echo "=== [stack_deploy] Redémarrage des services ==="
  IMAGE_TAG="$image_tag" \
  ECR_REGISTRY="$ecr_registry" \
  ECR_REPOSITORY="$ecr_repository" \
  docker compose -f "$compose_file" up -d --remove-orphans $services

  echo "=== [stack_deploy] État des conteneurs ==="
  docker compose -f "$compose_file" ps
}