# =============================================================================
# Multi-stage build for the build-info service (part of LAYER 1 — portable).
# The SAME Dockerfile is built by GitHub Actions, GitLab CI, Jenkins, laptop.
# Build metadata arrives as --build-arg from ci/image-build.sh.
# =============================================================================
FROM golang:1.25-alpine AS build
WORKDIR /src
COPY go.mod ./
RUN go mod download
COPY . .
ARG VERSION=dev
ARG COMMIT=unknown
ARG BUILD_ORIGIN=local
RUN CGO_ENABLED=0 go build -trimpath \
      -ldflags "-s -w -X main.version=${VERSION} -X main.commit=${COMMIT} -X main.builtBy=${BUILD_ORIGIN}" \
      -o /out/app .

FROM scratch
ARG VERSION=dev
ARG COMMIT=unknown
LABEL org.opencontainers.image.title="test-agnostic-ci" \
      org.opencontainers.image.description="CI-agnostic pipeline POC: identical scripts on GitHub Actions and GitLab CI" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${COMMIT}"
COPY --from=build /out/app /app
USER 65534:65534
EXPOSE 8080
ENTRYPOINT ["/app"]
