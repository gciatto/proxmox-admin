#!/usr/bin/env bash
set -euo pipefail

# Called by semantic-release (prepare step) on GitHub Actions, after Buildx setup and registry logins.
# With DOCKERHUB_USERNAME set, the image is also pushed to Docker Hub as DOCKERHUB_USERNAME/<repository name>.
version=${1:?Usage: scripts/release-image.sh VERSION}
repository=${GITHUB_REPOSITORY:?GITHUB_REPOSITORY must be set, e.g. owner/proxmox-admin}
repository_lc=$(printf '%s' "$repository" | tr '[:upper:]' '[:lower:]')
images=("ghcr.io/${repository_lc}")
if [ -n "${DOCKERHUB_USERNAME:-}" ]; then
  images+=("docker.io/${DOCKERHUB_USERNAME}/${repository_lc#*/}")
fi
tags=()
for image in "${images[@]}"; do
  for tag in "$version" "${version%.*}" "${version%%.*}" latest; do
    tags+=(--tag "${image}:${tag}")
  done
done

# The source label links the GHCR package to the repository (and its permissions).
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  --push \
  --provenance=mode=max \
  --sbom=true \
  --label "org.opencontainers.image.source=${GITHUB_SERVER_URL:-https://github.com}/${repository}" \
  --label "org.opencontainers.image.version=${version}" \
  "${tags[@]}" \
  .
