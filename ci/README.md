# lola-ci-deploy - Image Docker CI/CD

Image Docker qui centralise toute la logique de déploiement pour les applications Solis (API et Frontend).

## Objectif

Cette image embarque le script `deploy.sh` et tous les outils nécessaires pour :
- Builder les images Docker
- Créer et pousser les tags Git (versioning automatique)
- Pousser les images au registry Docker
- Envoyer des notifications Mattermost

## Contenu

- **Base :** `docker:27-cli` (client Docker officiel)
- **Outils installés :**
  - `bash` - Exécution du script
  - `curl` - Notifications HTTP
  - `git` - Gestion des tags
  - `jq` - Manipulation JSON
  - `openssh-client` - Accès SSH (si nécessaire)
  - `ca-certificates` - Certificats SSL

## Construction

```bash
# Depuis le repo services/
docker build -t registry.solisws.fr/lola-ci-deploy:latest ./ci

# Ou via Makefile
make ci-image-build
```

## Push au registry

```bash
docker push registry.solisws.fr/lola-ci-deploy:latest

# Ou via Makefile
make ci-image-push
```

## Usage dans GitHub Actions

L'image est utilisée dans les workflows GitHub Actions des repos `api` et `lolapp` :

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Deploy
        run: |
          docker run --rm \
            -v /var/run/docker.sock:/var/run/docker.sock \
            -v ${{ github.workspace }}:/workspace \
            -w /workspace \
            -e IMAGE_NAME=registry.solisws.fr/api \
            -e CI_COMMIT_BRANCH=${{ github.ref_name }} \
            -e APP_DISPLAY_NAME="API Laravel" \
            -e PROD_URL=https://api.lola-france.fr \
            -e TEST_URL=https://api.test.lola-france.fr \
            -e DOCKER_PASSWORD=${{ secrets.DOCKER_PASSWORD }} \
            -e MATTERMOST_WEBHOOK=${{ secrets.MATTERMOST_WEBHOOK }} \
            registry.solisws.fr/lola-ci-deploy:latest
```

## Variables d'environnement

### Obligatoires

| Variable           | Description                                  | Exemple                        |
|--------------------|----------------------------------------------|--------------------------------|
| `IMAGE_NAME`       | Nom complet de l'image Docker                | `registry.solisws.fr/api`      |
| `CI_COMMIT_BRANCH` | Branche Git courante                         | `main`, `develop`              |
| `DOCKER_PASSWORD`  | Mot de passe du registry Docker              | (secret)                       |

### Optionnelles

| Variable             | Description                              | Exemple                        |
|----------------------|------------------------------------------|--------------------------------|
| `APP_DISPLAY_NAME`   | Nom d'affichage dans les notifications  | `API Laravel`                  |
| `PROD_URL`           | URL de l'environnement de production     | `https://api.lola-france.fr`   |
| `TEST_URL`           | URL de l'environnement de test           | `https://api.test.lola-france.fr` |
| `BUILD_ARGS`         | Arguments Docker build (format: KEY=val,KEY2=val2) | `BUILD_ENV=production` |
| `MATTERMOST_WEBHOOK` | Webhook Mattermost pour notifications    | `https://mattermost.../hooks/...` |

## Logique du script deploy.sh

### Branche `main` (Production)

1. Récupère le dernier tag Git (ex: `0.0.1`)
2. Incrémente la version patch (ex: `0.0.2`)
3. Crée le nouveau tag Git et le pousse
4. Build l'image avec 2 tags : `latest` et `0.0.2`
5. Pousse les 2 tags au registry
6. Envoie une notification Mattermost

### Branche `develop` (Test)

1. Build l'image avec le tag `test`
2. Pousse le tag au registry
3. Envoie une notification Mattermost

### Autres branches

1. Build l'image avec le nom de la branche comme tag
2. Pousse le tag au registry

## Montage du socket Docker

L'image nécessite l'accès au socket Docker de l'hôte pour pouvoir construire et pousser les images :

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

⚠️ **Sécurité :** Cela donne au conteneur un accès complet au daemon Docker. Assurez-vous que les pipelines CI ne sont exécutés que sur des repos de confiance.

## Développement local

Pour tester l'image localement :

```bash
# Builder l'image
docker build -t lola-ci-deploy:test ./ci

# Lancer un test (depuis un repo git avec Dockerfile)
docker run --rm \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v $(pwd):/workspace \
  -w /workspace \
  -e IMAGE_NAME=registry.solisws.fr/test \
  -e CI_COMMIT_BRANCH=develop \
  -e DOCKER_PASSWORD=your_password \
  lola-ci-deploy:test
```

## Mise à jour

Quand le script `deploy.sh` est modifié :

1. Rebuilder l'image : `make ci-image-build`
2. Pousser au registry : `make ci-image-push`
3. Les prochaines exécutions CI utiliseront automatiquement la nouvelle version
