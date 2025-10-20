# Woodpecker CI - Configuration auto-hébergée

Ce document décrit comment configurer et utiliser Woodpecker CI pour automatiser le déploiement des applications Solis (API Laravel et Frontend Vue.js).

## Vue d'ensemble

**Woodpecker CI** est un système de CI/CD open source auto-hébergé. Cette configuration remplace le système GitHub Actions précédent tout en conservant la même logique de déploiement.

**✨ Nouveauté :** Woodpecker est maintenant **intégré au manifest.yml** et bénéficie de toute l'infrastructure Solis (Caddy reverse proxy, Homepage dashboard, commandes make uniformes).

**Architecture :**
```
┌─────────────────┐
│  manifest.yml   │  ← Source unique de vérité
│  (Woodpecker    │
│   définition)   │
└────────┬────────┘
         │ Génère via ConfigGenerator
         ▼
┌─────────────────┐
│ docker-compose  │
│ + Caddy proxy   │  → woodpecker.${DOMAIN}
│ + Homepage      │  → Visible dans le dashboard
└────────┬────────┘
         │
         ├──→ Woodpecker Server (port 8000)
         └──→ Woodpecker Agent (exécute les builds)
                     │
        ┌────────────┴────────────┐
        │                         │
  ┌─────▼─────┐           ┌───────▼───────┐
  │    API    │           │    LOLAPP     │
  │  (repo)   │           │    (repo)     │
  └─────┬─────┘           └───────┬───────┘
        │                         │
        │  .woodpecker.yml        │  .woodpecker.yml
        │                         │
        └────────────┬────────────┘
                     │
              ┌──────▼──────┐
              │ lola-ci-    │
              │ deploy      │
              │ (image)     │
              └─────────────┘
                     │
                Exécute deploy.sh
                (build/tag/push)
```

## Installation et configuration

### 1. Prérequis

- Docker et Docker Compose installés
- Accès au serveur de registry Docker (`registry.solisws.fr`)
- Token d'accès GitHub/Gitea/GitLab pour connecter les repos

### 2. Configuration initiale

#### a) Créer les variables d'environnement

Créer un fichier `.env.woodpecker` dans le repo `services` :

```bash
# URL publique de Woodpecker (adapter selon votre domaine)
WOODPECKER_HOST=https://woodpecker.solisws.fr

# Utilisateur admin (sera automatiquement admin au premier login)
WOODPECKER_ADMIN=votre-username-git

# Secret partagé entre server et agent (généré automatiquement ou personnalisé)
WOODPECKER_AGENT_SECRET=$(openssl rand -hex 32)

# Configuration GitHub (décommenter et remplir)
WOODPECKER_GITHUB_CLIENT=your_github_oauth_client_id
WOODPECKER_GITHUB_SECRET=your_github_oauth_secret

# OU Configuration Gitea (décommenter et remplir)
# WOODPECKER_GITEA=true
# WOODPECKER_GITEA_URL=https://gitea.example.com
# WOODPECKER_GITEA_CLIENT=your_gitea_oauth_client_id
# WOODPECKER_GITEA_SECRET=your_gitea_oauth_secret
```

#### b) Obtenir les credentials OAuth

**Pour GitHub :**
1. Aller sur https://github.com/settings/developers
2. Créer une nouvelle OAuth App
3. URL d'autorisation : `https://woodpecker.solisws.fr/authorize`
4. Copier le Client ID et générer un Secret

**Pour Gitea :**
1. Aller dans Settings → Applications
2. Créer une nouvelle OAuth2 Application
3. Redirect URI : `https://woodpecker.solisws.fr/authorize`
4. Copier le Client ID et Secret

### 3. Lancer Woodpecker

```bash
cd services

# Créer le fichier .env.woodpecker si nécessaire
cp .env.woodpecker.example .env.woodpecker
# Éditer .env.woodpecker avec vos credentials

# Lancer Woodpecker (via commandes standards du manifest)
make generate
make start woodpecker-server
make start woodpecker-agent

# Ou démarrer tout d'un coup (tous les services)
make up
```

Ces commandes :
- Génèrent la configuration Docker Compose depuis le manifest.yml
- Lancent le serveur Woodpecker (interface web sur port 8000)
- Lancent l'agent Woodpecker (exécute les pipelines)
- Configurent automatiquement le reverse proxy Caddy
- Créent un volume persistant pour les données
- Ajoutent Woodpecker au dashboard Homepage

