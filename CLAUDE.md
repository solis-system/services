# CLAUDE.md

Ce fichier fournit des directives à Claude Code (claude.ai/code) lors du travail sur le code de ce dépôt.

## Vue d'ensemble du projet

Ceci est un générateur de configuration Docker pour l'infrastructure Solis. L'outil lit les définitions de services depuis `config/manifest.yml` et génère des fichiers Docker Compose, la configuration du reverse proxy Caddy, et la configuration du tableau de bord Homepage.

## Architecture de base

**Flux de configuration :**
1. Les définitions de services sont maintenues dans `config/manifest.yml` (source unique de vérité)
2. `src/main.js` (classe ConfigGenerator) orchestre le processus de génération
3. Les fichiers de sortie sont générés dans le répertoire `dist/` :
   - `docker-compose.yml` - Services de production
   - `docker-compose.dev.yml` - Surcharges pour le développement
   - `proxy.docker-compose.yml` - Reverse proxy Caddy
   - `Caddyfile` - Routes du reverse proxy
   - `homepage_services.yaml` - Configuration du tableau de bord

**Structure de définition des services :**
Chaque service dans `manifest.yml` nécessite au minimum un champ `image`. Les champs optionnels incluent :
- `subdomain`, `internal_port` - Pour le routage du reverse proxy
- `environment`, `env_file`, `volumes`, `ports` - Configuration Docker
- `title`, `description`, `icon`, `group` - Affichage dans le tableau de bord Homepage
- `auth` - Mettre à "basic" pour activer l'authentification basique via Caddy
- `storage` - Mettre à "internal" pour la création automatique de volumes
- `dev_path` - Chemin vers le Dockerfile de développement pour le mode développement local

**Configuration d'environnement :**
- Variables d'environnement principales dans `.env` (DOMAIN, ENV, BASIC_AUTH, CLOUDFLARE_API_TOKEN, EMAIL)
- Les fichiers env spécifiques aux services suivent le pattern `.env.api.prod`, `.env.api.test` et sont automatiquement copiés dans dist/
- Paramètres centralisés dans `src/settings.js`

## Commandes courantes

### Générer les fichiers de configuration
```bash
make generate              # Génère tous les fichiers de config dans dist/
make generate ENV=production  # Définit explicitement l'environnement
```

### Opérations Docker
```bash
make up                    # Génère les configs et démarre tous les conteneurs
make up ENV=development    # Démarre avec les surcharges de dev (inclut les builds depuis dev_path)
make down                  # Arrête tous les conteneurs
make restart               # Redémarrage complet (down + up)

# Opérations sur un seul service
make start SERVICE=nocodb  # Démarre un service spécifique
make stop SERVICE=nocodb   # Arrête un service spécifique
make restart_one SERVICE=nocodb  # Redémarre un service spécifique

make ps                    # Liste les conteneurs en cours d'exécution
```

### Exécution directe
```bash
npm start                  # Exécute le générateur directement (utilise bun en interne)
bun src/main.js           # Exécution directe alternative
```

## Workflow de développement

**Ajouter un nouveau service :**
1. Ajouter la définition du service dans `config/manifest.yml`
2. Exécuter `make generate` pour créer les configs mises à jour
3. Vérifier les fichiers générés dans `dist/`
4. Déployer avec `make up`

**Mode développement :**
Les services avec `dev_path` défini seront construits depuis la source locale quand `ENV=development` :
```bash
make up ENV=development    # Construit les conteneurs depuis dev_path et monte les sources comme volumes
```

**Routes Caddy personnalisées :**
Ajouter des règles de reverse proxy personnalisées dans `config/Caddyfile.custom`. Celles-ci sont ajoutées aux routes auto-générées et supportent la substitution des variables `{$DOMAIN}` et `{$CLOUDFLARE_API_TOKEN}`.

## Structure du projet

```
config/
  manifest.yml           # Définitions des services (entrée principale)
  Caddyfile.custom      # Routes Caddy personnalisées
  Dockerfile-caddy      # Build du conteneur Caddy
  WEBDEV.conf          # Configuration de l'application WEBDEV
  homepage/            # Configs statiques du tableau de bord Homepage

src/
  main.js              # Classe ConfigGenerator - orchestre la génération
  settings.js          # Configuration d'environnement et constantes
  caddy-templates.js   # Templates de configuration Caddy
  utils/
    file.js            # Utilitaires pour opérations YAML/fichiers
    logger.js          # Configuration du logger Winston

dist/                  # Sortie générée (gitignored)
```

## Groupes de services

Les services sont organisés en groupes pour le tableau de bord Homepage :
- Groupe 1 : "Lolapp" - Services principaux de l'application
- Groupe 2 : "Outils" - Services utilitaires
- Groupe 3 : "Data" - Services de données

Les groupes sont définis dans `src/settings.js` sous `HOME_PAGE_GROUPS`.

## Architecture réseau

Tous les services et le proxy Caddy s'exécutent sur le réseau Docker externe `proxy-network`. Caddy gère la terminaison TLS et route le trafic vers les services en fonction de la configuration des sous-domaines.