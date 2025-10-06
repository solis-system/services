#!/bin/bash
set -e

echo "🚀 Starting Docker deploy for $IMAGE_NAME"
echo "🔀 Current branch: $GITHUB_REF_NAME"

# --- Step 0: Detect environment
if [[ "$GITHUB_REF_NAME" == "main" ]]; then
  ENV_TAG="prod"
elif [[ "$GITHUB_REF_NAME" == "develop" ]]; then
  ENV_TAG="test"
else
  ENV_TAG="$GITHUB_REF_NAME"
fi
echo "🏷️ Environment: $ENV_TAG"

# --- Step 1: Fetch latest tag and increment version
git fetch --tags
TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "")
echo "Latest tag: ${TAG:-none}"

IFS='.' read -r -a V <<< "${TAG:-0.0.0}"
NEW_TAG="${V[0]:-0}.${V[1]:-0}.$(( ${V[2]:-0} + 1 ))"
echo "🆕 New version candidate: $NEW_TAG"

# --- Step 2: Check if tag already exists
if git ls-remote --tags origin | grep -q "refs/tags/${NEW_TAG}$"; then
  echo "⚠️ Tag $NEW_TAG already exists on remote, skipping tag creation."
else
  echo "🏷️ Creating new tag: $NEW_TAG"
  git config --global user.email "actions@github.com"
  git config --global user.name "GitHub Actions"
  git tag "$NEW_TAG"
  git push origin "$NEW_TAG"
fi

echo "🔐 Logging into Docker registry..."
echo "$DOCKER_PASSWORD" | docker login "https://registry.solisws.fr" -u "admin" --password-stdin

# --- Step 4: Build and push
echo "🏗️ Building Docker image: $IMAGE_NAME"
echo "📦 Tags: $ENV_TAG, latest-${ENV_TAG}, $NEW_TAG"

docker build \
  -t "$IMAGE_NAME:${ENV_TAG}" \
  -t "$IMAGE_NAME:latest-${ENV_TAG}" \
  -t "$IMAGE_NAME:$NEW_TAG" .

echo "📤 Pushing images..."
docker push "$IMAGE_NAME:${ENV_TAG}"
docker push "$IMAGE_NAME:latest-${ENV_TAG}"
docker push "$IMAGE_NAME:$NEW_TAG"

# --- Step 5: Mattermost notification
DEFAULT_WEBHOOK="https://mattermost.solisws.fr/hooks/c97qgck97bgz3ju8ueu1gdx5uc"
WEBHOOK=${MATTERMOST_WEBHOOK:-$DEFAULT_WEBHOOK}

if [ -n "$WEBHOOK" ]; then
  echo "💬 Sending Mattermost notification..."
  curl -X POST -H 'Content-Type: application/json' \
       -d "{\"text\":\":rocket: *$IMAGE_NAME:$NEW_TAG* deployed successfully on *$ENV_TAG*.\"}" \
       "$WEBHOOK"
else
  echo "ℹ️ No Mattermost webhook provided — skipping notification."
fi

echo "✅ Deployment complete."