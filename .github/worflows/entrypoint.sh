#!/bin/bash
set -e

echo "🚀 Starting Docker deploy for $IMAGE_NAME"
echo "🔀 Current branch: $GITHUB_REF_NAME"

# Determine environment
if [[ "$GITHUB_REF_NAME" == "main" ]]; then
  ENV_TAG="prod"
elif [[ "$GITHUB_REF_NAME" == "develop" ]]; then
  ENV_TAG="test"
else
  ENV_TAG="$GITHUB_REF_NAME"
fi
echo "🏷️ Environment: $ENV_TAG"

# --- Step 1: Get latest Git tag
git fetch --tags
TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "")
echo "Latest tag: $TAG"

# --- Step 2: Increment version
if [ -z "$TAG" ]; then
  VERSION="0.0.0"
else
  VERSION="$TAG"
fi
IFS='.' read -r -a V <<< "$VERSION"
NEW_TAG="${V[0]:-0}.${V[1]:-0}.$(( ${V[2]:-0} + 1 ))"
echo "🆕 New version: $NEW_TAG"

git config --global user.email "actions@github.com"
git config --global user.name "GitHub Actions"
git tag "$NEW_TAG"
git push origin "$NEW_TAG"

# --- Step 3: Login to Docker registry
echo "🔐 Logging into Docker registry..."
echo "$DOCKER_PASSWORD" | docker login "$DOCKER_REGISTRY" -u "$DOCKER_USERNAME" --password-stdin

# --- Step 4: Build and push
echo "🏗️ Building image $IMAGE_NAME:$NEW_TAG ($ENV_TAG)..."

docker build \
  -t "$IMAGE_NAME:${ENV_TAG}" \
  -t "$IMAGE_NAME:latest-${ENV_TAG}" \
  -t "$IMAGE_NAME:$NEW_TAG" .

docker push "$IMAGE_NAME:${ENV_TAG}"
docker push "$IMAGE_NAME:latest-${ENV_TAG}"
docker push "$IMAGE_NAME:$NEW_TAG"

# --- Step 5: Mattermost notification (optional)
DEFAULT_WEBHOOK="https://mattermost.solisws.fr/hooks/c97qgck97bgz3ju8ueu1gdx5uc"
WEBHOOK=${MATTERMOST_WEBHOOK:-$DEFAULT_WEBHOOK}

if [ -n "$MATTERMOST_WEBHOOK" ]; then
  echo "💬 Sending Mattermost notification..."
  curl -X POST -H 'Content-Type: application/json' \
       -d "{\"text\":\":rocket: Deploy of *$IMAGE_NAME:$NEW_TAG* completed successfully.\"}" \
       "$WEBHOOK"
else
  echo "ℹ️ No Mattermost webhook provided — skipping notification."
fi

echo "✅ Done."