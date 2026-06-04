# Docker Provider Implementation
# This file contains all Docker-specific operations for CI testing

# Docker-specific variables
DOCKER_IMAGE ?= ubuntu:24.04
DOCKER_CONTAINER_NAME ?= dspace-server
DOCKER_SSH_PORT ?= 2222
DOCKER_RUNNING := $(shell docker ps -q -f name=$(DOCKER_CONTAINER_NAME) 2>/dev/null)

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key provider-install-deps

provider-init: ## Initialize Docker container with systemd
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Initializing Docker Container                  ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -z "$(DOCKER_RUNNING)" ]; then \
		echo "🐳 Container not running, starting it..."; \
		$(MAKE) -f providers/docker.mk provider-start; \
	else \
		echo "✅ Container already running"; \
	fi
	@# Setup SSH key authentication
	@$(MAKE) -f providers/docker.mk provider-copy-ssh-key

provider-start: ## Start the Docker container
	@echo "🚀 Starting container '$(DOCKER_CONTAINER_NAME)'..."
	@# Check if container exists but is stopped
	@if docker ps -a -q -f name=$(DOCKER_CONTAINER_NAME) | grep -q .; then \
		if [ -z "$(DOCKER_RUNNING)" ]; then \
			echo "Starting existing container..."; \
			docker start $(DOCKER_CONTAINER_NAME); \
		else \
			echo "Container already running"; \
		fi; \
	else \
		echo "Container doesn't exist, use the CI workflow to create it"; \
		exit 1; \
	fi
	@echo "✅ Container started"

provider-stop: ## Stop the Docker container
	@echo "⏹️  Stopping container '$(DOCKER_CONTAINER_NAME)'..."
	@if [ -n "$(DOCKER_RUNNING)" ]; then \
		docker stop $(DOCKER_CONTAINER_NAME); \
		echo "✅ Container stopped"; \
	else \
		echo "Container not running"; \
	fi

provider-destroy: ## Remove the Docker container
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Removing Docker Container                   ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🗑️  Removing container..."
	@docker stop $(DOCKER_CONTAINER_NAME) 2>/dev/null || true
	@docker rm $(DOCKER_CONTAINER_NAME) 2>/dev/null || true
	@echo "✅ Container removed"

provider-ssh: ## SSH into the Docker container
	@echo "Connecting to container '$(DOCKER_CONTAINER_NAME)'..."
	@ssh -o StrictHostKeyChecking=no -p $(DOCKER_SSH_PORT) admin@localhost

provider-exec: ## Run REMOTE_CMD in the container over SSH (e.g. REMOTE_CMD="uptime")
	@if [ -z "$(REMOTE_CMD)" ]; then echo "❌ REMOTE_CMD is required"; exit 1; fi
	@ssh -t -o StrictHostKeyChecking=no -p $(DOCKER_SSH_PORT) admin@localhost "$(REMOTE_CMD)"

provider-get-ip: ## Get IP address (always localhost for Docker)
	@echo "localhost"

provider-status: ## Check status of the Docker container
	@echo "Docker Provider Status:"
	@if [ -n "$(DOCKER_RUNNING)" ]; then \
		echo "✅ Container: Running"; \
		echo "📍 Host: localhost"; \
		echo "🔌 SSH Port: $(DOCKER_SSH_PORT)"; \
		if ssh -o StrictHostKeyChecking=no -p $(DOCKER_SSH_PORT) admin@localhost "exit" 2>/dev/null; then \
			echo "🔗 SSH: Connected"; \
		else \
			echo "❌ SSH: Not accessible"; \
		fi; \
	else \
		if docker ps -a -q -f name=$(DOCKER_CONTAINER_NAME) | grep -q .; then \
			echo "⏸️  Container: Stopped"; \
		else \
			echo "❌ Container: Not created"; \
		fi; \
	fi

provider-copy-ssh-key: ## Copy SSH key to Docker container
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@# Try to copy SSH key (requires sshpass for initial connection)
	@if command -v sshpass &> /dev/null; then \
		echo "📝 Copying SSH key to container..."; \
		sshpass -p admin ssh-copy-id -o StrictHostKeyChecking=no -p $(DOCKER_SSH_PORT) admin@localhost 2>/dev/null || \
			echo "⚠️  SSH key copy failed, password authentication may be required"; \
	else \
		echo "⚠️  sshpass not installed, manual SSH key setup may be required"; \
	fi
	@echo "✅ SSH key setup complete"

provider-install-deps: ## Install Docker dependencies
	@echo "📦 Checking Docker installation..."
	@if ! command -v docker &> /dev/null; then \
		echo "❌ Docker not installed. Please install from: https://www.docker.com/"; \
		exit 1; \
	else \
		echo "✅ Docker installed"; \
		docker --version; \
	fi