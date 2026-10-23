#!/usr/bin/env bash
#
# Build the governance-hub dynamic plugin OCI image and push it to quay.io.
#
# Prerequisites:
#   - Docker (with buildx) or Podman installed
#   - Logged in to quay.io:
#       docker login quay.io    (or: podman login quay.io)
#   - quay.io/mcombi/rhdh-gov-hub repository exists and you have push access
#
# Usage:
#   bash governance-hub-plugin/build-and-push.sh           # push :latest
#   bash governance-hub-plugin/build-and-push.sh v0.1.0    # push :v0.1.0
#
# After pushing, update developer-hub/k8s/instance/dynamic-plugins-configmap.yaml
# to reference the new tag/digest if you want to pin to a specific version.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="quay.io/mcombi/rhdh-gov-hub"
TAG="${1:-latest}"

echo "==> Building ${IMAGE}:${TAG} from ${SCRIPT_DIR}..."

# Use docker buildx if available, fall back to docker build or podman
if docker buildx version >/dev/null 2>&1; then
  docker buildx build \
    --platform linux/amd64 \
    --tag "${IMAGE}:${TAG}" \
    --push \
    "${SCRIPT_DIR}"
elif command -v podman >/dev/null 2>&1; then
  podman build \
    --platform linux/amd64 \
    --tag "${IMAGE}:${TAG}" \
    "${SCRIPT_DIR}"
  podman push "${IMAGE}:${TAG}"
else
  docker build \
    --tag "${IMAGE}:${TAG}" \
    "${SCRIPT_DIR}"
  docker push "${IMAGE}:${TAG}"
fi

echo "==> Pushed ${IMAGE}:${TAG}"
echo ""
echo "    To use a digest-pinned reference (recommended for production):"
echo "      docker inspect --format='{{index .RepoDigests 0}}' ${IMAGE}:${TAG}"
echo "    Then update dynamic-plugins-configmap.yaml:"
echo "      package: oci://${IMAGE}@sha256:<digest>"
