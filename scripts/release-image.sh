#!/usr/bin/env bash
set -euo pipefail

# Called by semantic-release (prepare step) on GitHub Actions, after Buildx setup and GHCR login.
version=${1:?Usage: scripts/release-image.sh VERSION}
repository=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set, e.g. owner/proxmox-admin}
image="ghcr.io/$(printf '%s' "$repository" | tr '[:upper:]' '[:lower:]')"

# The source label links the GHCR package to the repository (and its permissions).
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --provenance=mode=max \
  --sbom=true \
  --label "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/${repository}" \
  --label "org.opencontainers.image.version=${version}" \
  --tag "${image}:${version}" \
  --tag "${image}:${version%.*}" \
  --tag "${image}:${version%%.*}" \
  --tag "${image}:latest" \
  .