**Accès à l'interface web :**
- Local : http://localhost:8000
- Production : https://woodpecker.${DOMAIN} (via Caddy reverse proxy automatique)

### 4. Builder et pousser l'image CI

L'image `lola-ci-deploy` centralise toute la logique de déploiement (build, tag, push).

```bash
# Builder l'image
make ci-image-build

# Builder et pousser au registry
make ci-image-push
```

**Note :** Cette étape doit être faite **avant** d'activer les repos dans Woodpecker, car les pipelines utilisent cette image.

## Configuration des repositories

### 1. Activer un repo dans Woodpecker

1. Se connecter à l'interface Woodpecker (http://localhost:8000)
2. Cliquer sur "Repositories"
3. Activer les repos `api` et `lolapp`
4. Configurer les secrets (voir section suivante)

### 2. Configurer les secrets

Pour chaque repo activé, ajouter les secrets suivants dans l'interface Woodpecker :

**Secrets communs (api + lolapp) :**

| Nom                  | Valeur                                    | Description                          |
|----------------------|-------------------------------------------|--------------------------------------|
| `docker_password`    | `bj9ZxYD$SeX81e`                          | Mot de passe du registry Docker      |
| `mattermost_webhook` | `https://mattermost.solisws.fr/hooks/...` | Webhook pour notifications (optionel)|

**Note :** Ces secrets sont injectés automatiquement dans les pipelines via la directive `secrets:` dans `.woodpecker.yml`.

### 3. Fichiers de configuration des repos

Chaque repo contient un fichier `.woodpecker.yml` à la racine qui décrit le pipeline.

#### Exemple pour `api/.woodpecker.yml`

```yaml
when:
  - branch: [main, develop]
    event: push

steps:
  deploy:
    image: registry.solisws.fr/lola-ci-deploy:latest
    pull: true
    environment:
      - IMAGE_NAME=registry.solisws.fr/api
      - APP_DISPLAY_NAME=API Laravel
      - PROD_URL=https://api.lola-france.fr
      - TEST_URL=https://api.test.lola-france.fr
      - CI_COMMIT_BRANCH=${CI_COMMIT_BRANCH}
    secrets:
      - docker_password
      - mattermost_webhook
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

#### Exemple pour `lolapp/.woodpecker.yml`

```yaml
when:
  - branch: [main, develop]
    event: push

steps:
  deploy:
    image: registry.solisws.fr/lola-ci-deploy:latest
    pull: true
    environment:
      - IMAGE_NAME=registry.solisws.fr/app
      - APP_DISPLAY_NAME=Frontend Vue.js
      - PROD_URL=https://admin.lola-france.fr
      - TEST_URL=https://admin.test.lola-france.fr
      - CI_COMMIT_BRANCH=${CI_COMMIT_BRANCH}
      - BUILD_ARGS=BUILD_ENV=$${CI_COMMIT_BRANCH == "main" && "production" || "test"}
    secrets:
      - docker_password
      - mattermost_webhook
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
```

## Workflow de déploiement

### Branche `main` (Production)

1. Push sur `main` → Déclenche le pipeline Woodpecker
2. Woodpecker clone le repo
3. Lance l'image `lola-ci-deploy` qui :
   - Incrémente automatiquement la version (ex: `0.0.1` → `0.0.2`)
   - Crée un tag Git et le pousse
   - Build l'image Docker avec 2 tags : `latest` et `0.0.2`
   - Pousse les images au registry
   - Envoie une notification Mattermost
4. Le serveur de production peut ensuite pull l'image `latest` ou `0.0.2`

### Branche `develop` (Test/Staging)

1. Push sur `develop` → Déclenche le pipeline Woodpecker
2. Woodpecker clone le repo
3. Lance l'image `lola-ci-deploy` qui :
   - Build l'image Docker avec le tag `test`
   - Pousse l'image au registry
   - Envoie une notification Mattermost
4. Le serveur de test peut ensuite pull l'image `test`

## Commandes Makefile

Woodpecker utilise les **commandes standards** du système Solis (comme tous les autres services) :

```bash
# Démarrage
make start woodpecker-server    # Démarrer le serveur
make start woodpecker-agent     # Démarrer l'agent
make up                         # Démarrer tous les services (inclut Woodpecker)

