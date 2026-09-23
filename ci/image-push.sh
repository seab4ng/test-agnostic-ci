#!/bin/sh
# =============================================================================
# LAYER 1 — PORTABLE LOGIC (platform-blind)
# image-push.sh: login + push the image built by image-build.sh.
#
# Contract (env vars):
#   REGISTRY       required  registry host (must match image-build.sh)
#   REGISTRY_USER  required  registry username
#   REGISTRY_PASS  required  registry password/token — injected NATIVELY by
#                            each platform: Jenkins withCredentials, GitLab
#                            CI_REGISTRY_PASSWORD, GitHub secrets.GITHUB_TOKEN
#
# Input: .image-ref written by image-build.sh
# =============================================================================
set -eu

: "${REGISTRY:?REGISTRY is required}"
: "${REGISTRY_USER:?REGISTRY_USER is required}"
: "${REGISTRY_PASS:?REGISTRY_PASS is required}"
[ -f .image-ref ] || { echo "ERROR: .image-ref not found — run image-build.sh first" >&2; exit 1; }

REF="$(cat .image-ref)"
LATEST="${REF%:*}:latest"   # POC-simple: assumes REGISTRY host has no :port

echo "==> docker login ${REGISTRY}"
printf '%s' "${REGISTRY_PASS}" | docker login "${REGISTRY}" -u "${REGISTRY_USER}" --password-stdin

echo "==> docker push ${REF}"
docker push "${REF}"
docker push "${LATEST}"

docker logout "${REGISTRY}" >/dev/null 2>&1 || true
echo "==> OK: pushed ${REF} and ${LATEST}"
