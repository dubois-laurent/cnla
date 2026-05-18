# Docker Compose at repo root; loads .env when present
COMPOSE ?= docker compose

.PHONY: help up down down-v build rebuild ps logs logs-all restart stop start shell clean prune

.DEFAULT_GOAL := help

help: ## Show available targets and URLs
	@printf '\n  Docker containers\n\n'
	@echo '  App:    http://localhost:8088'
	@echo '  API:    http://localhost:3000'
	@echo '  Vite:   http://localhost:5173'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z0-9_.-]+:.*?## ' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
	@echo ''

up: ## Start all services in the background
	$(COMPOSE) up -d

down: ## Stop and remove containers
	$(COMPOSE) down

down-v: ## Full reset: containers, volumes, orphans, local images (then make rebuild)
	$(COMPOSE) down -v --remove-orphans --rmi local

build: ## Build images without starting
	$(COMPOSE) build

rebuild: ## Rebuild images without cache, then start
	$(COMPOSE) build --no-cache
	$(COMPOSE) up -d

ps: ## List containers and status
	$(COMPOSE) ps -a

logs: ## Follow logs; example make logs s=frontend or s=backend
	@if [ -n "$(s)" ]; then $(COMPOSE) logs -f "$(s)"; else $(COMPOSE) logs -f; fi

logs-all: ## Follow logs for all services with tail buffer
	$(COMPOSE) logs -f --tail=200

restart: ## Restart services; optional s=service name
	@if [ -n "$(s)" ]; then $(COMPOSE) restart "$(s)"; else $(COMPOSE) restart; fi

stop: ## Stop containers without removing them
	$(COMPOSE) stop

start: ## Start existing stopped containers
	$(COMPOSE) start

shell: ## Open sh in a container; requires s=service name
	@if [ -z "$(s)" ]; then echo 'Usage: make shell s=backend'; exit 1; fi
	$(COMPOSE) exec "$(s)" sh

clean: ## Stop project and remove locally built images
	$(COMPOSE) down --rmi local

prune: ## Run docker system prune on unused Docker data
	@echo 'Running docker system prune -f'
	docker system prune -f
