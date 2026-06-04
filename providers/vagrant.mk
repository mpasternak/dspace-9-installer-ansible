# Vagrant Provider Implementation
# This file contains all Vagrant-specific operations

# Vagrant-specific variables
VAGRANT_BOX ?= ubuntu/jammy64
VAGRANT_CPUS ?= 2
VAGRANT_MEMORY ?= 4096
VAGRANTFILE_PATH ?= ./Vagrantfile

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key

provider-init: ## Initialize Vagrant VM
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║           Initializing Vagrant VM                        ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Create Vagrantfile if it doesn't exist
	@if [ ! -f $(VAGRANTFILE_PATH) ]; then \
		echo "📝 Creating Vagrantfile..."; \
		echo 'Vagrant.configure("2") do |config|' > $(VAGRANTFILE_PATH); \
		echo '  config.vm.box = "$(VAGRANT_BOX)"' >> $(VAGRANTFILE_PATH); \
		echo '  config.vm.hostname = "$(VM_NAME)"' >> $(VAGRANTFILE_PATH); \
		echo '  config.vm.network "private_network", type: "dhcp"' >> $(VAGRANTFILE_PATH); \
		echo '  config.vm.provider "virtualbox" do |vb|' >> $(VAGRANTFILE_PATH); \
		echo '    vb.name = "$(VM_NAME)"' >> $(VAGRANTFILE_PATH); \
		echo '    vb.memory = "$(VAGRANT_MEMORY)"' >> $(VAGRANTFILE_PATH); \
		echo '    vb.cpus = $(VAGRANT_CPUS)' >> $(VAGRANTFILE_PATH); \
		echo '  end' >> $(VAGRANTFILE_PATH); \
		echo '  config.vm.provision "shell", inline: <<-SHELL' >> $(VAGRANTFILE_PATH); \
		echo '    # Create admin user with sudo privileges' >> $(VAGRANTFILE_PATH); \
		echo '    useradd -m -s /bin/bash -G sudo $(SSH_USER) 2>/dev/null || true' >> $(VAGRANTFILE_PATH); \
		echo '    echo "$(SSH_USER):$(SSH_DEFAULT_PASSWORD)" | chpasswd' >> $(VAGRANTFILE_PATH); \
		echo '    echo "$(SSH_USER) ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$(SSH_USER)' >> $(VAGRANTFILE_PATH); \
		echo '  SHELL' >> $(VAGRANTFILE_PATH); \
		echo 'end' >> $(VAGRANTFILE_PATH); \
		echo "✅ Vagrantfile created"; \
	else \
		echo "ℹ️  Vagrantfile already exists"; \
	fi
	@# Start the VM
	@echo "🚀 Starting Vagrant VM..."
	@vagrant up
	@echo "✅ VM started successfully"
	@# Get IP address
	@echo "📍 IP Address: $$($(MAKE) -f providers/vagrant.mk provider-get-ip)"
	@# Setup SSH key authentication
	@$(MAKE) -f providers/vagrant.mk provider-copy-ssh-key

provider-start: ## Start the Vagrant VM
	@echo "🚀 Starting VM '$(VM_NAME)'..."
	@if [ ! -f $(VAGRANTFILE_PATH) ]; then \
		echo "❌ Vagrantfile not found. Run 'make provider-init' first"; \
		exit 1; \
	fi
	@vagrant up
	@echo "✅ VM started at $$($(MAKE) -f providers/vagrant.mk provider-get-ip)"

provider-stop: ## Stop the Vagrant VM
	@echo "⏹️  Stopping VM '$(VM_NAME)'..."
	@if [ -f $(VAGRANTFILE_PATH) ]; then \
		vagrant halt; \
		echo "✅ VM stopped"; \
	else \
		echo "❌ Vagrantfile not found"; \
	fi

