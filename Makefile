# DSpace 9 Installer - Main Makefile
# Provider-agnostic orchestration for DSpace installation

# Include configuration (provider selection and common variables)
include config.mk

.PHONY: help info configure-developer-machine build-vm start-vm stop-vm destroy-vm ssh ssh-copy-id vm-status
.PHONY: update-apt install-prerequisites install-dspace install-dspace-all
.PHONY: dspace-download dspace-build dspace-install-only dspace-rebuild
.PHONY: dspace-version dspace-github clean

# Default target
.DEFAULT_GOAL := help

help: ## Display all targets in this Makefile
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           DSpace 9 Installer - Help                      ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Current Provider: $(PROVIDER)"
	@echo ""
	@echo "Available targets:"
	@echo ""
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  %-30s %s\n", $$1, $$2}' | sort
	@echo ""
	@echo "Usage examples:"
	@echo "  make build-vm                    # Build VM with default provider ($(PROVIDER))"
	@echo "  PROVIDER=vagrant make build-vm   # Build VM with Vagrant"
	@echo "  PROVIDER=ssh SSH_HOST=192.168.1.100 make configure-host"
	@echo ""
	@echo "To change default provider, edit config.mk"

info: ## Show current configuration
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Current Configuration                          ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Provider: $(PROVIDER)"
	@echo "VM/Host Name: $(VM_NAME)"
	@echo "SSH User: $(SSH_USER)"
	@echo "Ansible Inventory: $(ANSIBLE_INVENTORY)"
	@echo ""
	@$(MAKE) provider-status

# VM/Host Management (delegates to provider)
configure-developer-machine: ## Configure developer machine and initialize VM/host
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Configuring Developer Machine                    ║"
	@echo "║         Provider: $(PROVIDER)                            ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Install common dependencies
	@if ! command -v pipx &> /dev/null; then \
		if command -v brew &> /dev/null; then \
			echo "📦 Installing pipx via Homebrew..."; \
			brew install pipx; \
			pipx ensurepath; \
		elif command -v apt-get &> /dev/null; then \
			echo "📦 Installing pipx via apt..."; \
			sudo apt-get update && sudo apt-get install -y pipx; \
		else \
			echo "📦 Installing pipx via pip..."; \
			python3 -m pip install --user pipx; \
		fi; \
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
	@# Install provider-specific dependencies
	@$(MAKE) provider-install-deps
	@# Initialize the VM/host
	@$(MAKE) build-vm
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║                 Configuration Complete!                  ║"
	@echo "╠══════════════════════════════════════════════════════════╣"
	@echo "║ Provider: $(PROVIDER)                                    ║"
	@echo "║ Next Steps:                                              ║"
	@echo "║ • Run 'make install-prerequisites' for DSpace deps       ║"
	@echo "║ • Run 'make install-dspace' to install DSpace            ║"
	@echo "╚══════════════════════════════════════════════════════════╝"

build-vm: ## Build/Initialize VM or configure host (provider-specific)
	@$(MAKE) provider-init
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Updating System Packages                         ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Running system updates (this may take a few minutes)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) update-system.yml
	@echo "✅ System updates complete!"

configure-host: build-vm ## Alias for build-vm when using SSH provider

start-vm: ## Start the VM (provider-specific)
	@$(MAKE) provider-start

stop-vm: ## Stop the VM (provider-specific)
	@$(MAKE) provider-stop

destroy-vm: ## Destroy the VM (provider-specific)
	@$(MAKE) provider-destroy

ssh: ## SSH into the VM/host
	@$(MAKE) provider-ssh

ssh-copy-id: ## Copy SSH key to VM/host
	@$(MAKE) provider-copy-ssh-key

vm-status: ## Check VM/host status
	@$(MAKE) provider-status

# DSpace Installation Tasks (provider-agnostic)
update-apt: ## Update apt packages on target system
	@echo "Updating apt packages..."
	@echo "Running Ansible playbook..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) update-system.yml

install-prerequisites: ## Install DSpace prerequisites (Java, PostgreSQL, Solr, Tomcat)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        Installing DSpace Prerequisites                   ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installing Java, PostgreSQL, Solr, and Tomcat..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-prerequisites.yml
	@echo ""
	@echo "✅ Prerequisites installation complete!"

install-dspace: ## Install DSpace backend application (all steps)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║          Installing DSpace Backend                       ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Installing DSpace..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-dspace.yml
	@echo ""
	@echo "✅ DSpace installation complete!"

dspace-download: ## Download DSpace source code only
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║          Downloading DSpace Source                       ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📥 Downloading DSpace source code..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) dspace-download.yml
	@echo ""
	@echo "✅ DSpace download complete!"

dspace-build: ## Build DSpace with Maven and Ant only
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║            Building DSpace                               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔨 Building DSpace with Maven and Ant..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) dspace-build.yml
	@echo ""
	@echo "✅ DSpace build complete!"

