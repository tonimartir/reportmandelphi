#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
DOCKER_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
REPO_ROOT=$(CDPATH= cd -- "$DOCKER_DIR/../../.." && pwd)

VERSION="${1:-}"
DOCKER_HUB_REPO="${DOCKER_HUB_REPO:-tonimartir/reportman-web}"
LOCAL_IMAGE_NAME="${LOCAL_IMAGE_NAME:-reportman-web}"
REPWEBEXE_SOURCE="${REPWEBEXE_SOURCE:-server/docker/web/artifacts/linux64/repwebexe}"
PUSH_LATEST="${PUSH_LATEST:-1}"

if [ -z "$VERSION" ]; then
  echo "Usage: $0 <version>"
  echo "Example: $0 1.0.0"
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: docker is not available in this WSL session."
  exit 1
fi

if [ ! -f "$REPO_ROOT/$REPWEBEXE_SOURCE" ]; then
  echo "Error: Linux binary not found at: $REPO_ROOT/$REPWEBEXE_SOURCE"
  echo "Build or copy repwebexe Linux there before running this script."
  exit 1
fi

echo "=== [1/4] Build local image ==="
docker build \
  -f "$DOCKER_DIR/Dockerfile" \
  --build-arg REPWEBEXE_SOURCE="$REPWEBEXE_SOURCE" \
  -t "$LOCAL_IMAGE_NAME:$VERSION" \
  -t "$LOCAL_IMAGE_NAME:latest" \
  "$REPO_ROOT"

echo "=== [2/4] Tag Docker Hub image ==="
docker tag "$LOCAL_IMAGE_NAME:$VERSION" "$DOCKER_HUB_REPO:$VERSION"
if [ "$PUSH_LATEST" = "1" ]; then
  docker tag "$LOCAL_IMAGE_NAME:latest" "$DOCKER_HUB_REPO:latest"
fi

echo "=== [3/4] Push version tag ==="
docker push "$DOCKER_HUB_REPO:$VERSION"

echo "=== [4/4] Push latest tag ==="
if [ "$PUSH_LATEST" = "1" ]; then
  docker push "$DOCKER_HUB_REPO:latest"
else
  echo "Skipping latest because PUSH_LATEST=$PUSH_LATEST"
fi

echo "=== Published successfully ==="
echo "Image: $DOCKER_HUB_REPO:$VERSION"
if [ "$PUSH_LATEST" = "1" ]; then
  echo "Image: $DOCKER_HUB_REPO:latest"
fi