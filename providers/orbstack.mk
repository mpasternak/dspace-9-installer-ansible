# OrbStack Provider Implementation
# This file contains all OrbStack-specific operations.
# OrbStack runs lightweight Linux machines on macOS (https://orbstack.dev).
#
# Machines are managed with `orbctl` (alias `orb`) and reached over SSH via
# OrbStack's auto-generated 'orb' host: `ssh <machine>@orb`. OrbStack manages
# SSH keys and shares host resources dynamically, so there is no key-copy step
# and no CPU/RAM/disk sizing step.

# OrbStack-specific variables
ORBSTACK_IMAGE ?= ubuntu:noble

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key provider-install-deps

provider-init: ## Initialize OrbStack Linux machine
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Initializing OrbStack Machine                  ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Check if machine already exists
	@if orbctl list -q 2>/dev/null | grep -qx "$(VM_NAME)"; then \
		echo "⚠️  Machine '$(VM_NAME)' already exists"; \
		echo "💡 Run 'make destroy-vm' first to remove it, then 'make build-vm' to recreate"; \
		exit 1; \
	fi
	@echo "🔄 Creating machine '$(VM_NAME)' from $(ORBSTACK_IMAGE)..."
	@orbctl create $(ORBSTACK_IMAGE) $(VM_NAME)
	@echo "⏳ Waiting for machine to be running..."
	@for i in $$(seq 1 30); do \
		STATUS=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$2}'); \
		if [ "$$STATUS" = "running" ]; then break; fi; \
		sleep 1; \
	done
	@STATUS=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$2}'); \
	if [ "$$STATUS" != "running" ]; then \
		echo "❌ Machine did not reach 'running' state (status: $$STATUS)"; \
		exit 1; \
	fi
	@echo "✅ Machine created and running"
	@echo "📍 IP Address: $$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$NF}')"
	@echo "🔐 OrbStack manages SSH keys automatically (connect with: ssh $(VM_NAME)@orb)"

provider-start: ## Start the OrbStack machine
	@echo "🚀 Starting machine '$(VM_NAME)'..."
	@STATUS=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$2}'); \
	if [ -z "$$STATUS" ]; then \
		echo "❌ Machine does not exist. Run 'make build-vm' first"; \
		exit 1; \
	elif [ "$$STATUS" = "running" ]; then \
		echo "✅ Machine is already running"; \
	else \
		orbctl start $(VM_NAME); \
		echo "✅ Machine started"; \
	fi

provider-stop: ## Stop the OrbStack machine
	@echo "⏹️  Stopping machine '$(VM_NAME)'..."
	@STATUS=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$2}'); \
	if [ -z "$$STATUS" ]; then \
		echo "❌ Machine does not exist"; \
	elif [ "$$STATUS" != "running" ]; then \
		echo "ℹ️  Machine is not running (status: $$STATUS)"; \
	else \
		orbctl stop $(VM_NAME); \
		echo "✅ Machine stopped"; \
	fi

provider-destroy: ## Destroy the OrbStack machine
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Destroying OrbStack Machine                 ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@if orbctl list -q 2>/dev/null | grep -qx "$(VM_NAME)"; then \
		echo "🔍 Found machine '$(VM_NAME)'"; \
		echo "⚠️  WARNING: This will permanently delete the machine and all its data!"; \
		read -p "Are you sure you want to destroy the machine? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ] || [ "$$confirm" = "y" ]; then \
			echo "🗑️  Deleting machine..."; \
			orbctl delete $(VM_NAME); \
			echo "✅ Machine destroyed successfully"; \
		else \
			echo "❌ Destruction cancelled"; \
		fi; \
	else \
		echo "ℹ️  No machine found to destroy"; \
	fi

provider-ssh: ## SSH into the OrbStack machine
	@echo "Connecting to machine '$(VM_NAME)'..."
	@ssh $(VM_NAME)@orb

provider-exec: ## Run REMOTE_CMD on the machine over SSH (e.g. REMOTE_CMD="uptime")
	@if [ -z "$(REMOTE_CMD)" ]; then echo "❌ REMOTE_CMD is required"; exit 1; fi
	@ssh -t $(VM_NAME)@orb "$(REMOTE_CMD)"

provider-get-ip: ## Get IP address of the OrbStack machine
	@IP=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" && $$2 == "running" {print $$NF}'); \
	if [ -n "$$IP" ]; then \
		echo "$$IP"; \
	else \
		echo "Machine not running" >&2; \
		exit 1; \
	fi

provider-status: ## Check status of the OrbStack machine
	@echo "OrbStack Provider Status:"
	@STATUS=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$2}'); \
	if [ -z "$$STATUS" ]; then \
		echo "❌ Machine: Does not exist"; \
	elif [ "$$STATUS" != "running" ]; then \
		echo "⏸️  Machine: $$STATUS"; \
	else \
		echo "✅ Machine: Running"; \
		IP=$$(orbctl list 2>/dev/null | awk '$$1 == "$(VM_NAME)" {print $$NF}'); \
		echo "📍 IP: $$IP"; \
		if ssh -o ConnectTimeout=5 -o BatchMode=yes $(VM_NAME)@orb exit 2>/dev/null; then \
			echo "🔗 SSH: Connected"; \
		else \
			echo "❌ SSH: Not accessible"; \
		fi; \
	fi

provider-copy-ssh-key: ## (No-op) OrbStack manages SSH keys automatically
	@echo "🔐 OrbStack manages SSH keys automatically — no key copy needed."
	@echo "   Machines are reachable via: ssh $(VM_NAME)@orb"

provider-install-deps: ## Check OrbStack installation
	@echo "📦 Checking OrbStack installation..."
	@if ! command -v orbctl >/dev/null 2>&1; then \
		echo "❌ OrbStack not installed."; \
		echo "   Install via Homebrew: brew install orbstack"; \
		echo "   Or download from:     https://orbstack.dev"; \
		exit 1; \
	else \
		echo "✅ OrbStack installed"; \
		orbctl version 2>/dev/null | head -1; \
	fi
