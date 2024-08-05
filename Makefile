DOCKER_COMPOSE = docker-compose -f dist/proxy.docker-compose.yml -f dist/docker-compose.yml
#GENERATE_CONFIG = python3 generate.py
GENERATE_CONFIG = pnpm start

.PHONY: generate
generate:
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
	$(DOCKER_COMPOSE) up -d

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
	$(DOCKER_COMPOSE) up -d $(SERVICE)

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