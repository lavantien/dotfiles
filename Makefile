# Makefile for dotfiles testing and development
# Supports Windows (Git Bash), Linux, and macOS

# Detect OS
ifeq ($(OS),Windows_NT)
    DETECTED_OS := windows
else
    DETECTED_OS := $(shell uname -s 2>/dev/null || echo "unknown")
    ifeq ($(DETECTED_OS),Linux)
        DETECTED_OS := linux
    else ifeq ($(DETECTED_OS),Darwin)
        DETECTED_OS := macos
    endif
endif

# Colors
ifeq ($(DETECTED_OS),windows)
    RED := ""
    GREEN := ""
    YELLOW := ""
    BLUE := ""
    NC := ""
else
    RED := \033[0;31m
    GREEN := \033[0;32m
    YELLOW := \033[1;33m
    BLUE := \033[0;34m
    NC := \033[0m
endif

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)Dotfiles Testing & Development$(NC)"
	@echo ""
	@echo "$(GREEN)Usage:$(NC) make [target]"
	@echo ""
	@echo "$(GREEN)Targets:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(BLUE)%-20s$(NC) %s\n", $$1, $$2}'

.PHONY: check-bats
check-bats: ## Check if BATS is installed
	@command -v bats >/dev/null 2>&1 || { echo "$(RED)Error: BATS not installed$(NC)"; echo "Install via: npm install -g bats"; exit 1; }
	@echo "$(GREEN)BATS is installed: $(NC) $$(bats --version)"

.PHONY: test
test: check-bats ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@bats tests/bash/

.PHONY: test-unit
test-unit: check-bats ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@bats tests/bash/*_test.bats

.PHONY: test-e2e
test-e2e: check-bats ## Run end-to-end tests only
	@echo "$(BLUE)Running E2E tests...$(NC)"
	@if [ -d "tests/bash/e2e" ]; then \
		bats tests/bash/e2e/*.bats; \
	else \
		echo "$(YELLOW)No E2E tests found$(NC)"; \
	fi

.PHONY: test-update-all
test-update-all: check-bats ## Run update-all tests
	@echo "$(BLUE)Running update-all tests...$(NC)"
	@bats tests/bash/update-all_test.bats

.PHONY: test-git-hooks
test-git-hooks: check-bats ## Run git hooks tests
	@echo "$(BLUE)Running git hooks tests...$(NC)"
	@bats tests/bash/git-hooks_test.bats

.PHONY: test-bootstrap
test-bootstrap: check-bats ## Run bootstrap tests
	@echo "$(BLUE)Running bootstrap tests...$(NC)"
	@bats tests/bash/bootstrap_test.bats

.PHONY: test-verbose
test-verbose: check-bats ## Run tests with verbose output
	@echo "$(BLUE)Running tests (verbose)...$(NC)"
	@bats --print-output-on-passing-tests tests/bash/

.PHONY: test-filter
test-filter: check-bats ## Run tests matching a pattern (use TEST=pattern)
	@echo "$(BLUE)Running tests matching '$(TEST)'...$(NC)"
	@bats --filter '$(TEST)' tests/bash/

.PHONY: test-coverage
test-coverage: check-bats ## Run tests and show coverage summary
	@echo "$(BLUE)Running tests with coverage...$(NC)"
	@bats --formatter tap tests/bash/ | grep -E "^(ok|not ok|#)" | tail -20

.PHONY: install-bats
install-bats: ## Install BATS testing framework via npm
	@echo "$(BLUE)Installing BATS...$(NC)"
	@npm install -g bats

.PHONY: lint-bash
lint-bash: ## Lint bash scripts with shellcheck
	@echo "$(BLUE)Linting bash scripts...$(NC)"
	@if command -v shellcheck >/dev/null 2>&1; then \
		shellcheck *.sh hooks/**/*.sh bootstrap/**/*.sh; \
	else \
		echo "$(YELLOW)shellcheck not installed, skipping$(NC)"; \
	fi

.PHONY: format-bash
format-bash: ## Format bash scripts with shfmt
	@echo "$(BLUE)Formatting bash scripts...$(NC)"
	@if command -v shfmt >/dev/null 2>&1; then \
		shfmt -i 4 -w *.sh hooks/**/*.sh bootstrap/**/*.sh tests/**/*.bats 2>/dev/null || true; \
	else \
		echo "$(YELLOW)shfmt not installed, skipping$(NC)"; \
	fi

.PHONY: clean
clean: ## Clean test artifacts
	@echo "$(BLUE)Cleaning test artifacts...$(NC)"
	@rm -rf /tmp/dotfiles-test-*
	@echo "$(GREEN)Clean complete$(NC)"

.PHONY: ci
ci: check-bats lint-bash test ## Run CI pipeline (lint + test)
	@echo "$(GREEN)CI pipeline complete!$(NC)"
