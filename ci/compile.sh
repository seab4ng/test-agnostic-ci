#!/bin/sh
# =============================================================================
# LAYER 1 — PORTABLE LOGIC (platform-blind)
# compile.sh: vet + unit tests (JUnit XML) + static binary build.
#
# Runs identically on a laptop, Jenkins, GitLab CI, GitHub Actions.
# It knows NOTHING about any CI platform — configuration arrives only
# through the generic contract below.
#
# Contract (env vars, all optional here):
#   VERSION       version stamped into the binary               (default 0.1.0)
#   COMMIT        short commit sha                              (default: from git)
#   BUILD_ORIGIN  who built it: local|github-actions|gitlab-ci|jenkins (default local)
#
# Outputs: bin/app, reports/junit.xml
# =============================================================================
set -eu

# Container-based CI jobs often run as a uid that differs from the checkout owner.
git config --global --add safe.directory "$(pwd)" 2>/dev/null || true

VERSION="${VERSION:-0.1.0}"
COMMIT="${COMMIT:-$(git rev-parse --short=8 HEAD 2>/dev/null || echo unknown)}"
BUILD_ORIGIN="${BUILD_ORIGIN:-local}"

mkdir -p bin reports

echo "==> go vet"
go vet ./...

echo "==> go test (JUnit -> reports/junit.xml)"
go run gotest.tools/gotestsum@v1.13.0 --junitfile reports/junit.xml -- ./...

echo "==> go build"
CGO_ENABLED=0 go build -trimpath \
  -ldflags "-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.builtBy=${BUILD_ORIGIN}" \
  -o bin/app .

echo "==> OK: bin/app (version=${VERSION} commit=${COMMIT} builtBy=${BUILD_ORIGIN})"
