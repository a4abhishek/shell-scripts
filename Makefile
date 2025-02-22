# Set the version for the release (override from command line if desired)
VERSION ?= v1.0.0
ARCHIVE_NAME = shell-scripts-$(VERSION).tar.gz
PREFIX = shell-scripts-$(VERSION)/

.PHONY: release tag archive ghrelease gh-install test

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
	@if [ -f $(ARCHIVE_NAME) ]; then \
	  echo "Tar archive $(ARCHIVE_NAME) already exists. Skipping archive creation."; \
	else \
	  echo "Creating tar archive $(ARCHIVE_NAME)..."; \
	  git archive --format=tar.gz --prefix=$(PREFIX) -o $(ARCHIVE_NAME) $(VERSION); \
	  echo "Tar archive $(ARCHIVE_NAME) created successfully."; \
	fi

# Check if GitHub CLI is installed and authenticated.
check-gh-cli:
	@if ! command -v gh >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) is not installed."; \
		echo "👉 Run 'make gh-install' to install it automatically"; \
		echo "   or visit https://cli.github.com/ to install manually."; \
		exit 1; \
	fi
	@if ! gh auth status >/dev/null 2>&1; then \
		echo "❌ GitHub CLI (gh) is not authenticated."; \
		echo "👉 Run 'gh auth login' to authenticate"; \
		echo "   or set GH_TOKEN environment variable with a GitHub API token."; \
		exit 1; \
	fi

# GitHub release target: Generate release notes and create a GitHub release if possible.
ghrelease: check-gh-cli
	@echo "Checking if GitHub release $(VERSION) exists..."; \
	if gh release view $(VERSION) >/dev/null 2>&1; then \
		echo "GitHub release $(VERSION) already exists. Skipping release creation."; \
	else \
		PREV_TAG=$$(git describe --tags --abbrev=0 $(VERSION)^ 2>/dev/null); \
		if [ -z "$$PREV_TAG" ]; then \
			echo "No previous tag found. Generating release notes from the beginning..."; \
			echo "## What's Changed" > release_notes_$(VERSION).txt; \
			echo "" >> release_notes_$(VERSION).txt; \
			git log --pretty=format:"* %s" $(VERSION) >> release_notes_$(VERSION).txt || exit 1; \
			echo "" >> release_notes_$(VERSION).txt; \
			echo "" >> release_notes_$(VERSION).txt; \
			echo "## Additional Information" >> release_notes_$(VERSION).txt; \
			echo "This is the first release. For the full history, see https://github.com/a4abhishek/shell-scripts/commits/$(VERSION)" >> release_notes_$(VERSION).txt; \
		else \
			echo "Generating release notes from $$PREV_TAG to $(VERSION)..."; \
			echo "## What's Changed" > release_notes_$(VERSION).txt; \
			echo "" >> release_notes_$(VERSION).txt; \
			git log --pretty=format:"* %s" $$PREV_TAG..$(VERSION) >> release_notes_$(VERSION).txt || exit 1; \
			echo "" >> release_notes_$(VERSION).txt; \
			echo "" >> release_notes_$(VERSION).txt; \
			echo "## Additional Information" >> release_notes_$(VERSION).txt; \
			echo "Full Changelog: https://github.com/a4abhishek/shell-scripts/compare/$$PREV_TAG...$(VERSION)" >> release_notes_$(VERSION).txt; \
		fi; \
		gh release create $(VERSION) $(ARCHIVE_NAME) -t "Release $(VERSION)" -F release_notes_$(VERSION).txt || { rm -f release_notes_$(VERSION).txt; exit 1; }; \
		rm -f release_notes_$(VERSION).txt; \
	fi

# gh-install target: Attempts to install GitHub CLI (gh) automatically.
gh-install:
	@echo "Attempting to install GitHub CLI (gh)..."
	@if [ "$$(uname -s)" = "Darwin" ]; then \
		$(MAKE) gh-install-darwin; \
	elif [ "$$(uname -s)" = "Linux" ]; then \
		$(MAKE) gh-install-linux; \
	else \
		echo "Operating system not recognized. Please install gh manually from https://cli.github.com/"; \
		exit 1; \
	fi
	@echo "GitHub CLI (gh) installed successfully."

# Darwin-specific installation
gh-install-darwin:
	@if command -v brew >/dev/null 2>&1; then \
		echo "Installing gh via Homebrew..."; \
		brew install gh; \
	else \
		echo "Homebrew is not installed. Please install Homebrew or install gh manually from https://cli.github.com/"; \
		exit 1; \
	fi

# Linux-specific installation
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
		echo "Automatic installation is not supported on your Linux distribution. Please install gh manually from https://cli.github.com/"; \
		exit 1; \
	fi

# Test target: Run all tests
test: check-bats
	@echo "Running tests..."
	@./run_tests.sh

# Check if BATS is installed
check-bats:
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "❌ BATS (Bash Automated Testing System) is not installed."; \
		case "$$(uname -s)" in \
			Darwin) \
				echo "👉 On macOS, install it with: 'brew install bats-core'"; \
				;; \
			Linux) \
				echo "👉 On Linux (Debian/Ubuntu), install it with: 'sudo apt install bats'"; \
				;; \
			*) \
				echo "👉 Visit https://github.com/bats-core/bats-core for installation instructions."; \
				;; \
		esac; \
		exit 1; \
	fi