dspace-install-only: ## Install and configure DSpace (skip download/build)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║      Installing DSpace (from built sources)              ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 Installing DSpace from built sources..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) dspace-install-only.yml
	@echo ""
	@echo "✅ DSpace installation complete!"

dspace-rebuild: ## Rebuild and reinstall DSpace (skip download)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Rebuilding and Reinstalling DSpace               ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔄 Rebuilding and reinstalling DSpace..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) dspace-build.yml && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) dspace-install-only.yml
	@echo ""
	@echo "✅ DSpace rebuild complete!"

install-dspace-all: ## Install prerequisites and DSpace backend in one command
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║      Complete DSpace Backend Installation                 ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@$(MAKE) install-prerequisites
	@$(MAKE) install-dspace
	@echo ""
	@echo "🎉 Complete DSpace backend stack installed successfully!"

dspace-version: ## Install specific DSpace version (usage: make dspace-version VERSION=9.1)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION (e.g., make dspace-version VERSION=9.1)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace version $(VERSION)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-dspace.yml \
		-e "dspace_version=$(VERSION)"

dspace-github: ## Install DSpace from GitHub branch (usage: make dspace-github BRANCH=main)
	@if [ -z "$(BRANCH)" ]; then \
		echo "❌ Please specify BRANCH (e.g., make dspace-github BRANCH=main)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace from GitHub branch $(BRANCH)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-dspace.yml \
		-e "dspace_source_type=github" -e "dspace_github_branch=$(BRANCH)"

# Frontend targets
install-frontend: ## Install DSpace Angular frontend with Node.js and PM2
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        Installing DSpace Frontend (Angular UI)           ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Installing DSpace Angular frontend..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend.yml
	@echo ""
	@echo "✅ DSpace frontend installation complete!"

frontend-restart: ## Restart DSpace frontend (PM2 process)
	@echo "🔄 Restarting DSpace frontend..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo -u dspace pm2 restart dspace-ui" --become
	@echo "✅ Frontend restarted"

frontend-logs: ## View DSpace frontend PM2 logs
	@echo "📋 Viewing DSpace frontend logs (Ctrl+C to exit)..."
	@$(MAKE) provider-ssh -- "sudo -u dspace pm2 logs dspace-ui --lines 100"

frontend-status: ## Check DSpace frontend status
	@echo "📊 Checking DSpace frontend status..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo -u dspace pm2 status" --become

install-complete: ## Complete installation: backend + frontend + nginx
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║      Complete DSpace Stack Installation                  ║"
	@echo "║      (Backend + Frontend + Nginx)                        ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@$(MAKE) install-prerequisites
	@$(MAKE) install-dspace
	@$(MAKE) install-frontend
	@echo ""
	@echo "🎉 Complete DSpace stack with frontend installed successfully!"
	@echo ""
	@echo "📌 Access your DSpace installation:"
	@echo "   Frontend UI: http://$(VM_NAME)/"
	@echo "   Backend API: http://$(VM_NAME)/server/api"
	@echo ""

frontend-version: ## Install specific frontend version (usage: make frontend-version VERSION=9.1)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION (e.g., make frontend-version VERSION=9.1)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace frontend version $(VERSION)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend.yml \
		-e "dspace_frontend_version=$(VERSION)"

frontend-github: ## Install frontend from GitHub branch (usage: make frontend-github BRANCH=main)
	@if [ -z "$(BRANCH)" ]; then \
		echo "❌ Please specify BRANCH (e.g., make frontend-github BRANCH=main)"; \
		exit 1; \
	fi
	@echo "📦 Installing DSpace frontend from GitHub branch $(BRANCH)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend.yml \
		-e "dspace_frontend_source_type=github" -e "dspace_frontend_github_branch=$(BRANCH)"

# Utility targets
check-services: ## Check status of all DSpace services
	@echo "Checking DSpace services on target..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo systemctl status postgresql tomcat solr --no-pager | head -n 3"

tail-logs: ## Tail DSpace logs
	@echo "Tailing DSpace logs..."
	@$(MAKE) provider-ssh -- "sudo tail -f /opt/dspace/log/dspace.log"

clean-logs: ## Clean DSpace logs
	@echo "Cleaning DSpace logs..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo truncate -s 0 /opt/dspace/log/*.log"

backup-db: ## Backup DSpace database
	@echo "Creating database backup..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo -u postgres pg_dump dspace | gzip > /tmp/dspace-backup-$$(date +%Y%m%d-%H%M%S).sql.gz && ls -lh /tmp/dspace-backup-*.sql.gz | tail -1"

clean: ## Remove Emacs backup files (*~, #*#, .#*)
	@echo "Cleaning Emacs backup files..."
	@find . -type f -name '*~' -delete 2>/dev/null || true
	@find . -type f -name '#*#' -delete 2>/dev/null || true
	@find . -type f -name '.#*' -delete 2>/dev/null || true
	@echo "✅ Emacs backup files removed"