# Local Linux Provider Implementation (loopback)
# This file installs DSpace directly onto the machine running `make`, using
# Ansible's local connection (no VM, no SSH).
#
# Constraints:
#   - Debian/Ubuntu Linux host only (the installer uses apt). On macOS this
#     provider refuses to run — use PROVIDER=tart or PROVIDER=orbstack instead.
#   - The current user must have passwordless sudo: the installer runs many
#     privileged tasks unattended, matching the convention used by every other
#     provider (their `admin` user has NOPASSWD sudo).
#
# WARNING: `make build-vm` also runs update-system.yml, which may upgrade
# packages and reboot the host. Use a dedicated machine/VM as the target.

# Host OS detection (used by the guards below)
LOCAL_LINUX_OS := $(shell uname -s)

# Provider interface implementation
.PHONY: provider-init provider-start provider-stop provider-destroy provider-ssh provider-get-ip provider-status provider-copy-ssh-key provider-install-deps

provider-init: ## Validate the local Linux host (loopback target)
	@echo ""
	@echo "╔══════════════════════════════════════════════════════════╗"
	@echo "║         Initializing Local Linux Host (loopback)         ║"
	@echo "╚══════════════════════════════════════════════════════════╝"
	@echo ""
	@# Guard: Linux + apt only
	@if [ "$(LOCAL_LINUX_OS)" != "Linux" ]; then \
		echo "❌ The 'local-linux' provider only runs on a Linux host."; \
		echo "   Detected operating system: $(LOCAL_LINUX_OS)"; \
		echo "   On macOS, use PROVIDER=tart or PROVIDER=orbstack instead."; \
		exit 1; \
	fi
	@if ! command -v apt-get >/dev/null 2>&1; then \
		echo "❌ 'apt-get' not found — this provider supports Debian/Ubuntu hosts."; \
		exit 1; \
	fi
	@echo "✅ Linux host with apt detected ($$(. /etc/os-release 2>/dev/null && echo $$PRETTY_NAME || uname -sr))"
	@# Guard: passwordless sudo
	@echo "🔍 Checking passwordless sudo..."
	@if sudo -n true 2>/dev/null; then \
		echo "✅ Passwordless sudo available"; \
	else \
		echo "❌ Passwordless sudo is required for the local-linux provider."; \
		echo "   The installer runs many privileged tasks unattended."; \
		echo "   Grant it with (replace <user> with your username):"; \
		echo "     echo '<user> ALL=(ALL) NOPASSWD:ALL' | sudo tee /etc/sudoers.d/dspace-installer"; \
		exit 1; \
	fi
	@echo ""
	@echo "⚠️  NOTE: This installs DSpace onto THIS machine and may upgrade"
	@echo "    packages and reboot it. Use a dedicated host/VM as the target."
	@echo "✅ Local host ready"

provider-start: ## (No-op) The target is this machine
	@echo "ℹ️  local-linux provider: the target is this machine — nothing to start."

provider-stop: ## (No-op) The target is this machine
	@echo "ℹ️  local-linux provider: the target is this machine — nothing to stop."

provider-destroy: ## (No-op) Refuse to destroy the local machine
	@echo "ℹ️  local-linux provider: the target is this machine — refusing to 'destroy' it."
	@echo ""
	@echo "To remove a DSpace installation from this host, manually run e.g.:"
	@echo "  sudo rm -rf /opt/dspace* /opt/solr /opt/tomcat"

provider-ssh: ## Open a local shell (you are already on the host)
	@echo "ℹ️  local-linux provider: you are already on the target host."
	@echo "   Launching a local shell ($${SHELL:-/bin/bash})..."
	@exec $${SHELL:-/bin/bash}

provider-get-ip: ## Get IP address (always localhost for loopback)
	@echo "127.0.0.1"

provider-status: ## Check status of the local host
	@echo "Local Linux Provider Status:"
	@if [ "$(LOCAL_LINUX_OS)" != "Linux" ]; then \
		echo "❌ Host: not Linux ($(LOCAL_LINUX_OS)) — this provider is unavailable here"; \
		echo "   On macOS, use PROVIDER=tart or PROVIDER=orbstack instead."; \
	else \
		echo "✅ Target: this machine (localhost)"; \
		echo "🖥️  Hostname: $$(hostname)"; \
		echo "🐧 OS: $$(. /etc/os-release 2>/dev/null && echo $$PRETTY_NAME || uname -sr)"; \
		echo "💾 Memory: $$(free -h 2>/dev/null | awk '/Mem:/{print $$2}')"; \
		echo "💻 CPUs: $$(nproc 2>/dev/null)"; \
		if sudo -n true 2>/dev/null; then \
			echo "🔑 Sudo: passwordless ✅"; \
		else \
			echo "🔑 Sudo: password required ⚠️  (run 'make build-vm' for setup instructions)"; \
		fi; \
	fi

provider-copy-ssh-key: ## (No-op) Local connection needs no SSH key
	@echo "ℹ️  local-linux provider uses a local connection — no SSH key needed."

provider-install-deps: ## Verify this is a supported Linux host
	@echo "📦 Checking local Linux host..."
	@if [ "$(LOCAL_LINUX_OS)" != "Linux" ]; then \
		echo "❌ The 'local-linux' provider only runs on a Linux host."; \
		echo "   Detected operating system: $(LOCAL_LINUX_OS)"; \
		echo "   On macOS, use PROVIDER=tart or PROVIDER=orbstack instead."; \
		exit 1; \
	fi
	@if ! command -v apt-get >/dev/null 2>&1; then \
		echo "❌ 'apt-get' not found — this provider supports Debian/Ubuntu hosts."; \
		exit 1; \
	fi
	@echo "✅ Linux host with apt detected"
	@if ! command -v python3 >/dev/null 2>&1; then \
		echo "⚠️  python3 not found — Ansible needs a Python interpreter on the host."; \
		echo "   Install with: sudo apt-get update && sudo apt-get install -y python3"; \
	else \
		echo "✅ python3 available"; \
	fi