provider-destroy: ## Destroy the Vagrant VM
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║              Destroying Vagrant VM                       ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@if [ -f $(VAGRANTFILE_PATH) ]; then \
		echo "🔍 Found Vagrant VM"; \
		echo "⚠️  WARNING: This will permanently delete the VM and all its data!"; \
		read -p "Are you sure you want to destroy the VM? (yes/no): " confirm; \
		if [ "$$confirm" = "yes" ] || [ "$$confirm" = "y" ]; then \
			VM_IP=$$($(MAKE) -f providers/vagrant.mk provider-get-ip 2>/dev/null || echo ""); \
			echo "🗑️  Destroying VM..."; \
			vagrant destroy -f; \
			if [ -n "$$VM_IP" ]; then \
				echo "🔑 Removing SSH host key..."; \
				ssh-keygen -R "$$VM_IP" 2>/dev/null || true; \
			fi; \
			echo "✅ VM destroyed successfully"; \
			echo "💡 Vagrantfile retained for future use. Delete manually if needed."; \
		else \
			echo "❌ Destruction cancelled"; \
		fi; \
	else \
		echo "ℹ️  No Vagrant VM found"; \
	fi

provider-ssh: ## SSH into the Vagrant VM
	@echo "Connecting to VM '$(VM_NAME)'..."
	@vagrant ssh

provider-exec: ## Run REMOTE_CMD on the VM over SSH (e.g. REMOTE_CMD="uptime")
	@if [ -z "$(REMOTE_CMD)" ]; then echo "❌ REMOTE_CMD is required"; exit 1; fi
	@vagrant ssh -c "$(REMOTE_CMD)" -- -t

provider-get-ip: ## Get IP address of the Vagrant VM
	@vagrant ssh-config 2>/dev/null | grep HostName | awk '{print $$2}' || \
		(vagrant ssh -c "ip addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print \$$2}' | cut -d/ -f1" 2>/dev/null) || \
		(echo "VM not running or IP not available" >&2; exit 1)

provider-status: ## Check status of the Vagrant VM
	@echo "Vagrant Provider Status:"
	@if [ -f $(VAGRANTFILE_PATH) ]; then \
		STATUS=$$(vagrant status --machine-readable | grep "state," | cut -d',' -f4); \
		if [ "$$STATUS" = "running" ]; then \
			echo "✅ VM: Running"; \
			IP=$$($(MAKE) -f providers/vagrant.mk provider-get-ip 2>/dev/null); \
			if [ -n "$$IP" ]; then \
				echo "📍 IP: $$IP"; \
				if vagrant ssh -c "exit" 2>/dev/null; then \
					echo "🔗 SSH: Connected"; \
				else \
					echo "❌ SSH: Not accessible"; \
				fi; \
			fi; \
		elif [ -n "$$STATUS" ]; then \
			echo "⏸️  VM: $$STATUS"; \
		else \
			echo "❌ VM: Not created"; \
		fi; \
	else \
		echo "❌ Vagrantfile not found"; \
	fi

provider-copy-ssh-key: ## Copy SSH key to Vagrant VM
	@echo "🔐 Setting up SSH key authentication..."
	@if [ ! -f ~/.ssh/id_rsa ] && [ ! -f ~/.ssh/id_ed25519 ]; then \
		echo "🔑 Generating SSH key..."; \
		ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""; \
	fi
	@# Vagrant already handles SSH keys, but we'll add our key for the admin user
	@echo "📝 Adding SSH key for $(SSH_USER) user..."
	@vagrant ssh -c "sudo mkdir -p /home/$(SSH_USER)/.ssh && sudo cp ~/.ssh/authorized_keys /home/$(SSH_USER)/.ssh/ && sudo chown -R $(SSH_USER):$(SSH_USER) /home/$(SSH_USER)/.ssh"
	@echo "✅ SSH key configured"

provider-install-deps: ## Install Vagrant dependencies
	@echo "📦 Installing Vagrant dependencies..."
	@# Check for VirtualBox or other hypervisor
	@if ! command -v vagrant &> /dev/null; then \
		echo "❌ Vagrant not installed. Please install from: https://www.vagrantup.com/downloads"; \
		echo "   On macOS: brew install vagrant"; \
		echo "   On Linux: Follow distribution-specific instructions"; \
		exit 1; \
	else \
		echo "✅ Vagrant installed"; \
	fi
	@if ! command -v VBoxManage &> /dev/null; then \
		echo "⚠️  VirtualBox not found. Install from: https://www.virtualbox.org/"; \
		echo "   On macOS: brew install --cask virtualbox"; \
	else \
		echo "✅ VirtualBox installed"; \
	fi