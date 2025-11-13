# DevContainer Makefile
.PHONY: help build run stop clean shell logs restart update

# Default project name
PROJECT_NAME ?= default

# Detect docker compose command (docker-compose or docker compose)
DOCKER_COMPOSE := $(shell \
	if command -v docker-compose >/dev/null 2>&1; then \
		echo "docker-compose"; \
	elif docker compose version >/dev/null 2>&1; then \
		echo "docker compose"; \
	else \
		echo ""; \
	fi)

ifeq ($(DOCKER_COMPOSE),)
$(error Docker Compose is not installed. Please install either 'docker-compose' or the Docker Compose plugin)
endif

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help: ## Show this help message
	@echo "DevContainer Management Commands"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "$(BLUE)%-15s$(NC) %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) build

run: ## Run the container (interactive)
	@echo "$(BLUE)Starting container for project: $(PROJECT_NAME)$(NC)"
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) run --rm --service-ports devcontainer

shell: ## Start container and get shell access
	@echo "$(BLUE)Starting container shell for project: $(PROJECT_NAME)$(NC)"
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) run --rm --service-ports --entrypoint /bin/zsh devcontainer

stop: ## Stop running containers
	@echo "$(YELLOW)Stopping containers...$(NC)"
	$(DOCKER_COMPOSE) down

clean: ## Remove containers and images
	@echo "$(RED)Cleaning up containers and images...$(NC)"
	$(DOCKER_COMPOSE) down --rmi all --volumes --remove-orphans

logs: ## Show container logs
	@echo "$(BLUE)Showing logs for project: $(PROJECT_NAME)$(NC)"
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) logs -f

restart: ## Restart the container
	@echo "$(YELLOW)Restarting container for project: $(PROJECT_NAME)$(NC)"
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) restart

update: ## Pull latest base image and rebuild
	@echo "$(BLUE)Updating base image and rebuilding...$(NC)"
	docker pull archlinux:latest
	PROJECT_NAME=$(PROJECT_NAME) $(DOCKER_COMPOSE) build --no-cache

status: ## Show status of containers
	@echo "$(BLUE)Container status:$(NC)"
	$(DOCKER_COMPOSE) ps

images: ## List devcontainer images
	@echo "$(BLUE)DevContainer images:$(NC)"
	docker images | grep devcontainer || echo "No devcontainer images found"

# Project-specific targets
run-%: ## Run container for specific project (e.g., make run-myproject)
	@echo "$(BLUE)Starting container for project: $*$(NC)"
	PROJECT_NAME=$* $(DOCKER_COMPOSE) run --rm --service-ports devcontainer

shell-%: ## Start shell for specific project (e.g., make shell-myproject)
	@echo "$(BLUE)Starting shell for project: $*$(NC)"
	PROJECT_NAME=$* $(DOCKER_COMPOSE) run --rm --service-ports --entrypoint /bin/zsh devcontainer

# Development helpers
bootstrap: ## Run the bootstrap script locally
	@echo "$(BLUE)Running bootstrap script...$(NC)"
	bash devcontainer.sh --project $(PROJECT_NAME)

test-bootstrap: ## Test bootstrap script in dry-run mode
	@echo "$(YELLOW)Testing bootstrap script (dry run)...$(NC)"
	bash -n devcontainer.sh

# Cleanup helpers
clean-all: ## Remove all devcontainer containers and images
	@echo "$(RED)Removing all devcontainer containers and images...$(NC)"
	docker rm -f $$(docker ps -aq --filter "name=devcontainer") 2>/dev/null || true
	docker rmi -f $$(docker images -q --filter "reference=*devcontainer*") 2>/dev/null || true

# Info targets
info: ## Show system information
	@echo "$(BLUE)System Information:$(NC)"
	@echo "Docker version: $$(docker --version)"
	@echo "Docker Compose version: $$($(DOCKER_COMPOSE) version)"
	@echo "Docker Compose command: $(DOCKER_COMPOSE)"
	@echo "Project name: $(PROJECT_NAME)"
	@echo "Dev directory: $(HOME)/dev"
	@echo "Container name: devcontainer-$(PROJECT_NAME)"

# Quick start for new projects
new-%: ## Create and start new project (e.g., make new-myproject)
	@echo "$(GREEN)Creating new project: $*$(NC)"
	PROJECT_NAME=$* $(MAKE) run