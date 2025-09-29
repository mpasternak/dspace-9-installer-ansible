# VM Configuration
VM_NAME := dspace-server

.PHONY: help configure-developer-machine update-apt ssh ssh-copy-id install-prerequisites install-dspace install-dspace-all dspace-version dspace-github

help: ## Display all targets in this Makefile
	@echo "Available targets:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}'
	@echo ""
	@echo "Usage: make <target>"

configure-developer-machine: ## Install Homebrew, Tart, and DSpace VM
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Configuring Developer Machine                    ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
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
	@# Install pipx if not already installed
	@if ! command -v pipx &> /dev/null; then \
		echo "📦 Installing pipx..."; \
		brew install pipx; \
		pipx ensurepath; \
	else \
		echo "✅ pipx already installed"; \
	fi
	@# Install Ansible via pipx if not already installed
	@if ! command -v ansible &> /dev/null; then \
		echo "📦 Installing Ansible..."; \
		pipx install --include-deps ansible; \
	else \
		echo "✅ Ansible already installed"; \
	fi
	@# Build VM using the build-vm target
	@$(MAKE) build-vm
	@# Display results
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║                 Configuration Complete!                  ║"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@echo "║ VM Status: Running                                       ║"
	@printf "║ VM IP Address: %-42s║\n" "$$(tart ip $(VM_NAME))"
	@printf "║ SSH Command: ssh admin@%-34s║\n" "$$(tart ip $(VM_NAME))"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@echo "║ Next Steps:                                              ║"
	@echo "║ • Run 'make update-apt' to update the VM packages        ║"
	@echo "║ • Use 'tart stop $(VM_NAME)' to stop the VM                  ║"
	@echo "║ • Use 'tart list' to see all VMs                         ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""

build-vm: ## Build and configure DSpace VM from scratch
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Building DSpace VM                             ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Check if VM already exists
	@if tart list | grep -q "$(VM_NAME)"; then \
		echo "⚠️  DSpace VM already exists"; \
		echo "💡 Run 'make destroy-vm' first to remove it, then 'make build-vm' to recreate"; \
		exit 1; \
	fi
	@# Clone Ubuntu image
	@echo "🔄 Cloning Ubuntu image..."
	@tart clone ghcr.io/cirruslabs/ubuntu:latest $(VM_NAME)
	@echo "✅ DSpace VM created"
	@# Get the number of CPUs on the host machine and configure VM resources
	@HOST_CPUS=$$(sysctl -n hw.ncpu); \
	HOST_CPUS=$$(echo "$$HOST_CPUS / 2" | bc); \
	echo "🔧 Configuring VM resources:"; \
	echo "   • CPUs: $$HOST_CPUS (half of the host)"; \
	tart set $(VM_NAME) --cpu $$HOST_CPUS
	@# Start the VM
	@echo "🚀 Starting DSpace VM..."
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
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@echo "📝 Copying SSH key to VM (default password: admin)..."
	@if ! command -v sshpass &> /dev/null; then \
		echo "⚠️  sshpass not found, installing..."; \
		brew install hudochenkov/sshpass/sshpass; \
	fi
	@echo "admin" | sshpass -p admin ssh-copy-id -o StrictHostKeyChecking=no admin@$$(tart ip $(VM_NAME))
	@echo "✅ SSH key copied successfully"
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║                  VM Build Complete                       ║"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@printf "║ VM IP Address: %-42s║\n" "$$(tart ip $(VM_NAME))"
	@printf "║ SSH Command: ssh admin@%-34s║\n" "$$(tart ip $(VM_NAME))"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@echo "║ Next Steps:                                              ║"
	@echo "║ • Run 'make update-apt' to update the VM packages        ║"
	@echo "║ • Run 'make install-prerequisites' to install DSpace deps║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""

start-vm: ## Start the DSpace VM
	@echo "🚀 Starting DSpace VM..."
	@if ! tart list | grep -q "$(VM_NAME)"; then \
		echo "❌ VM does not exist. Run 'make build-vm' first"; \
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

stop-vm: ## Stop the DSpace VM
	@echo "⏹️  Stopping DSpace VM..."
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

update-apt: ## Update apt packages on DSpace VM using Ansible
	@echo "Updating apt packages on DSpace VM..."
	@echo "Running Ansible playbook..."
	@cd ansible && ansible-playbook -v update-system.yml

ssh: ## SSH into the DSpace VM
	@echo "Connecting to DSpace VM..."
	@ssh admin@$$(tart ip $(VM_NAME))

ssh-copy-id: ## Copy SSH key to DSpace VM (standalone target)
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@echo "📝 Copying SSH key to VM (default password: admin)..."
	@echo "admin" | sshpass -p admin ssh-copy-id -o StrictHostKeyChecking=no admin@$$(tart ip $(VM_NAME)) 2>/dev/null || \
	(echo "⚠️  sshpass not found, installing..."; brew install hudochenkov/sshpass/sshpass; \
	echo "admin" | sshpass -p admin ssh-copy-id -o StrictHostKeyChecking=no admin@$$(tart ip $(VM_NAME)))
	@echo "✅ SSH key copied successfully"

