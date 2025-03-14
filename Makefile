# Set shell and shell flags for consistency
SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c

# Set the version for the release (override from command line if desired)
VERSION ?= v1.0.0
ARCHIVE_NAME = shell-scripts-$(VERSION).tar.gz
PREFIX = shell-scripts-$(VERSION)/
TEST_FILE ?=

# Directories to check
SCRIPT_DIRS := bin lib test

# Find all shell scripts (excluding test files, .git and .github directories)
SHELL_SCRIPTS := $(shell find $(SCRIPT_DIRS) -type f -name "*.sh" ! -name "*_test.sh" \
                        -not -path "*/\.*/*" \
                        -not -path "*/\.*") \
                 $(shell find $(SCRIPT_DIRS) -type f ! -name "*_test.sh" \
                        -not -path "*/\.*/*" \
                        -not -path "*/\.*" \
                        -exec test -x {} \; \
                        -exec sh -c 'file -b --mime-type "$$0" | grep -q "^text/"' {} \; -print)

# Collect all PHONY targets in one place
.PHONY: help tag archive ghrelease release gh-install test all check format format-check install-tools setup-hooks

# Default target
all: check test

# Installation targets for required tools
install-tools: install-shellcheck install-shfmt install-gh

install-shellcheck-darwin:
	@echo "Installing shellcheck via Homebrew..."
	@brew install shellcheck

install-shellcheck-linux:
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "Installing shellcheck via apt-get..."; \
		sudo apt-get update && sudo apt-get install -y shellcheck; \
	elif command -v yum >/dev/null 2>&1; then \
		echo "Installing shellcheck via yum..."; \
		sudo yum install -y epel-release && sudo yum install -y shellcheck; \
	else \
		echo "Please install shellcheck manually from https://github.com/koalaman/shellcheck#installing"; \
		exit 1; \
	fi

install-shellcheck:
	@echo "Attempting to install shellcheck..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		$(MAKE) install-shellcheck-darwin; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		$(MAKE) install-shellcheck-linux; \
	else \
		echo "Operating system not recognized. Please install shellcheck manually."; \
		echo "Visit: https://github.com/koalaman/shellcheck#installing"; \
		exit 1; \
	fi

install-shfmt-darwin:
	@echo "Installing shfmt via Homebrew..."
	@brew install shfmt

install-shfmt-linux:
	@if command -v snap >/dev/null 2>&1; then \
		echo "Installing shfmt via snap..."; \
		sudo snap install shfmt; \
	elif command -v go >/dev/null 2>&1; then \
		echo "Installing shfmt via go..."; \
		go install mvdan.cc/sh/v3/cmd/shfmt@latest; \
	else \
		echo "Please install shfmt manually from https://github.com/mvdan/sh#installation"; \
		exit 1; \
	fi

install-shfmt:
	@echo "Attempting to install shfmt..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		$(MAKE) install-shfmt-darwin; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		$(MAKE) install-shfmt-linux; \
	else \
		echo "Operating system not recognized. Please install shfmt manually."; \
		echo "Visit: https://github.com/mvdan/sh#installation"; \
		exit 1; \
	fi

# Rename gh-install to install-gh for consistency
install-gh: gh-install-darwin gh-install-linux
gh-install: install-gh

# Check tools before running checks
check-tools:
	@echo "Checking required tools..."
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck is required but not installed."; \
		echo "👉 Run 'make install-shellcheck' to install it automatically"; \
		echo "   or visit https://github.com/koalaman/shellcheck#installing"; \
		exit 1; \
	fi
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt is required but not installed."; \
		echo "👉 Run 'make install-shfmt' to install it automatically"; \
		echo "   or visit https://github.com/mvdan/sh#installation"; \
		exit 1; \
	fi

# Test targets
test-all:
	@echo "Running all tests..."
	@./run_tests.sh

