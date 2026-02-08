.DEFAULT_GOAL := help
TOOLKIT_DIR := $(shell cd "$(dir $(lastword $(MAKEFILE_LIST)))" && pwd)

help: ## Show all available targets
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk -F ':.*## ' '{printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

install: ## Install toolkit to ~/.claude/ (non-destructive)
	@$(TOOLKIT_DIR)/scripts/install.sh

update: ## Pull latest and reinstall
	@echo "=== Updating ==="
	git -C $(TOOLKIT_DIR) pull --rebase
	@$(MAKE) --no-print-directory install

doctor: ## Diagnose common issues (15 checks)
	@~/.claude/scripts/doctor.sh

audit: ## Check config against best practices (18+ checks)
	@~/.claude/scripts/audit.sh

list: ## List installed hooks, skills, plugins, permissions
	@echo "=== Hooks ==="
	@ls -1 ~/.claude/hooks/*.sh 2>/dev/null | xargs -I{} basename {} || echo "  (none)"
	@echo ""
	@echo "=== Skills ==="
	@ls -1 ~/.claude/skills/ 2>/dev/null | grep -v .gitkeep || echo "  (none)"
	@echo ""
	@echo "=== MCP ==="
	@ls -1 ~/.claude/mcp/ 2>/dev/null | grep -v .gitkeep || echo "  (none)"
	@echo ""
	@echo "=== Plugins ==="
	@if [ -f ~/.claude/settings.json ]; then \
		jq -r '.enabledPlugins // {} | to_entries[] | "  " + (if .value then "✓" else "✗" end) + " " + .key' ~/.claude/settings.json; \
	fi
	@echo ""
	@echo "=== Permissions ==="
	@if [ -f ~/.claude/settings.json ]; then \
		echo "Allow: $$(jq '.permissions.allow | length' ~/.claude/settings.json) rules"; \
		echo "Deny:  $$(jq '.permissions.deny | length' ~/.claude/settings.json) rules"; \
	fi

init-project: ## Initialize project config (P=<path>)
	@~/.claude/scripts/init-project.sh $(or $(P),$(error Usage: make init-project P=<path>))

sync: ## Sync config to all agents (Codex + CodeBuddy)
	@~/.claude/scripts/sync-agents.sh all

fetch-libs: ## Fetch third-party reference libraries (git submodules)
	@echo "=== Fetching Libraries ==="
	git -C $(TOOLKIT_DIR) submodule update --init --recursive
	@echo "Done."

.PHONY: help install update doctor audit list init-project sync fetch-libs
