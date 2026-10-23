# Multi-stage build for the @mcombi/backstage-plugin-governance-hub dynamic plugin.
#
# Stage 1: Build the plugin using Node.js and @backstage/cli.
#   - Installs dependencies
#   - Runs `backstage-cli package build` (produces CommonJS bundle in dist/)
#   - Runs `backstage-cli package export-dynamic-plugin --clean` (produces dist-dynamic/)
#
# Stage 2: Minimal OCI image from scratch.
#   RHDH's dynamic plugin loader expects an OCI image whose root filesystem
#   contains the exported plugin artifacts at /.
#   The FROM scratch layer produces the smallest possible image with no shell or
#   OS overhead.
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
# RHDH mounts the image filesystem and loads the plugin from /package/dist-dynamic
# The export-dynamic command places artifacts in dist-dynamic/ relative to /app.
FROM scratch
COPY --from=build /app/dist-dynamic /
