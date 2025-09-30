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

if ! command -v vagrant &> /dev/null; then
    echo -e "${RED}❌ Vagrant is not installed${RESET}"
    echo "Please install Vagrant: https://www.vagrantup.com/downloads"
    exit 1
fi

if ! command -v VBoxManage &> /dev/null; then
    echo -e "${YELLOW}⚠️  VirtualBox not found, checking for other providers...${RESET}"
    if ! command -v vmrun &> /dev/null; then
        echo -e "${RED}❌ No virtualization provider found${RESET}"
        echo "Please install VirtualBox or VMware"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Prerequisites satisfied${RESET}"
echo ""

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
echo -e "${YELLOW}Starting Vagrant VM...${RESET}"

if vagrant status --machine-readable | grep -q "state,running"; then
    echo "VM is already running"
else
    vagrant up
fi

echo -e "${GREEN}✅ VM is running${RESET}"
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