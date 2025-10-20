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

## Woodpecker CI (auto-hébergé)

Woodpecker CI est **intégré au manifest.yml** et fait partie de l'infrastructure Solis. Il bénéficie automatiquement du reverse proxy Caddy, du dashboard Homepage, et des commandes Make uniformes.

### Installation rapide

```bash
# 1. Configurer les variables d'environnement
cp .env.woodpecker.example .env.woodpecker
# Éditer .env.woodpecker avec vos credentials GitHub/Gitea/GitLab

# 2. Lancer Woodpecker CI (commandes standards comme les autres services)
make generate
make start woodpecker-server
make start woodpecker-agent

# Ou démarrer tous les services d'un coup
make up

# 3. Builder et pousser l'image CI
make ci-image-push
```

**Accès web :**
- Local : http://localhost:8000
- Production : https://woodpecker.${DOMAIN} (via Caddy, automatique)
- Dashboard : Visible dans Homepage (groupe "Outils")

📚 **Documentation complète :** [WOODPECKER.md](./WOODPECKER.md)

### Commandes

Woodpecker utilise les **commandes standards** (comme tous les autres services) :

```bash
# Gestion des services
make start woodpecker-server        # Démarrer le serveur
make start woodpecker-agent         # Démarrer l'agent
make restart woodpecker-server      # Redémarrer
make logs woodpecker-server FOLLOW=1  # Suivre les logs

# Image CI (spécifique au déploiement)
make ci-image-build                 # Builder l'image lola-ci-deploy
make ci-image-push                  # Builder et pousser au registry
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
