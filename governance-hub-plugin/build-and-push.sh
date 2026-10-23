#!/usr/bin/env bash
#
# Build the governance-hub dynamic plugin OCI image and push it to quay.io.
#
# RHDH 1.10 requires the OCI image to carry the `io.backstage.dynamic-packages`
# annotation so the install-dynamic-plugins init container can discover plugins.
# This script offers two build paths:
#
#   Path A (recommended): @red-hat-developer-hub/cli plugin package
#     Uses `rhdh-cli plugin package --tag <image> --push` which handles export,
#     OCI image creation, and annotation injection automatically.
#     Requires: Node 20+, npm, quay.io login
#
#   Path B (Dockerfile fallback): docker/podman build
#     The Dockerfile manually runs the export step and adds the annotation via
#     LABEL. Use if the rhdh-cli path is unavailable.
#     Requires: Docker with buildx or Podman, quay.io login
#
# Prerequisites:
#   - Logged in to quay.io:
#       docker login quay.io    (or: podman login quay.io)
#   - quay.io/mcombi/rhdh-gov-hub repository exists and you have push access
#
# Usage:
#   bash governance-hub-plugin/build-and-push.sh           # push :latest
#   bash governance-hub-plugin/build-and-push.sh v0.1.0    # push :v0.1.0
#   SKIP_RHDH_CLI=1 bash governance-hub-plugin/build-and-push.sh   # force Dockerfile path
#
# After pushing, set disabled: false in:
#   developer-hub/k8s/instance/dynamic-plugins-configmap.yaml
# then apply: oc apply -f developer-hub/k8s/instance/dynamic-plugins-configmap.yaml
# and restart: oc rollout restart deployment/backstage-developer-hub -n rhdh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="quay.io/mcombi/rhdh-gov-hub"
TAG="${1:-latest}"

# ── Path A: rhdh-cli plugin package (recommended for RHDH 1.10+) ────────────
if [[ -z "${SKIP_RHDH_CLI:-}" ]] && command -v node >/dev/null 2>&1; then
  echo "==> Building ${IMAGE}:${TAG} via rhdh-cli plugin package (Path A)..."
  cd "${SCRIPT_DIR}"
  npm install --legacy-peer-deps --no-audit
  npm run tsc
  npm run build
  # rhdh-cli plugin package handles export-dynamic + OCI annotation + push
  npx rhdh-cli plugin package --tag "${IMAGE}:${TAG}" --push
  echo "==> Pushed ${IMAGE}:${TAG} (with io.backstage.dynamic-packages annotation)"
  cd - >/dev/null
  exit 0
fi

# ── Path B: Dockerfile build (fallback) ─────────────────────────────────────
echo "==> Building ${IMAGE}:${TAG} via Dockerfile (Path B)..."
echo "    NOTE: Dockerfile adds the io.backstage.dynamic-packages LABEL manually."

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
echo ""
echo "    After rebuilding, enable the plugin:"
echo "      1. Set disabled: false in developer-hub/k8s/instance/dynamic-plugins-configmap.yaml"
echo "      2. oc apply -f developer-hub/k8s/instance/dynamic-plugins-configmap.yaml"
echo "      3. oc rollout restart deployment/backstage-developer-hub -n rhdh"
