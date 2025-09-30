#!/bin/bash
# ============================================================================
# Local Testing Script for CI Vagrant Setup
# ============================================================================
#
# PURPOSE: Test the CI workflow locally without using GitHub Actions
#          This helps debug issues and saves GitHub Actions minutes.
#
# Usage: .github/test-local.sh [complete|backend|prerequisites]
#
# ============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Test type (default: complete)
TEST_TYPE="${1:-complete}"

echo -e "${BLUE}============================================================================${RESET}"
echo -e "${BLUE}DSpace Installation Local CI Test${RESET}"
echo -e "${BLUE}Test Type: $TEST_TYPE${RESET}"
echo -e "${BLUE}============================================================================${RESET}"
echo ""

# Check prerequisites
echo -e "${YELLOW}Checking prerequisites...${RESET}"

# Detect architecture
ARCH=$(uname -m)
echo -e "${BLUE}System architecture: $ARCH${RESET}"

if ! command -v vagrant &> /dev/null; then
    echo -e "${RED}❌ Vagrant is not installed${RESET}"
    echo "Please install Vagrant: https://www.vagrantup.com/downloads"
    exit 1
fi

# Check for virtualization provider based on architecture
PROVIDER=""
if [[ "$ARCH" == "arm64" ]] || [[ "$ARCH" == "aarch64" ]]; then
    echo -e "${YELLOW}Checking for ARM64-compatible virtualization providers...${RESET}"

    if command -v vmrun &> /dev/null; then
        echo -e "${GREEN}✅ VMware Fusion found${RESET}"
        PROVIDER="vmware_desktop"
    elif command -v prlctl &> /dev/null; then
        echo -e "${GREEN}✅ Parallels found${RESET}"
        PROVIDER="parallels"
    elif command -v qemu-system-aarch64 &> /dev/null; then
        echo -e "${GREEN}✅ QEMU found${RESET}"
        PROVIDER="qemu"
        # Check for vagrant-qemu plugin
        if ! vagrant plugin list | grep -q vagrant-qemu; then
            echo -e "${YELLOW}Installing vagrant-qemu plugin...${RESET}"
            vagrant plugin install vagrant-qemu
        fi
    elif command -v VBoxManage &> /dev/null; then
        echo -e "${YELLOW}⚠️  VirtualBox found but may have limited ARM64 support${RESET}"
        PROVIDER="virtualbox"
    else
        echo -e "${RED}❌ No ARM64-compatible virtualization provider found${RESET}"
        echo "For Apple Silicon Macs, please install one of:"
        echo "  - VMware Fusion: https://www.vmware.com/products/fusion.html"
        echo "  - Parallels Desktop: https://www.parallels.com/"
        echo "  - QEMU: brew install qemu"
        exit 1
    fi
else
    echo -e "${YELLOW}Checking for x86_64 virtualization providers...${RESET}"

    if command -v VBoxManage &> /dev/null; then
        echo -e "${GREEN}✅ VirtualBox found${RESET}"
        PROVIDER="virtualbox"
    elif command -v vmrun &> /dev/null; then
        echo -e "${GREEN}✅ VMware found${RESET}"
        PROVIDER="vmware_desktop"
    elif command -v qemu-system-x86_64 &> /dev/null; then
        echo -e "${GREEN}✅ QEMU found${RESET}"
        PROVIDER="qemu"
        # Check for vagrant-qemu plugin
        if ! vagrant plugin list | grep -q vagrant-qemu; then
            echo -e "${YELLOW}Installing vagrant-qemu plugin...${RESET}"
            vagrant plugin install vagrant-qemu
        fi
    else
        echo -e "${RED}❌ No virtualization provider found${RESET}"
        echo "Please install one of:"
        echo "  - VirtualBox: https://www.virtualbox.org/"
        echo "  - VMware: https://www.vmware.com/"
        echo "  - QEMU: brew install qemu (macOS) or apt install qemu (Linux)"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Prerequisites satisfied${RESET}"
echo -e "${BLUE}Using provider: $PROVIDER${RESET}"
echo ""

# Export provider for Vagrant
export VAGRANT_DEFAULT_PROVIDER=$PROVIDER

# Setup Vagrant environment
echo -e "${YELLOW}Setting up Vagrant environment...${RESET}"

