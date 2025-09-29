# Tart Provider Implementation
# This file contains all Tart-specific operations

# Tart-specific variables
TART_IMAGE ?= ghcr.io/cirruslabs/ubuntu:latest
VM_CPUS ?= $(shell echo "$$(sysctl -n hw.ncpu) / 2" | bc)

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key

provider-init: ## Initialize Tart VM
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Initializing Tart VM                           ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Check if VM already exists
	@if tart list | grep -q "$(VM_NAME)"; then \
		echo "⚠️  VM '$(VM_NAME)' already exists"; \
		echo "💡 Run 'make provider-destroy' first to remove it, then 'make provider-init' to recreate"; \
		exit 1; \
	fi
	@# Clone Ubuntu image
	@echo "🔄 Cloning Ubuntu image..."
	@tart clone $(TART_IMAGE) $(VM_NAME)
	@echo "✅ VM created"
	@# Configure VM resources
	@echo "🔧 Configuring VM with $(VM_CPUS) CPUs..."
	@tart set $(VM_NAME) --cpu $(VM_CPUS)
	@# Start the VM
	@echo "🚀 Starting VM..."
	@tart run $(VM_NAME) &
	@echo "⏳ Waiting for VM to start..."
	@sleep 10
	@while ! tart ip $(VM_NAME) 2>/dev/null; do \
		echo "⏳ Waiting for VM IP..."; \
		sleep 2; \
	done
	@echo "✅ VM started successfully"
	@echo "📍 IP Address: $$(tart ip $(VM_NAME))"
	@# Setup SSH key authentication
	@$(MAKE) -f providers/tart.mk provider-copy-ssh-key

provider-start: ## Start the Tart VM
	@echo "🚀 Starting VM '$(VM_NAME)'..."
	@if ! tart list | grep -q "$(VM_NAME)"; then \
		echo "❌ VM does not exist. Run 'make provider-init' first"; \
		exit 1; \
	fi
	@if tart ip $(VM_NAME) 2>/dev/null; then \
		echo "✅ VM is already running at $$(tart ip $(VM_NAME))"; \
	else \
		tart run --no-graphics $(VM_NAME) & \
		sleep 5; \
		while ! tart ip $(VM_NAME) 2>/dev/null; do \
			sleep 2; \
		done; \
		echo "✅ VM started at $$(tart ip $(VM_NAME))"; \
	fi

provider-stop: ## Stop the Tart VM
	@echo "⏹️  Stopping VM '$(VM_NAME)'..."
	@if tart list | grep -q "$(VM_NAME)"; then \
		if tart ip $(VM_NAME) 2>/dev/null; then \
			tart stop $(VM_NAME); \
			echo "✅ VM stopped"; \
		else \
			echo "ℹ️  VM is not running"; \
		fi; \
	else \
		echo "❌ VM does not exist"; \
	fi

provider-destroy: ## Destroy the Tart VM
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Destroying Tart VM                          ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@if tart list | grep -q "$(VM_NAME)"; then \
		echo "🔍 Found VM '$(VM_NAME)'"; \
		echo "⚠️  WARNING: This will permanently delete the VM and all its data!"; \
		read -p "Are you sure you want to destroy the VM? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ] || [ "$$confirm" = "y" ]; then \
			VM_IP=$$(tart ip $(VM_NAME) 2>/dev/null || echo ""); \
			if [ -n "$$VM_IP" ]; then \
				echo "⏹️  Stopping VM..."; \
				tart stop $(VM_NAME); \
				sleep 2; \
			fi; \
			echo "🗑️  Deleting VM..."; \
			tart delete $(VM_NAME); \
			if [ -n "$$VM_IP" ]; then \
				echo "🔑 Removing SSH host key..."; \
				ssh-keygen -R "$$VM_IP" 2>/dev/null || true; \
			fi; \
			echo "✅ VM destroyed successfully"; \
		else \
			echo "❌ Destruction cancelled"; \
		fi; \
	else \
		echo "ℹ️  No VM found to destroy"; \
	fi

provider-ssh: ## SSH into the Tart VM
	@echo "Connecting to VM '$(VM_NAME)'..."
	@ssh $(SSH_USER)@$$(tart ip $(VM_NAME))

provider-get-ip: ## Get IP address of the Tart VM
	@tart ip $(VM_NAME) 2>/dev/null || (echo "VM not running" >&2; exit 1)

provider-status: ## Check status of the Tart VM
	@echo "Tart Provider Status:"
	@if tart list | grep -q "$(VM_NAME)"; then \
		if IP=$$(tart ip $(VM_NAME) 2>/dev/null); then \
			echo "✅ VM: Running"; \
			echo "📍 IP: $$IP"; \
			if ssh -o ConnectTimeout=2 -o BatchMode=yes $(SSH_USER)@$$IP exit 2>/dev/null; then \
				echo "🔗 SSH: Connected"; \
			else \
				echo "❌ SSH: Not accessible"; \
			fi; \
		else \
			echo "⏸️  VM: Stopped"; \
		fi; \
	else \
		echo "❌ VM: Does not exist"; \
	fi

provider-copy-ssh-key: ## Copy SSH key to Tart VM
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@echo "📝 Copying SSH key to VM (default password: $(SSH_DEFAULT_PASSWORD))..."
	@if ! command -v sshpass &> /dev/null; then \
		echo "⚠️  sshpass not found, installing..."; \
		brew install hudochenkov/sshpass/sshpass; \
	fi
	@echo "$(SSH_DEFAULT_PASSWORD)" | sshpass -p $(SSH_DEFAULT_PASSWORD) ssh-copy-id -o StrictHostKeyChecking=no $(SSH_USER)@$$(tart ip $(VM_NAME))
	@echo "✅ SSH key copied successfully"

provider-install-deps: ## Install Tart dependencies on macOS
	@echo "📦 Installing Tart dependencies..."
	@# Install Homebrew if not already installed
	@if ! command -v brew &> /dev/null; then \
		echo "📦 Installing Homebrew..."; \
		/bin/bash -c "$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; \
	else \
		echo "✅ Homebrew already installed"; \
	fi
	@# Install Tart via Homebrew if not already installed
	@if ! command -v tart &> /dev/null; then \
		echo "📦 Installing Tart..."; \
		brew install cirruslabs/cli/tart; \
	else \
		echo "✅ Tart already installed"; \
	fi