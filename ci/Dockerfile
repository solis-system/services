# Dockerfile pour l'image lola-ci-deploy
# Cette image centralise toute la logique CI/CD (build, tag, push, deploy)
# Usage: docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
#        -e IMAGE_NAME=registry.solisws.fr/api \
#        -e CI_COMMIT_BRANCH=main \
#        lola-ci-deploy:latest

FROM docker:27-cli

# Installation des dépendances nécessaires
RUN apk add --no-cache \
    bash \
    curl \
    git \
    jq \
    openssh-client \
    ca-certificates

# Créer le répertoire pour les scripts CI
RUN mkdir -p /ci

# Copier le script de déploiement
COPY deploy.sh /ci/deploy.sh
RUN chmod +x /ci/deploy.sh

# Définir le workdir
WORKDIR /workspace

# Définir l'entrypoint
ENTRYPOINT ["/ci/deploy.sh"]
