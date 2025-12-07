.DEFAULT_GOAL := help
.PHONY: help install preview-marketing up-marketing

CYAN := \033[36m
GREEN := \033[32m
YELLOW := \033[33m
RESET := \033[0m

help: ## Display available commands
	@printf "$(CYAN)Infrastructure commands:$(RESET)\n"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  $(GREEN)%-20s$(RESET) %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""

install: ## Install Pulumi dependencies for all projects
	@printf "$(YELLOW)Installing infra dependencies...$(RESET)\n"
	cd marketing && yarn install

preview-marketing: ## Preview marketing infrastructure changes
	@printf "$(YELLOW)Previewing marketing changes...$(RESET)\n"
	cd marketing && pulumi preview --stack production

up-marketing: ## Deploy marketing infrastructure
	@printf "$(YELLOW)Deploying marketing infrastructure...$(RESET)\n"
	cd marketing && pulumi up --stack production --yes

# NOTE: No destroy target intentionally - use `cd marketing && pulumi destroy` directly
# with manual confirmation to prevent accidental infrastructure deletion