install-prerequisites: ## Install DSpace prerequisites (Java, PostgreSQL, Solr, Tomcat)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        Installing DSpace Prerequisites                   ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installing Java, PostgreSQL, Solr, and Tomcat..."
	@cd ansible && ansible-playbook -v install-prerequisites.yml
	@echo ""
	@echo "✅ Prerequisites installation complete!"

install-dspace: ## Install DSpace backend application (all steps)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║          Installing DSpace Backend                       ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Installing DSpace..."
	@cd ansible && ansible-playbook -v install-dspace.yml
	@echo ""
	@echo "✅ DSpace installation complete!"

dspace-download: ## Download DSpace source code only
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║          Downloading DSpace Source                       ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📥 Downloading DSpace source code..."
	@cd ansible && ansible-playbook -v dspace-download.yml
	@echo ""
	@echo "✅ DSpace download complete!"

dspace-build: ## Build DSpace with Maven and Ant only
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║            Building DSpace                               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔨 Building DSpace with Maven and Ant..."
	@cd ansible && ansible-playbook -v dspace-build.yml
	@echo ""
	@echo "✅ DSpace build complete!"

dspace-install-only: ## Install and configure DSpace (skip download/build)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║      Installing DSpace (from built sources)              ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installing DSpace from built sources..."
	@cd ansible && ansible-playbook -v dspace-install-only.yml
	@echo ""
	@echo "✅ DSpace installation complete!"

dspace-rebuild: ## Rebuild and reinstall DSpace (skip download)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Rebuilding and Reinstalling DSpace               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔄 Rebuilding and reinstalling DSpace..."
	@cd ansible && ansible-playbook -v dspace-build.yml && ansible-playbook -v dspace-install-only.yml
	@echo ""
	@echo "✅ DSpace rebuild complete!"

install-dspace-all: ## Install prerequisites and DSpace in one command
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║      Complete DSpace Installation                        ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@$(MAKE) install-prerequisites
	@$(MAKE) install-dspace
	@echo ""
	@echo "🎉 Complete DSpace stack installed successfully!"

dspace-version: ## Install specific DSpace version (usage: make dspace-version VERSION=9.1)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION (e.g., make dspace-version VERSION=9.1)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace version $(VERSION)..."
	@cd ansible && ansible-playbook -v playbooks/install-dspace.yml -e "dspace_version=$(VERSION)"

dspace-github: ## Install DSpace from GitHub branch (usage: make dspace-github BRANCH=main)
	@if [ -z "$(BRANCH)" ]; then \
		echo "❌ Please specify BRANCH (e.g., make dspace-github BRANCH=main)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace from GitHub branch $(BRANCH)..."
	@cd ansible && ansible-playbook -v playbooks/install-dspace.yml -e "dspace_source_type=github" -e "dspace_github_branch=$(BRANCH)"

vm-status: ## Check the status of the DSpace VM and services
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║                    VM Status                             ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@if tart ip $(VM_NAME) 2>/dev/null; then \
		echo "✅ VM Status: Running"; \
		echo "📍 IP Address: $$(tart ip $(VM_NAME))"; \
		echo ""; \
		echo "Checking services on VM..."; \
		ssh admin@$$(tart ip $(VM_NAME)) "sudo systemctl status postgresql --no-pager | head -3" 2>/dev/null || true; \
		ssh admin@$$(tart ip $(VM_NAME)) "sudo systemctl status solr --no-pager | head -3" 2>/dev/null || true; \
		ssh admin@$$(tart ip $(VM_NAME)) "sudo systemctl status tomcat --no-pager | head -3" 2>/dev/null || true; \
	else \
		echo "❌ VM Status: Not Running"; \
		echo "💡 Run 'make configure-developer-machine' to start the VM"; \
	fi
	@echo ""

destroy-vm: ## Stop and delete the DSpace VM for a clean restart
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Destroying DSpace VM                        ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Check if VM exists
	@if tart list | grep -q "$(VM_NAME)"; then \
		echo "🔍 Found DSpace VM"; \
		echo "⚠️  WARNING: This will permanently delete the VM and all its data!"; \
		read -p "Are you sure you want to destroy the VM? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ] || [ "$$confirm" = "y" ]; then \
			VM_IP=$$(tart ip $(VM_NAME) 2>/dev/null || echo ""); \
			if [ -n "$$VM_IP" ]; then \
				echo "📍 VM IP address: $$VM_IP"; \
				echo "⏹️  Stopping DSpace VM..."; \
				tart stop $(VM_NAME); \
				sleep 2; \
			else \
				echo "ℹ️  VM is not running"; \
			fi; \
			echo "🗑️  Deleting DSpace VM..."; \
			tart delete $(VM_NAME); \
			if [ -n "$$VM_IP" ]; then \
				echo "🔑 Removing SSH host key for $$VM_IP..."; \
				ssh-keygen -R "$$VM_IP" 2>/dev/null || true; \
				echo "✅ SSH host key removed"; \
			fi; \
			echo "✅ VM destroyed successfully"; \
		else \
			echo "❌ Destruction cancelled"; \
		fi; \
	else \
		echo "ℹ️  No DSpace VM found to destroy"; \
	fi
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║               VM Cleanup Complete                        ║"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@echo "║ To create a fresh VM, run:                               ║"
	@echo "║   make build-vm                                          ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
