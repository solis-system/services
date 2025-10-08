# =============================================================================
# Solis Services Infrastructure - Makefile
# =============================================================================
# Usage: make [command] [OPTIONS]
# Examples:
#   make up                    # Start all services in background
#   make restart SERVICE=api   # Restart a specific service
#   make logs SERVICE=api      # View logs for api service
#   make logs SERVICE=api FOLLOW=1  # Follow logs in real-time
# =============================================================================

# Load environment variables
ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
else
    $(warning Warning: .env file not found. Using defaults.)
endif

# Default environment
ENV ?= production

# Docker Compose configuration
DOCKER_COMPOSE_FILES = -f dist/proxy.docker-compose.yml -f dist/docker-compose.yml
ifeq ($(ENV),development)
    DOCKER_COMPOSE_FILES += -f dist/docker-compose.dev.yml
    BUILD_OPTION = --build
else
    BUILD_OPTION =
endif

DOCKER_COMPOSE = docker compose $(DOCKER_COMPOSE_FILES)
GENERATE_CONFIG = bun src/main.js

# Default target
.DEFAULT_GOAL := help

# =============================================================================
# Configuration & Validation
# =============================================================================

.PHONY: generate
generate:
	@echo "→ Generating configuration for environment: $(ENV)"
	@$(GENERATE_CONFIG) || (echo "✗ Configuration generation failed" && exit 1)
	@echo "✓ Configuration generated"

.PHONY: validate
validate: generate
	@echo "→ Validating Docker Compose configuration..."
	@$(DOCKER_COMPOSE) config > /dev/null && echo "✓ Configuration is valid" || (echo "✗ Configuration is invalid" && exit 1)

.PHONY: list
list: generate
	@echo "→ Available services:"
	@$(DOCKER_COMPOSE) config --services | sort

# =============================================================================
# Lifecycle Management
# =============================================================================

.PHONY: up
up: generate
	@echo "→ Starting services in detached mode..."
	$(DOCKER_COMPOSE) up -d $(BUILD_OPTION)
	@echo "✓ Services started"

.PHONY: up-fg
up-fg: generate
	@echo "→ Starting services in foreground mode..."
	$(DOCKER_COMPOSE) up $(BUILD_OPTION)

.PHONY: down
down: generate
	@echo "→ Stopping all services..."
	$(DOCKER_COMPOSE) down
	@echo "✓ Services stopped"

.PHONY: start
start: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "✗ Error: SERVICE parameter is required"; \
		echo "Usage: make start SERVICE=service_name"; \
		exit 1; \
	fi
	@echo "→ Starting service: $(SERVICE)"
	@$(DOCKER_COMPOSE) up -d $(BUILD_OPTION) $(SERVICE)
	@echo "✓ Service $(SERVICE) started"

.PHONY: stop
stop: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "✗ Error: SERVICE parameter is required"; \
		echo "Usage: make stop SERVICE=service_name"; \
		exit 1; \
	fi
	@echo "→ Stopping service: $(SERVICE)"
	@$(DOCKER_COMPOSE) stop $(SERVICE)
	@echo "✓ Service $(SERVICE) stopped"

.PHONY: restart
restart: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "→ Restarting all services..."; \
		$(DOCKER_COMPOSE) restart; \
		echo "✓ All services restarted"; \
	else \
		echo "→ Restarting service: $(SERVICE)"; \
		$(DOCKER_COMPOSE) restart $(SERVICE); \
		echo "✓ Service $(SERVICE) restarted"; \
	fi

.PHONY: recreate
recreate: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "→ Recreating all services (down + up)..."; \
		$(DOCKER_COMPOSE) down; \
		$(DOCKER_COMPOSE) up -d $(BUILD_OPTION); \
		echo "✓ All services recreated"; \
	else \
		echo "→ Recreating service: $(SERVICE)"; \
		$(DOCKER_COMPOSE) rm -sf $(SERVICE); \
		$(DOCKER_COMPOSE) up -d $(BUILD_OPTION) $(SERVICE); \
		echo "✓ Service $(SERVICE) recreated"; \
	fi

# =============================================================================
# Updates & Images
# =============================================================================

.PHONY: pull
pull:
	@if [ -z "$(SERVICE)" ]; then \
		echo "→ Pulling all images..."; \
		$(DOCKER_COMPOSE) pull; \
		echo "✓ All images pulled"; \
	else \
		echo "→ Pulling image for: $(SERVICE)"; \
		$(DOCKER_COMPOSE) pull $(SERVICE); \
		echo "✓ Image for $(SERVICE) pulled"; \
	fi

.PHONY: update
update:
	@if [ -z "$(SERVICE)" ]; then \
		echo "✗ Error: SERVICE parameter is required for update"; \
		echo "Usage: make update SERVICE=service_name"; \
		echo "Tip: Use 'make update-all' to update all services"; \
		exit 1; \
	fi
	@echo "→ Updating service: $(SERVICE)"
	@$(MAKE) pull SERVICE=$(SERVICE)
	@$(MAKE) restart SERVICE=$(SERVICE)
	@echo "✓ Service $(SERVICE) updated"

.PHONY: update-all
update-all: pull restart
	@echo "✓ All services updated"

