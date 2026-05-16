#!/bin/bash
# Build + push the api and web Docker images to the private registry.
# Matches the pattern in eport.hippa/docker-publish.sh.
set -euo pipefail

REGISTRY="docker-repository.eport.fi"
API_IMAGE="searchassistant-api"
WEB_IMAGE="searchassistant-web"
TAG="${TAG:-latest}"

# Web SPA needs the API base URL baked in at build time (Vite inlines env vars).
VITE_API_BASE="${VITE_API_BASE:-https://searchassistant.eport.fi}"

API_FULL="${REGISTRY}/${API_IMAGE}:${TAG}"
WEB_FULL="${REGISTRY}/${WEB_IMAGE}:${TAG}"

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$REPO_ROOT"

echo "==> Building API image (linux/amd64)"
docker build \
    --platform linux/amd64 \
    -f apps/api/Dockerfile \
    -t "${API_IMAGE}:${TAG}" \
    apps/api

echo "==> Building web image (linux/amd64) with VITE_API_BASE=${VITE_API_BASE}"
docker build \
    --platform linux/amd64 \
    --build-arg "VITE_API_BASE=${VITE_API_BASE}" \
    -f apps/web/Dockerfile \
    -t "${WEB_IMAGE}:${TAG}" \
    apps/web

echo "==> Tagging for ${REGISTRY}"
docker tag "${API_IMAGE}:${TAG}" "${API_FULL}"
docker tag "${WEB_IMAGE}:${TAG}" "${WEB_FULL}"

echo "==> Pushing ${API_FULL}"
docker push "${API_FULL}"
echo "==> Pushing ${WEB_FULL}"
docker push "${WEB_FULL}"

echo "==> Cleaning up dangling layers and build cache"
docker image prune -f
docker builder prune -f 2>/dev/null || true

echo ""
echo "✓ Pushed ${API_FULL}"
echo "✓ Pushed ${WEB_FULL}"