test-specific:
	@if [ -z "$(TEST_FILE)" ]; then \
		echo "❌ Error: No test file specified"; \
		echo "Usage: make test TEST_FILE=path/to/test_file.sh"; \
		exit 1; \
	fi
	@if [ ! -f "$(TEST_FILE)" ]; then \
		echo "❌ Error: Test file '$(TEST_FILE)' not found"; \
		exit 1; \
	fi
	@echo "Running specific test: $(TEST_FILE)"
	@bats "$(TEST_FILE)" --verbose-run --jobs 8

# Smart test target that delegates to either test-all or test-specific
test:
	@if [ -z "$(TEST_FILE)" ]; then \
		$(MAKE) test-all; \
	else \
		$(MAKE) test-specific; \
	fi

# Check targets
check: check-tools format-check shellcheck custom-checks

shellcheck:
	@echo "Running shellcheck..."
	@shellcheck -x -s bash \
		--exclude=SC2034,SC2178 \
		$(SHELL_SCRIPTS)

custom-checks:
	@echo "Running custom checks..."
	@for file in $(SHELL_SCRIPTS); do \
		if ! $(SHELL) -c '. scripts/custom-checks.sh && run_script_checks "'"$$file"'"'; then \
			exit 1; \
		fi; \
	done

# Release targets
release: check-gh-cli tag archive ghrelease
	@echo "Release $(VERSION) complete."

# Tag target: Create the tag if it doesn't exist; otherwise, push it.
tag:
	@echo "Checking if tag $(VERSION) exists..."
	@if git rev-parse $(VERSION) >/dev/null 2>&1; then \
		echo "Tag $(VERSION) already exists. Pushing tag to remote..."; \
		git push origin $(VERSION); \
	else \
		echo "Creating tag $(VERSION)..."; \
		git tag -a $(VERSION) -m "Release $(VERSION)"; \
		git push origin $(VERSION); \
	fi

# Archive target: Create a tar.gz archive if one doesn't exist.
archive:
	@if [ -f "$(ARCHIVE_NAME)" ]; then \
		echo "Tar archive $(ARCHIVE_NAME) already exists. Skipping archive creation."; \
	else \
		echo "Creating tar archive $(ARCHIVE_NAME)..."; \
		git archive --format=tar.gz --prefix=$(PREFIX) -o $(ARCHIVE_NAME) $(VERSION); \
		echo "Tar archive $(ARCHIVE_NAME) created successfully."; \
	fi

# GitHub release target: Create a release if it doesn't exist.
ghrelease: check-gh-cli
	@echo "Checking if GitHub release $(VERSION) exists..."
	@if gh release view $(VERSION) >/dev/null 2>&1; then \
		echo "GitHub release $(VERSION) already exists. Skipping release creation."; \
	else \
		$(MAKE) generate-release-notes; \
		gh release create $(VERSION) $(ARCHIVE_NAME) -t "Release $(VERSION)" -F release_notes_$(VERSION).txt || { rm -f release_notes_$(VERSION).txt; exit 1; }; \
		rm -f release_notes_$(VERSION).txt; \
	fi

# Release helper: Generate release notes based on commit messages.
generate-release-notes:
	@PREV_TAG=$$(git describe --tags --abbrev=0 $(VERSION)^ 2>/dev/null || true); \
	if [ -z "$$PREV_TAG" ]; then \
		echo "No previous tag found. Generating release notes from the beginning..."; \
		git log --pretty=format:"* %s" $(VERSION) > release_notes_$(VERSION).txt; \
	else \
		echo "Generating release notes from $$PREV_TAG to $(VERSION)..."; \
		git log --pretty=format:"* %s" $$PREV_TAG..$(VERSION) > release_notes_$(VERSION).txt; \
	fi; \
	echo -e "\n\nFull Changelog: https://github.com/a4abhishek/shell-scripts/commits/$(VERSION)" >> release_notes_$(VERSION).txt

# Check for GitHub CLI (gh) and its authentication status.
check-gh-cli:
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) is not installed."; \
		echo "👉 Run 'make gh-install' to install it automatically or visit https://cli.github.com/ to install manually."; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) is not authenticated."; \
		echo "👉 Run 'gh auth login' to authenticate or set the GH_TOKEN environment variable with a GitHub API token."; \
		exit 1; \
	fi

