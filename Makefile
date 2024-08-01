COMPOSE_FILE=docker-compose.yml
COMPOSE_FILE_DEV=dev.docker-compose.yml

ENV ?= prod

ifeq ($(ENV),dev)
    COMPOSE_FILES=$(COMPOSE_FILE) -f $(COMPOSE_FILE_DEV)
else
    COMPOSE_FILES=$(COMPOSE_FILE)
endif

DOCKER_COMPOSE = docker-compose -f $(COMPOSE_FILES)
GENERATE_CONFIG = python3 generate_configs.py


.PHONY: generate_configs
generate_configs:
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
up: generate_configs
	$(DOCKER_COMPOSE) up -d

.PHONY: down
down: generate_configs
	$(DOCKER_COMPOSE) down

.PHONY: restart
restart: generate_configs down up

.PHONY: start
start: generate_configs
	@if [ -z "$(SERVICE)" ]; then \
		echo "Veuillez spécifier le service avec SERVICE=service_name"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) up -d $(SERVICE)

.PHONY: stop
stop: generate_configs
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