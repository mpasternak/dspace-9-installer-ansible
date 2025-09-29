# DSpace Installer Configuration
# This file contains provider selection and common configuration

# Provider selection (tart, vagrant, or ssh)
# Can be overridden via environment variable: PROVIDER=vagrant make <target>
PROVIDER ?= tart

# Common VM/Host configuration
VM_NAME ?= dspace-server
SSH_USER ?= admin
SSH_DEFAULT_PASSWORD ?= admin

# Provider-specific configuration can be set here or via environment variables
# For SSH provider:
# SSH_HOST ?= 192.168.1.100
# SSH_PORT ?= 22

# For Vagrant provider:
# VAGRANT_BOX ?= ubuntu/jammy64
# VAGRANT_CPUS ?= 2
# VAGRANT_MEMORY ?= 4096

# For Tart provider:
# TART_IMAGE ?= ghcr.io/cirruslabs/ubuntu:latest

# Ansible configuration
# ansible-playbook is executed inside 'ansible/' dir so this is relative:
ANSIBLE_INVENTORY ?= inventory/$(PROVIDER).ini
ANSIBLE_PLAYBOOK_DIR ?= ansible
ANSIBLE_VERBOSE ?= -v

# Include provider-specific Makefile
include providers/$(PROVIDER).mk
