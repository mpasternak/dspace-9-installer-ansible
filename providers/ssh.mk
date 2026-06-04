# SSH Provider Implementation
# This file provides operations for direct SSH host connections (no virtualization)

# SSH-specific variables
SSH_HOST ?=
SSH_PORT ?= 22
SSH_PRIVATE_KEY ?= ~/.ssh/id_rsa

# Validate SSH_HOST is provided
ifndef SSH_HOST
$(error SSH_HOST is required for SSH provider. Usage: SSH_HOST=192.168.1.100 make <target>)
endif

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key

provider-init: ## Initialize SSH connection (validate host)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Initializing SSH Host Connection               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔍 Validating SSH host: $(SSH_HOST)"
	@# Test SSH connection
	@if ssh -o ConnectTimeout=5 -o BatchMode=yes -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) exit 2>/dev/null; then \
		echo "✅ SSH connection successful"; \
		echo "📍 Host: $(SSH_HOST):$(SSH_PORT)"; \
		echo "👤 User: $(SSH_USER)"; \
	else \
		echo "❌ Cannot connect to SSH host"; \
		echo ""; \
		echo "Please ensure:"; \
		echo "  1. The host is accessible: $(SSH_HOST):$(SSH_PORT)"; \
		echo "  2. SSH service is running on the host"; \
		echo "  3. Your SSH key is authorized or run: make provider-copy-ssh-key"; \
		exit 1; \
	fi
	@# Check if host is Ubuntu/Debian
	@echo "🔍 Checking host OS..."
	@if ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "lsb_release -d 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME" | grep -iE "(ubuntu|debian)"; then \
		echo "✅ Compatible OS detected"; \
	else \
		echo "⚠️  Warning: Non-Ubuntu/Debian OS detected. Some operations may not work as expected."; \
	fi

provider-start: ## Start SSH host (no-op for SSH provider)
	@echo "ℹ️  SSH provider: Host management is external"
	@echo "📍 Configured host: $(SSH_HOST):$(SSH_PORT)"

provider-stop: ## Stop SSH host (no-op for SSH provider)
	@echo "ℹ️  SSH provider: Host management is external"
	@echo "📍 The host $(SSH_HOST) remains running"

provider-destroy: ## Destroy SSH host (no-op for SSH provider)
	@echo "ℹ️  SSH provider: Host management is external"
	@echo "📍 No action taken on host $(SSH_HOST)"
	@echo ""
	@echo "To clean up the host, manually run:"
	@echo "  ssh $(SSH_USER)@$(SSH_HOST) 'sudo rm -rf /opt/dspace* /opt/solr /opt/tomcat'"

provider-ssh: ## SSH into the configured host
	@echo "Connecting to $(SSH_HOST):$(SSH_PORT)..."
	@ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST)

provider-exec: ## Run REMOTE_CMD on the host over SSH (e.g. REMOTE_CMD="uptime")
	@if [ -z "$(REMOTE_CMD)" ]; then echo "❌ REMOTE_CMD is required"; exit 1; fi
	@ssh -t -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "$(REMOTE_CMD)"

provider-get-ip: ## Get IP address of the SSH host
	@echo $(SSH_HOST)

provider-status: ## Check status of the SSH host
	@echo "SSH Provider Status:"
	@echo "📍 Host: $(SSH_HOST):$(SSH_PORT)"
	@echo "👤 User: $(SSH_USER)"
	@if ssh -o ConnectTimeout=2 -o BatchMode=yes -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) exit 2>/dev/null; then \
		echo "✅ SSH: Connected"; \
		ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "echo '🖥️  Hostname:' \$$(hostname)"; \
		ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "echo '🐧 OS:' \$$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2)"; \
		ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "echo '💾 Memory:' \$$(free -h | grep Mem | awk '{print \$$2}')"; \
		ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "echo '💻 CPUs:' \$$(nproc)"; \
	else \
		echo "❌ SSH: Not accessible"; \
		echo ""; \
		echo "Troubleshooting:"; \
		echo "  1. Check network connectivity: ping $(SSH_HOST)"; \
		echo "  2. Check SSH service: nc -zv $(SSH_HOST) $(SSH_PORT)"; \
		echo "  3. Check credentials: ssh -v $(SSH_USER)@$(SSH_HOST)"; \
	fi

provider-copy-ssh-key: ## Copy SSH key to SSH host
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@echo "📝 Copying SSH key to $(SSH_HOST)..."
	@echo "You will be prompted for the password of $(SSH_USER)@$(SSH_HOST)"
	@ssh-copy-id -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST)
	@echo "✅ SSH key copied successfully"

provider-install-deps: ## Check SSH client dependencies
	@echo "📦 Checking SSH client..."
	@if command -v ssh &> /dev/null; then \
		echo "✅ SSH client installed"; \
		ssh -V; \
	else \
		echo "❌ SSH client not found. Please install OpenSSH client."; \
		exit 1; \
	fi
	@if command -v ssh-copy-id &> /dev/null; then \
		echo "✅ ssh-copy-id available"; \
	else \
		echo "⚠️  ssh-copy-id not found. Manual key copying may be required."; \
	fi

# SSH-specific helper targets
check-sudo: ## Check if user has sudo privileges on the host
	@echo "🔍 Checking sudo privileges on $(SSH_HOST)..."
	@if ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "sudo -n true 2>/dev/null"; then \
		echo "✅ User $(SSH_USER) has passwordless sudo"; \
	else \
		if ssh -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "sudo -v 2>/dev/null"; then \
			echo "⚠️  User $(SSH_USER) has sudo (password required)"; \
		else \
			echo "❌ User $(SSH_USER) does not have sudo privileges"; \
			echo "   DSpace installation will require sudo access"; \
			exit 1; \
		fi; \
	fi

test-connection: ## Test SSH connection and gather host info
	@echo "Testing connection to $(SSH_HOST):$(SSH_PORT)..."
	@ssh -o ConnectTimeout=5 -p $(SSH_PORT) $(SSH_USER)@$(SSH_HOST) "\
		echo '===== Host Information ====='; \
		echo 'Hostname:' \$$(hostname -f); \
		echo 'OS:' \$$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'\"' -f2); \
		echo 'Kernel:' \$$(uname -r); \
		echo 'Architecture:' \$$(uname -m); \
		echo 'CPUs:' \$$(nproc); \
		echo 'Memory:' \$$(free -h | grep Mem | awk '{print \$$2}'); \
		echo 'Disk:' \$$(df -h / | tail -1 | awk '{print \$$4 \" available\"}'); \
		echo '==========================='"