# Installation targets for GitHub CLI (gh)
gh-install-darwin:
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing gh via Homebrew..."; \
		brew install gh; \
	else \
		echo "Homebrew is not installed. Please install gh manually from https://cli.github.com/"; \
		exit 1; \
	fi

gh-install-linux:
	@if command -v apt-get >/dev/null 2>&1; then \
		echo "Installing gh via apt-get..."; \
		curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg && \
		sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg && \
		echo "deb [arch=$$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null && \
		sudo apt-get update && sudo apt-get install gh -y; \
	elif command -v yum >/dev/null 2>&1; then \
		echo "Installing gh via yum..."; \
		sudo yum install gh -y; \
	else \
		echo "Automatic installation is not supported. Please install gh manually from https://cli.github.com/"; \
		exit 1; \
	fi

# Format targets
format:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt is required but not installed."; \
		echo "👉 Installing shfmt..."; \
		$(MAKE) install-shfmt; \
	fi
	@echo "Formatting shell scripts..."
	@shfmt -w -i 4 -bn -ci -sr $(SHELL_SCRIPTS)

format-check:
	@if ! command -v shfmt >/dev/null 2>&1; then \
		echo "shfmt is required but not installed."; \
		echo "👉 Installing shfmt..."; \
		$(MAKE) install-shfmt; \
	fi
	@echo "Checking shell script formatting..."
	@shfmt -d -i 4 -bn -ci -sr $(SHELL_SCRIPTS) || { \
		echo "❌ Formatting check failed."; \
		echo "👉 Run 'make format' to fix formatting automatically"; \
		exit 1; \
	}

# Help target
help:
	@echo "Shell Scripts - Available Make Targets"
	@echo ""
	@echo "Development Targets:"
	@echo "  all            - Run checks and tests (default)"
	@echo "  check          - Run all checks (tools, shellcheck, custom)"
	@echo "  format         - Format all shell scripts automatically"
	@echo "  format-check   - Check if shell scripts are properly formatted"
	@echo "  setup-hooks    - Set up Git pre-commit hooks for automatic checks"
	@echo ""
	@echo "Testing Targets:"
	@echo "  test           - Run tests (all or specific)"
	@echo "                   Usage: make test [TEST_FILE=path/to/test.sh]"
	@echo ""
	@echo "Installation Targets:"
	@echo "  install-tools  - Install all required development tools"
	@echo "  install-shellcheck - Install shellcheck"
	@echo "  install-shfmt  - Install shfmt"
	@echo "  install-gh     - Install GitHub CLI (gh)"
	@echo ""
	@echo "Release Targets:"
	@echo "  release        - Create and publish a new release"
	@echo "                   Usage: make release [VERSION=v1.2.3]"
	@echo "  tag            - Create and push a new git tag"
	@echo "                   Usage: make tag [VERSION=v1.2.3]"
	@echo "  archive        - Create release archive"
	@echo "                   Usage: make archive [VERSION=v1.2.3]"
	@echo "  ghrelease      - Create GitHub release"
	@echo "                   Usage: make ghrelease [VERSION=v1.2.3]"
	@echo ""
	@echo "Examples:"
	@echo "  make test TEST_FILE=test/logging_test.sh"
	@echo "  make release VERSION=v1.2.3"
	@echo "  make format"
	@echo ""
	@echo "Default Values:"
	@echo "  VERSION        = $(VERSION)"
	@echo "  TEST_FILE      = $(TEST_FILE)"

# Add setup-hooks target
setup-hooks:
	@echo "Setting up Git hooks..."
	@mkdir -p .git/hooks
	@ln -sf "../../scripts/hooks/pre-commit.sh" .git/hooks/pre-commit
	@chmod +x scripts/hooks/pre-commit.sh
	@echo "✅ Git hooks installed successfully!"
