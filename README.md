# Solis Services Infrastructure

Générateur de configuration Docker pour l'infrastructure Solis. Orchestre tous les services via Docker Compose, Caddy (reverse proxy), et Homepage (dashboard).

## Prérequis

- Docker & Docker Compose
- Make
- Node.js / Bun
- pnpm

## Démarrage rapide

```bash
# Générer les configs et démarrer tous les services
make up

# Arrêter tous les services
make down

# Voir les logs
make logs

# Aide complète
make help
```

## Submodules

```bash
# Mettre à jour les submodules
make init_submodule
```

## labels

```yml
labels:
  base:
    container_name: base
    image: ''
    labels:
      caddy: '${DOMAIN}'
      caddy.reverse_proxy: '{{upstreams 80}}'
    volumes:
      -
    environment:
      -
    ports:
      - ''
    restart: always
    networks:
      - proxy-network
```