# Arrêt
make stop woodpecker-server     # Arrêter le serveur
make stop woodpecker-agent      # Arrêter l'agent
make down                       # Arrêter tous les services

# Redémarrage
make restart woodpecker-server  # Redémarrer le serveur
make restart woodpecker-agent   # Redémarrer l'agent

# Logs
make logs woodpecker-server                 # Afficher les logs du serveur
make logs woodpecker-server FOLLOW=1        # Suivre les logs en temps réel
make logs woodpecker-agent FOLLOW=1         # Suivre les logs de l'agent

# Mise à jour
make update woodpecker-server   # Pull + redémarrer le serveur
make update woodpecker-agent    # Pull + redémarrer l'agent

# Image CI (commandes spécifiques pour l'image de déploiement)
make ci-image-build             # Builder l'image lola-ci-deploy
make ci-image-push              # Builder et pousser au registry
```

## Visualiser les builds

1. Se connecter à l'interface Woodpecker (http://localhost:8000)
2. Cliquer sur le repo (`api` ou `lolapp`)
3. Voir la liste des pipelines exécutés
4. Cliquer sur un pipeline pour voir les logs détaillés de chaque étape

## Différences avec GitHub Actions

| Aspect                 | GitHub Actions                          | Woodpecker CI                           |
|------------------------|-----------------------------------------|-----------------------------------------|
| **Hébergement**        | GitHub (cloud)                          | Auto-hébergé (votre serveur)            |
| **Variables CI**       | `GITHUB_REF_NAME`, `github.ref_name`    | `CI_COMMIT_BRANCH`                      |
| **Workdir**            | `/home/runner/work/{repo}`              | `/woodpecker/src`                       |
| **Checkout**           | Action `actions/checkout@v4`            | Automatique (clone par Woodpecker)      |
| **Secrets**            | GitHub Secrets                          | Interface Woodpecker + env vars         |
| **Workflow**           | `.github/workflows/deploy.yml`          | `.woodpecker.yml`                       |
| **Script central**     | `services/.github/scripts/deploy.sh`    | `lola-ci-deploy` (image Docker)         |

## Dépannage

### Problème : Pipeline bloqué sur "pending"

**Cause :** L'agent n'est pas connecté au serveur.

**Solution :**
```bash
make logs woodpecker-agent FOLLOW=1
# Vérifier que l'agent se connecte correctement
# Si erreur d'authentification, vérifier WOODPECKER_AGENT_SECRET
```

### Problème : Image lola-ci-deploy introuvable

**Cause :** L'image n'a pas été buildée ou poussée au registry.

**Solution :**
```bash
make ci-image-push
```

### Problème : Erreur de permission Docker

**Cause :** L'agent n'a pas accès au socket Docker.

**Solution :** Vérifier que `/var/run/docker.sock` est bien monté dans le conteneur agent (voir `config/manifest.yml`).

### Problème : Les secrets ne sont pas injectés

**Cause :** Les secrets ne sont pas configurés dans l'interface Woodpecker.

**Solution :**
1. Aller dans Woodpecker → Repository → Settings → Secrets
2. Ajouter `docker_password` et `mattermost_webhook`

## Intégration avec l'infrastructure Solis

### Reverse proxy Caddy (automatique)

Woodpecker est exposé automatiquement via Caddy reverse proxy sur `woodpecker.${DOMAIN}` grâce à la définition `subdomain: woodpecker` dans le manifest.yml.

**Aucune configuration manuelle nécessaire** - Le générateur crée automatiquement :
- La route Caddy avec TLS (Cloudflare DNS)
- L'ajout au réseau `proxy-network`
- Le routage vers `woodpecker-server:8000`

### Dashboard Homepage (automatique)

Woodpecker apparaît dans le dashboard Homepage (groupe "Outils") avec :
- Titre : "Woodpecker CI"
- Description : "Serveur CI/CD auto-hébergé"
- Icône : 🐦 (mdi-bird)
- Lien direct vers l'interface web

## Ressources

- Documentation officielle Woodpecker : https://woodpecker-ci.org/docs
- Syntaxe des workflows : https://woodpecker-ci.org/docs/usage/workflow-syntax
- Configuration des secrets : https://woodpecker-ci.org/docs/usage/secrets