# Check if we're in the right directory
if [ ! -f "Makefile" ] || [ ! -d "ansible" ]; then
    echo -e "${RED}❌ This script must be run from the dspace-9-installer root directory${RESET}"
    exit 1
fi

# Use CI Vagrantfile if no Vagrantfile exists
if [ ! -f "Vagrantfile" ]; then
    echo "Creating Vagrantfile from CI template..."
    cp .github/Vagrantfile.ci Vagrantfile
    echo -e "${GREEN}✅ Vagrantfile created${RESET}"
else
    echo -e "${YELLOW}⚠️  Vagrantfile already exists, using existing configuration${RESET}"
fi

# Start or provision VM
echo ""
echo -e "${YELLOW}Starting Vagrant VM with $PROVIDER provider...${RESET}"

if vagrant status --machine-readable | grep -q "state,running"; then
    echo "VM is already running"
else
    vagrant up --provider=$PROVIDER
fi

echo -e "${GREEN}✅ VM is running with $PROVIDER${RESET}"
echo ""

# Configure environment
export PROVIDER=vagrant

# Run installation based on test type
echo -e "${BLUE}Running installation test: $TEST_TYPE${RESET}"
echo ""

case "$TEST_TYPE" in
    prerequisites)
        echo "Testing prerequisites installation..."
        make update-apt
        make install-prerequisites
        ;;
    backend)
        echo "Testing backend installation..."
        make update-apt
        make install-prerequisites
        make install-dspace
        ;;
    complete)
        echo "Testing complete installation..."
        make update-apt
        make install-complete
        ;;
    *)
        echo -e "${RED}Invalid test type: $TEST_TYPE${RESET}"
        echo "Usage: $0 [complete|backend|prerequisites]"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}✅ Installation completed${RESET}"
echo ""

# Validation
echo -e "${YELLOW}Validating installation...${RESET}"

# Check services
echo "Checking services..."
vagrant ssh -c "sudo systemctl is-active postgresql" && echo -e "${GREEN}✅ PostgreSQL${RESET}" || echo -e "${RED}❌ PostgreSQL${RESET}"
vagrant ssh -c "sudo systemctl is-active tomcat" && echo -e "${GREEN}✅ Tomcat${RESET}" || echo -e "${RED}❌ Tomcat${RESET}"
vagrant ssh -c "sudo systemctl is-active solr" && echo -e "${GREEN}✅ Solr${RESET}" || echo -e "${RED}❌ Solr${RESET}"

# Check directories
echo ""
echo "Checking installation directories..."
vagrant ssh -c "test -d /opt/dspace" && echo -e "${GREEN}✅ DSpace directory${RESET}" || echo -e "${RED}❌ DSpace directory${RESET}"
vagrant ssh -c "test -d /opt/solr" && echo -e "${GREEN}✅ Solr directory${RESET}" || echo -e "${RED}❌ Solr directory${RESET}"

# Additional checks for backend/complete
if [ "$TEST_TYPE" != "prerequisites" ]; then
    echo ""
    echo "Checking database..."
    vagrant ssh -c "sudo -u postgres psql -d dspace -c 'SELECT 1;' > /dev/null 2>&1" && \
        echo -e "${GREEN}✅ Database connection${RESET}" || \
        echo -e "${RED}❌ Database connection${RESET}"
fi

# Check frontend for complete installation
if [ "$TEST_TYPE" = "complete" ]; then
    echo ""
    echo "Checking frontend..."
    HTTP_CODE=$(vagrant ssh -c "curl -s -o /dev/null -w '%{http_code}' http://localhost:4000" 2>/dev/null)
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✅ Frontend responding (HTTP $HTTP_CODE)${RESET}"
    else
        echo -e "${YELLOW}⚠️  Frontend returned HTTP $HTTP_CODE${RESET}"
    fi
fi

echo ""
echo -e "${BLUE}============================================================================${RESET}"
echo -e "${GREEN}Local CI test completed successfully!${RESET}"
echo -e "${BLUE}============================================================================${RESET}"
echo ""
echo "VM Status:"
vagrant status
echo ""
echo "To access the VM: vagrant ssh"
echo "To destroy the VM: vagrant destroy -f"
echo "To view logs: vagrant ssh -c 'sudo journalctl -xe'"
echo ""

# ============================================================================
# End of Local Testing Script
# ============================================================================