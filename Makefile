ifneq (,$(wildcard .env))
    include .env
    export $(shell sed 's/=.*//' .env)
endif
ENV ?= production

DOCKER_COMPOSE_FILES = -f dist/proxy.docker-compose.yml -f dist/docker-compose.yml
ifeq ($(ENV),development)
    DOCKER_COMPOSE_FILES += -f dist/docker-compose.dev.yml
    BUILD_OPTION = --build
else
    BUILD_OPTION =
endif

DOCKER_COMPOSE = docker compose $(DOCKER_COMPOSE_FILES)

GENERATE_CONFIG = bun src/main.js

.PHONY: generate
generate:
	@echo "Generating configuration for environment: $(ENV)"
	$(GENERATE_CONFIG)

.PHONY: help
help:
	@echo "Usage: make [command] [ENV=prod|dev] [SERVICE=service_name]"
	@echo ""
	@echo "Commands:"
	@echo "  up           Démarrer tous les conteneurs"
	@echo "  down         Arrêter tous les conteneurs"
	@echo "  restart      Redémarrer tous les conteneurs"
	@echo "  start        Démarrer un conteneur spécifique"
	@echo "  stop         Arrêter un conteneur spécifique"
	@echo "  restart_one  Redémarrer un conteneur spécifique"
	@echo "  ps           Lister les conteneurs"

.PHONY: up
up: generate
	$(DOCKER_COMPOSE) up $(BUILD_OPTION)

.PHONY: down
down: generate
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: generate down up

.PHONY: start
start: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "Veuillez spécifier le service avec SERVICE=service_name"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) up -d $(BUILD_OPTION) $(SERVICE)

.PHONY: stop
stop: generate
	@if [ -z "$(SERVICE)" ]; then \
		echo "Veuillez spécifier le service avec SERVICE=service_name"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) stop $(SERVICE)

.PHONY: restart_one
restart_one: stop start

.PHONY: ps
ps:
	$(DOCKER_COMPOSE) ps
