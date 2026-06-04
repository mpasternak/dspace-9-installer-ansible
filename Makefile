# DSpace 9 Installer - Main Makefile
# Provider-agnostic orchestration for DSpace installation

# Include configuration (provider selection and common variables)
include config.mk

.PHONY: help info show-available-providers lint configure-developer-machine build-vm start-vm stop-vm destroy-vm ssh ssh-copy-id vm-status
.PHONY: hosts-add hosts-remove hosts-check
.PHONY: update-apt install-prerequisites install-dspace install-dspace-all set-access-url
.PHONY: migrate-plan migrate-from
.PHONY: dspace-download dspace-build dspace-install-only dspace-rebuild
.PHONY: dspace-version dspace-github clean
.PHONY: open-browser open-api open-solr _open-resolved provider-exec

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

show-available-providers: ## Show which providers are usable on THIS machine
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Available Providers (this machine)             ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@printf "  Host: %s\n\n" "$$(uname -srm)"
	@for p in tart orbstack vagrant ssh docker local-linux; do \
		ok=1; detail=""; \
		case $$p in \
		  tart)        if command -v tart    >/dev/null 2>&1; then detail="$$(command -v tart)"; else ok=0; detail="not installed (macOS native VMs)"; fi ;; \
		  orbstack)    if command -v orbctl  >/dev/null 2>&1; then detail="$$(command -v orbctl)"; else ok=0; detail="orbctl not installed — https://orbstack.dev"; fi ;; \
		  vagrant)     if command -v vagrant >/dev/null 2>&1; then detail="$$(command -v vagrant)"; else ok=0; detail="not installed"; fi ;; \
		  ssh)         if command -v ssh     >/dev/null 2>&1; then detail="ready — set SSH_HOST=<ip> (Ubuntu/Debian)"; else ok=0; detail="ssh client missing"; fi ;; \
		  docker)      if command -v docker  >/dev/null 2>&1; then \
		                 if docker info >/dev/null 2>&1; then detail="daemon running"; else ok=0; detail="installed, daemon not running"; fi; \
		               else ok=0; detail="not installed"; fi ;; \
		  local-linux) if [ "$$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then detail="this host (loopback)"; else ok=0; detail="needs a Debian/Ubuntu Linux host"; fi ;; \
		esac; \
		[ "$$p" = "$(PROVIDER)" ] && detail="$$detail  ← default"; \
		if [ $$ok -eq 1 ]; then icon="\033[32m✅\033[0m"; else icon="\033[31m❌\033[0m"; fi; \
		printf "  %b %-13s %s\n" "$$icon" "$$p" "$$detail"; \
	done
	@echo ""
	@echo "Use:  PROVIDER=<name> make <target>      (default: $(PROVIDER), change in config.mk)"

lint: ## Run ansible-lint on the playbooks/roles (profile: production)
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-lint --offline

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

# Browser access — open the running DSpace instance in your default browser.
# The host is resolved via the active provider (provider-get-ip), so these work
# across Tart, OrbStack, Vagrant, SSH and local-linux. Overridable:
#   make open-browser BROWSER_PATH=server/api   # frontend host, different path
#   make open-browser URL=http://1.2.3.4:8983/solr  # open an explicit URL
#   make open-solr SOLR_PORT=8984                # non-default Solr port
BROWSER_SCHEME ?= http
SOLR_PORT ?= 8983
BROWSER_PATH ?=

open-browser: ## Open the DSpace frontend in your default browser
	@$(MAKE) --no-print-directory _open-resolved OPEN_PATH="$(BROWSER_PATH)"

open-api: ## Open the DSpace backend API in your default browser
	@$(MAKE) --no-print-directory _open-resolved OPEN_PATH="server/"

open-solr: ## Open the Solr admin UI in your default browser
	@$(MAKE) --no-print-directory _open-resolved OPEN_PATH="solr/" OPEN_PORT="$(SOLR_PORT)"

# Internal: build "$(BROWSER_SCHEME)://<host>[:port]/<path>" from the active
# provider's IP (or use URL=... verbatim) and open it cross-platform.
_open-resolved:
	@URL="$(URL)"; \
	if [ -z "$$URL" ]; then \
		HOST=$$($(MAKE) -s provider-get-ip 2>/dev/null | tail -n1); \
		if [ -z "$$HOST" ]; then \
			echo "❌ Could not determine the target host — is the VM/host running?"; \
			echo "   Check with: make vm-status"; \
			exit 1; \
		fi; \
		PORT="$(OPEN_PORT)"; \
		if [ -n "$$PORT" ]; then PORT=":$$PORT"; fi; \
		URL="$(BROWSER_SCHEME)://$$HOST$$PORT/$(OPEN_PATH)"; \
	fi; \
	echo "🌐 Opening $$URL ..."; \
	if command -v open >/dev/null 2>&1; then open "$$URL"; \
	elif command -v xdg-open >/dev/null 2>&1; then xdg-open "$$URL"; \
	elif command -v wslview >/dev/null 2>&1; then wslview "$$URL"; \
	else \
		echo "⚠️  No browser opener found (open / xdg-open / wslview)."; \
		echo "   Please open this URL manually: $$URL"; \
	fi

# Hosts file management - delegates to provider if supported
# Currently only implemented for Tart provider

# DSpace Installation Tasks (provider-agnostic)
update-apt: ## Update apt packages on target system
	@echo "Updating apt packages..."
	@echo "Running Ansible playbook..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) update-system.yml

set-access-url: ## Set the public access URL (usage: make set-access-url URL=http://1.2.3.4)
	@if [ -z "$(URL)" ]; then \
		echo "❌ Please specify URL (e.g. make set-access-url URL=http://192.168.64.11)"; \
		echo "   Supports http/https, a hostname or IP, and an optional :port."; \
		exit 1; \
	fi
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Setting DSpace Access URL                   ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔧 Pointing backend + frontend at: $(URL)"
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) set-access-url.yml -e "access_url=$(URL)"
	@echo ""
	@echo "✅ Done. Open: $(URL)"
	@echo "   (Tomcat restarts ~30-60s, so the first page load may be slow.)"

migrate-plan: ## Show a migration plan from a legacy install on the host (EXISTING=/old/dspace)
	@if [ -z "$(EXISTING)" ]; then \
		echo "❌ Specify EXISTING=/path/to/legacy/dspace (e.g. make migrate-plan EXISTING=/opt/dspace-old)"; \
		exit 1; \
	fi
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) migrate-local.yml \
		-e "existing_dspace_dir=$(EXISTING)" -e "migrate_mode=plan"

migrate-from: ## Migrate a legacy install into this one (EXISTING=/old/dspace; opts: WITH_STATS=1 CONFIRM=yes START_AT="step")
	@if [ -z "$(EXISTING)" ]; then \
		echo "❌ Specify EXISTING=/path/to/legacy/dspace"; \
		echo "   Tip: run 'make migrate-plan EXISTING=...' first to preview."; \
		exit 1; \
	fi
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Migrating Legacy DSpace -> This Install          ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) migrate-local.yml \
		-e "existing_dspace_dir=$(EXISTING)" -e "migrate_mode=run" \
		$(if $(WITH_STATS),-e with_stats=true) \
		$(if $(filter yes,$(CONFIRM)),-e confirm=yes) \
		$(if $(START_AT),--start-at-task="$(START_AT)")

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

install-firefox: ## Install Firefox from Mozilla's official APT repository
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║             Installing Firefox                           ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🦊 Installing Firefox from Mozilla's official repository..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-firefox.yml
	@echo ""
	@echo "✅ Firefox installation complete!"

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

install-handles-server: ## (Optional) Install handles server for DSpace
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        Installing Handles Server (Optional)              ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🔗 Installing handles server for DSpace..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-handles-server.yml
	@echo ""
	@echo "✅ Handles server installation complete!"

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

dspace-version: ## Install specific DSpace version (usage: make dspace-version VERSION=9.3)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION (e.g., make dspace-version VERSION=9.3)"; \
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
install-frontend-prerequisites: ## Install frontend prerequisites (Node.js, PM2, build tools)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║       Installing Frontend Prerequisites                   ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend-prerequisites.yml
	@echo ""
	@echo "✅ Prerequisites installed successfully!"

install-frontend-download: ## Download and extract DSpace Angular source
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║       Downloading DSpace Angular Frontend                 ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend-download.yml
	@echo ""
	@echo "✅ Frontend source downloaded successfully!"

install-frontend-config: ## Configure DSpace Angular frontend
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║       Configuring DSpace Angular Frontend                 ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend-config.yml
	@echo ""
	@echo "✅ Frontend configured successfully!"

install-frontend-build: ## Build and deploy DSpace Angular frontend
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════════════════════════╗"
	@echo "║       Building DSpace Angular Frontend                                        ║"
	@echo "╚══════════════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "⚠️  This may take 10-15 minutes depending on your system..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend-build.yml
	@echo ""
	@echo "✅ Frontend built and deployed successfully!"

install-frontend: ## Install DSpace Angular frontend (runs all frontend steps)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        Installing DSpace Frontend (Angular UI)           ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "🚀 Installing DSpace Angular frontend (all steps)..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) install-frontend.yml
	@echo ""
	@echo "✅ DSpace frontend installation complete!"

frontend-restart: ## Restart DSpace frontend (PM2 process)
	@echo "🔄 Restarting DSpace frontend..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo -u dspaceui pm2 restart dspace-ui" --become
	@echo "✅ Frontend restarted"

# Initial number of log lines shown before following live (override: LINES=500)
LINES ?= 200
# Backend log file followed by tail-logs (override e.g. LOG_FILE=/var/log/tomcat/catalina.out)
LOG_FILE ?= /opt/dspace/log/dspace.log

frontend-logs: ## Follow DSpace frontend (PM2) logs live (Ctrl+C to stop)
	@echo "📋 Following DSpace frontend (PM2) logs — press Ctrl+C to stop..."
	@$(MAKE) provider-exec REMOTE_CMD="sudo -u dspaceui pm2 logs dspace-ui --lines $(LINES)" || true

frontend-status: ## Check DSpace frontend status
	@echo "📊 Checking DSpace frontend status..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo -u dspaceui pm2 status" --become

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

frontend-version: ## Install specific frontend version (usage: make frontend-version VERSION=9.3)
	@if [ -z "$(VERSION)" ]; then \
		echo "❌ Please specify VERSION (e.g., make frontend-version VERSION=9.3)"; \
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

# Frontend removal targets
remove-frontend: ## Remove DSpace frontend completely (including PM2 settings and frontend user)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║        WARNING: Removing DSpace Frontend                 ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "⚠️  This will completely remove:"
	@echo "   - PM2 processes and configuration"
	@echo "   - Systemd service (dspace-frontend)"
	@echo "   - Frontend source code and build files"
	@echo "   - Frontend user (dspaceui) and group"
	@echo "   - All PM2 logs and runtime files"
	@echo ""
	@echo "The backend DSpace installation will remain intact."
	@echo ""
	@cd $(ANSIBLE_PLAYBOOK_DIR) && ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) remove-frontend.yml
	@echo ""
	@echo "✅ Frontend removal complete!"

remove-frontend-force: ## Force remove frontend without confirmation prompt
	@echo "🗑️  Force removing DSpace frontend..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible-playbook $(ANSIBLE_VERBOSE) -i $(ANSIBLE_INVENTORY) remove-frontend.yml \
		-e "confirm_removal=yes"
	@echo "✅ Frontend removed!"

# Utility targets
check-services: ## Check status of all DSpace services
	@echo "Checking DSpace services on target..."
	@cd $(ANSIBLE_PLAYBOOK_DIR) && \
		ansible -i $(ANSIBLE_INVENTORY) all -m shell \
		-a "sudo systemctl status postgresql tomcat solr --no-pager | head -n 3"

tail-logs: ## Follow DSpace backend logs live (Ctrl+C to stop; LOG_FILE/LINES overridable)
	@echo "📋 Following $(LOG_FILE) — press Ctrl+C to stop..."
	@echo "   (uses 'tail -F', so it keeps waiting/retries if the file isn't there yet)"
	@$(MAKE) provider-exec REMOTE_CMD="sudo tail -F -n $(LINES) $(LOG_FILE)" || true

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