.PHONY: build
build: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "→ Building all services..."; \
		$(DOCKER_COMPOSE) build; \
		echo "✓ All services built"; \
	else \
		echo "→ Building service: $(SERVICE)"; \
		$(DOCKER_COMPOSE) build $(SERVICE); \
		echo "✓ Service $(SERVICE) built"; \
	fi

# =============================================================================
# Debugging & Monitoring
# =============================================================================

.PHONY: ps
ps:
	@$(DOCKER_COMPOSE) ps

.PHONY: status
status: ps
	@echo ""
	@echo "→ Disk usage:"
	@docker system df

.PHONY: logs
logs:
	@if [ -z "$(SERVICE)" ]; then \
		if [ "$(FOLLOW)" = "1" ]; then \
			echo "→ Following logs for all services (Ctrl+C to exit)..."; \
			$(DOCKER_COMPOSE) logs -f; \
		else \
			echo "→ Showing logs for all services..."; \
			$(DOCKER_COMPOSE) logs --tail=100; \
		fi \
	else \
		if [ "$(FOLLOW)" = "1" ]; then \
			echo "→ Following logs for $(SERVICE) (Ctrl+C to exit)..."; \
			$(DOCKER_COMPOSE) logs -f $(SERVICE); \
		else \
			echo "→ Showing logs for $(SERVICE)..."; \
			$(DOCKER_COMPOSE) logs --tail=100 $(SERVICE); \
		fi \
	fi

.PHONY: exec
exec:
	@if [ -z "$(SERVICE)" ]; then \
		echo "✗ Error: SERVICE parameter is required"; \
		echo "Usage: make exec SERVICE=service_name [CMD='command']"; \
		exit 1; \
	fi
	@if [ -z "$(CMD)" ]; then \
		echo "→ Opening shell in $(SERVICE)..."; \
		$(DOCKER_COMPOSE) exec $(SERVICE) sh || $(DOCKER_COMPOSE) exec $(SERVICE) bash; \
	else \
		echo "→ Executing '$(CMD)' in $(SERVICE)..."; \
		$(DOCKER_COMPOSE) exec $(SERVICE) $(CMD); \
	fi

# =============================================================================
# Maintenance
# =============================================================================

.PHONY: clean
clean:
	@echo "→ Removing stopped containers..."
	@docker container prune -f
	@echo "→ Removing unused networks..."
	@docker network prune -f
	@echo "→ Removing unused volumes (orphaned)..."
	@docker volume prune -f
	@echo "✓ Cleanup complete"

.PHONY: clean-all
clean-all:
	@echo "⚠️  Warning: This will remove ALL unused Docker resources"
	@echo "→ Press Ctrl+C to cancel, or Enter to continue..."
	@read confirm
	@echo "→ Cleaning all unused Docker resources..."
	@docker system prune -af --volumes
	@echo "✓ Deep cleanup complete"

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help:
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════════════╗"
	@echo "║         Solis Services Infrastructure - Make Commands             ║"
	@echo "╚════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "📦 LIFECYCLE MANAGEMENT"
	@echo "  make up              Start all services (detached)"
	@echo "  make up-fg           Start all services (foreground)"
	@echo "  make down            Stop all services"
	@echo "  make restart         Restart all services (or SERVICE=name)"
	@echo "  make recreate        Recreate containers (down+up, or SERVICE=name)"
	@echo "  make start           Start a specific service (requires SERVICE=name)"
	@echo "  make stop            Stop a specific service (requires SERVICE=name)"
	@echo ""
	@echo "🔄 UPDATES & IMAGES"
	@echo "  make pull            Pull latest images (all or SERVICE=name)"
	@echo "  make update          Pull + restart service (requires SERVICE=name)"
	@echo "  make update-all      Pull + restart all services"
	@echo "  make build           Build images (all or SERVICE=name)"
	@echo ""
	@echo "🔍 DEBUGGING & MONITORING"
	@echo "  make ps              List running containers"
	@echo "  make status          Show containers status + disk usage"
	@echo "  make logs            Show logs (all or SERVICE=name, add FOLLOW=1)"
	@echo "  make exec            Open shell in container (requires SERVICE=name)"
	@echo ""
	@echo "🛠️  CONFIGURATION & MAINTENANCE"
	@echo "  make generate        Generate docker-compose configs"
	@echo "  make validate        Validate docker-compose configuration"
	@echo "  make list            List all available services"
	@echo "  make clean           Remove stopped containers, unused networks/volumes"
	@echo "  make clean-all       Deep clean (removes ALL unused Docker resources)"
	@echo ""
	@echo "📋 OPTIONS"
	@echo "  ENV=production       Set environment (default: production)"
	@echo "  ENV=development      Use development overrides"
	@echo "  SERVICE=name         Target a specific service"
	@echo "  FOLLOW=1             Follow logs in real-time"
	@echo "  CMD='command'        Execute custom command in container"
	@echo ""
	@echo "💡 EXAMPLES"
	@echo "  make up ENV=development"
	@echo "  make restart SERVICE=api_prod"
	@echo "  make logs SERVICE=api_prod FOLLOW=1"
	@echo "  make exec SERVICE=api_prod CMD='php artisan migrate'"
	@echo "  make update SERVICE=api_prod"
	@echo ""
