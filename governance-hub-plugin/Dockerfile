# Multi-stage build for the @mcombi/backstage-plugin-governance-hub dynamic plugin.
#
# Stage 1: Build the plugin using Node.js and @red-hat-developer-hub/cli.
#   - Installs dependencies
#   - Runs `backstage-cli package build` (produces CommonJS bundle in dist/)
#   - Runs `rhdh-cli package export-dynamic-plugin --clean` (produces dist-dynamic/)
#
# Stage 2: Minimal OCI image from scratch.
#   RHDH 1.10's dynamic plugin loader requires the image to carry the
#   `io.backstage.dynamic-packages` OCI annotation (JSON array) so the
#   install-dynamic-plugins.py init-container can discover the plugin.
#   The annotation is added via LABEL in this stage.
#
# Build and push:
#   bash governance-hub-plugin/build-and-push.sh
#   (or: docker buildx build --platform linux/amd64 -t quay.io/mcombi/rhdh-gov-hub:latest --push .)
FROM node:20-slim AS build

WORKDIR /app

# Install dependencies first for better layer caching
COPY package.json ./
RUN npm install --legacy-peer-deps --no-audit --include=peer

# Copy source and build configuration
COPY tsconfig.json ./
COPY src/ ./src/

# Generate TypeScript declaration files (dist-types/) required by backstage-cli package build
RUN npm run tsc

# Build the plugin bundle and export for dynamic plugin loading
RUN npm run build && npm run export-dynamic

# ── Final stage: scratch OCI image ──────────────────────────────────────────
# RHDH 1.10 install-dynamic-plugins.py reads the `io.backstage.dynamic-packages`
# OCI image annotation (added via LABEL) to discover plugin packages.
# Without this annotation the init container raises:
#   "No plugins found in OCI image … The image might not contain the
#    'io.backstage.dynamic-packages' annotation."
# Format: JSON array of {name, version, path} objects (path relative to image root).
FROM scratch
LABEL "io.backstage.dynamic-packages"='[{"name":"@mcombi/backstage-plugin-governance-hub","version":"0.1.0","path":"./"}]'
COPY --from=build /app/dist-dynamic /
