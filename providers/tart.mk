# Tart Provider Implementation
# This file contains all Tart-specific operations

# Tart-specific variables
TART_IMAGE ?= ghcr.io/cirruslabs/ubuntu:latest
VM_CPUS ?= $(shell echo "$$(sysctl -n hw.ncpu) / 2" | bc)

# Get domain_name from Ansible configuration
DOMAIN_NAME := $(shell grep '^domain_name:' ansible/group_vars/all.yml | awk '{print $$2}' | tr -d '"')
HOSTS_COMMENT := \# Managed by dspace-9-installer

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key
.PHONY: hosts-add hosts-remove hosts-check

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
	@echo "🔧 Configuring VM with $(VM_CPUS) CPUs, 8GB RAM, and 30GB disk..."
	@tart set $(VM_NAME) --cpu $(VM_CPUS) --memory 8192 --disk-size 30
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
	@$(MAKE) provider-copy-ssh-key
	@# Add to /etc/hosts
	@echo ""
	@echo "🔧 Configuring /etc/hosts..."
	@$(MAKE) hosts-add

provider-start: ## Start the Tart VM
	@echo "🚀 Starting VM '$(VM_NAME)'..."
	@# Check if VM exists and get its status
	@VM_STATUS=$$(tart list 2>/dev/null | awk '$$2 == "$(VM_NAME)" {print $$6}'); \
	if [ -z "$$VM_STATUS" ]; then \
		echo "❌ VM does not exist. Run 'make provider-init' first"; \
		exit 1; \
	fi; \
	if [ "$$VM_STATUS" != "stopped" ]; then \
		echo "✅ VM is already running at $$(tart ip $(VM_NAME))"; \
	else \
		tart run $(VM_NAME) & \
		sleep 5; \
		while [ "$$(tart list 2>/dev/null | awk '$$2 == "$(VM_NAME)" {print $$6}')" = "stopped" ]; do \
			sleep 2; \
		done; \
		echo "✅ VM started at $$(tart ip $(VM_NAME))"; \
	fi

provider-stop: ## Stop the Tart VM
	@echo "⏹️  Stopping VM '$(VM_NAME)'..."
	@VM_STATUS=$$(tart list 2>/dev/null | awk '$$2 == "$(VM_NAME)" {print $$6}'); \
	if [ -z "$$VM_STATUS" ]; then \
		echo "❌ VM does not exist"; \
	elif [ "$$VM_STATUS" = "stopped" ]; then \
		echo "ℹ️  VM is not running"; \
	else \
		tart stop $(VM_NAME); \
		echo "✅ VM stopped"; \
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
			echo "🔧 Removing /etc/hosts entry..."; \
			$(MAKE) hosts-remove; \
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
	@VM_STATUS=$$(tart list 2>/dev/null | awk '$$2 == "$(VM_NAME)" {print $$6}'); \
	if [ -z "$$VM_STATUS" ]; then \
		echo "❌ VM: Does not exist"; \
	elif [ "$$VM_STATUS" = "stopped" ]; then \
		echo "⏸️  VM: Stopped"; \
	else \
		echo "✅ VM: Running"; \
		IP=$$(tart ip $(VM_NAME) 2>/dev/null); \
		echo "📍 IP: $$IP"; \
		if ssh -o ConnectTimeout=2 -o BatchMode=yes $(SSH_USER)@$$IP exit 2>/dev/null; then \
			echo "🔗 SSH: Connected"; \
		else \
			echo "❌ SSH: Not accessible"; \
		fi; \
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
	@VM_IP=$$(tart ip $(VM_NAME)) && \
		sshpass -p "$(SSH_DEFAULT_PASSWORD)" ssh-copy-id -o StrictHostKeyChecking=no $(SSH_USER)@$$VM_IP
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

# Hosts file management targets
hosts-add: ## Add VM IP to /etc/hosts
	@if [ -z "$(DOMAIN_NAME)" ]; then \
		echo "❌ domain_name not found in ansible/group_vars/all.yml"; \
		exit 1; \
	fi
	@echo "🔍 Getting VM IP address..."
	@VM_IP=$$(tart ip $(VM_NAME) 2>/dev/null); \
	if [ -z "$$VM_IP" ]; then \
		echo "❌ VM is not running or IP not available"; \
		exit 1; \
	fi; \
	echo "📝 Adding/updating hosts entry: $$VM_IP $(DOMAIN_NAME)"; \
	if grep -q "$(DOMAIN_NAME)" /etc/hosts; then \
		echo "⚠️  Entry for $(DOMAIN_NAME) already exists in /etc/hosts"; \
		echo "🔄 Updating existing entry..."; \
		sudo sed -i.bak "/$(DOMAIN_NAME)/d" /etc/hosts; \
	fi; \
	echo "$$VM_IP $(DOMAIN_NAME) # Managed by dspace-9-installer" | sudo tee -a /etc/hosts > /dev/null; \
	echo "✅ Hosts file updated successfully"; \
	echo "📌 You can now access DSpace at: http://$(DOMAIN_NAME)"

hosts-remove: ## Remove VM IP from /etc/hosts
	@if [ -z "$(DOMAIN_NAME)" ]; then \
		echo "❌ domain_name not found in ansible/group_vars/all.yml"; \
		exit 1; \
	fi
	@echo "🗑️  Removing hosts entry for $(DOMAIN_NAME)..."
	@if grep -q "$(DOMAIN_NAME)" /etc/hosts; then \
		sudo sed -i.bak "/$(DOMAIN_NAME).*Managed by dspace-9-installer/d" /etc/hosts; \
		echo "✅ Hosts entry removed"; \
	else \
		echo "ℹ️  No entry found for $(DOMAIN_NAME)"; \
	fi

hosts-check: ## Check current hosts file entry
	@if [ -z "$(DOMAIN_NAME)" ]; then \
		echo "❌ domain_name not found in ansible/group_vars/all.yml"; \
		exit 1; \
	fi
	@echo "🔍 Checking /etc/hosts for $(DOMAIN_NAME)..."
	@if grep -q "$(DOMAIN_NAME)" /etc/hosts; then \
		echo "✅ Found entry:"; \
		grep "$(DOMAIN_NAME)" /etc/hosts; \
		VM_IP=$$(tart ip $(VM_NAME) 2>/dev/null); \
		if [ -n "$$VM_IP" ]; then \
			echo "📍 Current VM IP: $$VM_IP"; \
			if grep -q "$$VM_IP.*$(DOMAIN_NAME)" /etc/hosts; then \
				echo "✅ Hosts entry is up to date"; \
			else \
				echo "⚠️  Hosts entry IP doesn't match current VM IP"; \
				echo "💡 Run 'make hosts-add' to update"; \
			fi; \
		fi; \
	else \
		echo "❌ No entry found for $(DOMAIN_NAME)"; \
		echo "💡 Run 'make hosts-add' to add it"; \
	fi
