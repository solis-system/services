#!/bin/bash
set -e

echo "🚀 Starting Docker deploy for $IMAGE_NAME"
echo "🔀 Current branch: $GITHUB_REF_NAME"

# --- Step 0: Detect environment and prepare tags
DOCKER_TAGS=()

if [[ "$GITHUB_REF_NAME" == "main" ]]; then
  echo "🏷️ Environment: Production (main)"

  # Fetch latest tag and increment version
  git fetch --tags
  TAG=$(git describe --tags "$(git rev-list --tags --max-count=1)" 2>/dev/null || echo "")
  echo "Latest tag: ${TAG:-none}"

  IFS='.' read -r -a V <<< "${TAG:-0.0.0}"
  NEW_TAG="${V[0]:-0}.${V[1]:-0}.$(( ${V[2]:-0} + 1 ))"
  echo "🆕 New version: $NEW_TAG"

  # Check if tag already exists
  if git ls-remote --tags origin | grep -q "refs/tags/${NEW_TAG}$"; then
    echo "⚠️ Tag $NEW_TAG already exists on remote, skipping tag creation."
  else
    echo "🏷️ Creating new tag: $NEW_TAG"
    git config --global user.email "actions@github.com"
    git config --global user.name "GitHub Actions"
    git tag "$NEW_TAG"
    git push origin "$NEW_TAG"
  fi

  # Production tags: latest + version
  DOCKER_TAGS+=("latest" "$NEW_TAG")

elif [[ "$GITHUB_REF_NAME" == "develop" ]]; then
  echo "🏷️ Environment: Test (develop)"

  # Test tag only
  DOCKER_TAGS+=("test")

else
  echo "🏷️ Environment: Branch ($GITHUB_REF_NAME)"
  DOCKER_TAGS+=("$GITHUB_REF_NAME")
fi

echo "🔐 Logging into Docker registry..."
echo "$DOCKER_PASSWORD" | docker login "https://registry.solisws.fr" -u "admin" --password-stdin

# --- Step 1: Build with all tags
echo "🏗️ Building Docker image: $IMAGE_NAME"
echo "📦 Tags: ${DOCKER_TAGS[*]}"

DOCKER_BUILD_ARGS=()
for tag in "${DOCKER_TAGS[@]}"; do
  DOCKER_BUILD_ARGS+=("-t" "$IMAGE_NAME:$tag")
done

# Convert BUILD_ARGS (KEY1=val1,KEY2=val2) to --build-arg format
if [ -n "$BUILD_ARGS" ]; then
  echo "🔧 Build arguments: $BUILD_ARGS"
  IFS=',' read -ra ARGS <<< "$BUILD_ARGS"
  for arg in "${ARGS[@]}"; do
    DOCKER_BUILD_ARGS+=("--build-arg" "$arg")
  done
fi

docker build "${DOCKER_BUILD_ARGS[@]}" .

# --- Step 2: Push all tags
echo "📤 Pushing images..."
for tag in "${DOCKER_TAGS[@]}"; do
  docker push "$IMAGE_NAME:$tag"
done

# --- Step 3: Mattermost notification
DEFAULT_WEBHOOK="https://mattermost.solisws.fr/hooks/c97qgck97bgz3ju8ueu1gdx5uc"
WEBHOOK=${MATTERMOST_WEBHOOK:-$DEFAULT_WEBHOOK}

if [ -n "$WEBHOOK" ]; then
  echo "💬 Sending Mattermost notification..."

  # Extract image name (after last /)
  IMAGE_SHORT=$(echo "$IMAGE_NAME" | awk -F'/' '{print $NF}')

  # Build registry URL
  REGISTRY_URL="https://registry.solisws.fr/#!/taglist/${IMAGE_SHORT}"

  # Determine environment and service URL
  if [[ "$GITHUB_REF_NAME" == "main" ]]; then
    ENV_TYPE="Production"
    SERVICE_URL="${PROD_URL}"
    PRIMARY_TAG="${DOCKER_TAGS[1]}"  # Version tag (not "latest")
  else
    ENV_TYPE="Test"
    SERVICE_URL="${TEST_URL}"
    PRIMARY_TAG="${DOCKER_TAGS[0]}"  # test or branch name
  fi

  # Build display name (use provided or fallback to image name)
  DISPLAY_NAME="${APP_DISPLAY_NAME:-$IMAGE_SHORT}"

  # Build message parts
  MESSAGE="#### 🚀 Déploiement: **${DISPLAY_NAME}**\n"
  MESSAGE+="📦 Version: [${PRIMARY_TAG}](${REGISTRY_URL})"

  # Add service URL if provided
  if [ -n "$SERVICE_URL" ]; then
    MESSAGE+="\n🌐 Service: ${SERVICE_URL}"
  fi

  curl -X POST -H 'Content-Type: application/json' \
       -d "{\"text\":\"${MESSAGE}\"}" \
       "$WEBHOOK"
else
  echo "ℹ️ No Mattermost webhook provided — skipping notification."
fi

echo "✅ Deployment complete."