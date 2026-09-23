#!/bin/sh
# =============================================================================
# LAYER 1 — PORTABLE LOGIC (platform-blind)
# image-build.sh: docker build with build metadata stamped in.
#
# Contract (env vars):
#   REGISTRY      required  e.g. ghcr.io | registry.gitlab.com | artifactory.local
#   IMAGE         required  e.g. org/app
#   TAG           optional  image tag (default: short git sha, else "dev")
#   VERSION, COMMIT, BUILD_ORIGIN   same meaning as in compile.sh
#
# Outputs: local image ${REGISTRY}/${IMAGE}:${TAG} (+ :latest),
#          .image-ref file consumed by image-push.sh
# =============================================================================
set -eu

: "${REGISTRY:?REGISTRY is required (e.g. ghcr.io)}"
: "${IMAGE:?IMAGE is required (e.g. org/app)}"

git config --global --add safe.directory "$(pwd)" 2>/dev/null || true
TAG="${TAG:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo dev)}"
VERSION="${VERSION:-0.1.0}"
COMMIT="${COMMIT:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)}"
BUILD_ORIGIN="${BUILD_ORIGIN:-local}"

REF="${REGISTRY}/${IMAGE}:${TAG}"

echo "==> docker build ${REF}"
docker build \
  --build-arg VERSION="${VERSION}" \
  --build-arg COMMIT="${COMMIT}" \
  --build-arg BUILD_ORIGIN="${BUILD_ORIGIN}" \
  -t "${REF}" -t "${REGISTRY}/${IMAGE}:latest" .

printf '%s' "${REF}" > .image-ref
echo "==> OK: built ${REF} (ref saved to .image-ref)"
