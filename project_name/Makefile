# ==============================================================
#  Makefile — shortcuts for common Docker operations
#  Usage:  make build | make up | make exec | make down …
# ==============================================================

.PHONY: help build up down exec attach logs clean rebuild xhost

SHELL  := /bin/bash
DC     := docker compose

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ---------- Build ----------

build: ## Build the Docker image
	$(DC) build

rebuild: ## Force rebuild without cache
	$(DC) build --no-cache

# ---------- Run ----------

xhost: ## Allow X11 forwarding (run once per reboot)
	xhost +local:docker

up: xhost ## Start container (detached)
	$(DC) up -d

down: ## Stop & remove container
	$(DC) down

restart: down up ## Restart container

# ---------- Shell ----------

exec: ## Open a new bash shell inside the running container
	$(DC) exec ros2 bash

attach: ## Attach to the main container process
	docker attach project_name

# ---------- Inspect ----------

logs: ## Show container logs
	$(DC) logs -f --tail=100

ps: ## Show running containers
	$(DC) ps

# ---------- Cleanup ----------

clean: down ## Remove container, volumes, and image
	$(DC) down -v --rmi local
	@echo "Cleaned up all project containers, volumes, and images."
