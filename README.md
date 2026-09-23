# test-agnostic-ci — CI-Agnostic Pipeline POC

**One codebase. One set of pipeline scripts. Two CI platforms — with zero shared code changed.**

| Platform | Wrapper file | Pushes image to |
|---|---|---|
| GitHub Actions | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) | `ghcr.io/seab4ng/test-agnostic-ci` |
| GitLab CI | [`.gitlab-ci.yml`](.gitlab-ci.yml) | `registry.gitlab.com/_alucard/test-agnostic-ci` |

Both pipelines run the **byte-identical** scripts in [`ci/`](ci/) and produce the **same image tag**
(the 8-char commit sha) — each into its own platform-native registry, using each platform's
native automatic credentials. No secrets were configured anywhere.

## The architecture: two layers

```
                 ┌───────────────────────────────────────────────────┐
                 │  LAYER 2 — thin native wrappers (~40 lines each)  │
                 │  orchestration ONLY: triggers, job images,        │
                 │  credentials, artifacts, env mapping              │
                 │                                                   │
 GitHub Actions ─►  .github/workflows/ci.yml                         │
 GitLab CI      ─►  .gitlab-ci.yml                                   │
 Jenkins (next) ─►  Jenkinsfile            (see "Adding Jenkins")    │
                 └──────────────────────┬────────────────────────────┘
                                        │ generic env-var contract
                                        ▼
                 ┌───────────────────────────────────────────────────┐
                 │  LAYER 1 — portable logic (platform-blind)        │
                 │  Taskfile.yml        the MENU: task compile, ...  │
                 │  ci/compile.sh       vet + unit tests + build     │
                 │  ci/image-build.sh   docker build (+ metadata)    │
                 │  ci/image-push.sh    docker login + push          │
                 │  Dockerfile          multi-stage, scratch runtime │
                 └───────────────────────────────────────────────────┘
```

**The rule that makes it work: no business logic in platform YAML — ever.**
The wrapper may only trigger, order jobs, inject credentials, declare artifacts,
and call `task <name>`. The Taskfile is the menu (`task --list`); the recipes are
the `ci/*.sh` scripts — so the whole pipeline also runs on your laptop.

## The generic contract

The scripts know nothing about any CI. They read only these env vars,
which each wrapper maps from its platform's native values:

| Contract var | GitHub Actions maps from | GitLab CI maps from | Jenkins would map from |
|---|---|---|---|
| `REGISTRY` | `ghcr.io` (literal) | `$CI_REGISTRY` | your Artifactory host |
| `IMAGE` | `${{ github.repository }}` | `$CI_PROJECT_PATH` | literal |
| `TAG` / `COMMIT` | `${GITHUB_SHA:0:8}` | `$CI_COMMIT_SHORT_SHA` | `GIT_COMMIT` |
| `REGISTRY_USER` / `REGISTRY_PASS` | `github.actor` / `secrets.GITHUB_TOKEN` | `$CI_REGISTRY_USER` / `$CI_REGISTRY_PASSWORD` | `withCredentials(...)` |
| `BUILD_ORIGIN` | `github-actions` | `gitlab-ci` | `jenkins` |

## What we did NOT lose (the whole point)

- **Per-job logs & retries** — `compile` and `docker-image` are separate platform jobs on both sides; each has its own log, timing, and retry button in the native UI.
- **Native test reporting** — `ci/compile.sh` emits `reports/junit.xml`; GitLab ingests it via `artifacts:reports:junit` (test widget in MRs), GitHub stores it as a build artifact. Same file, one line of declaration each.
- **Native credentials** — no tokens in scripts or repo; GitHub injects `GITHUB_TOKEN`, GitLab injects the job-scoped `CI_REGISTRY_PASSWORD`, Jenkins would use `withCredentials`.
- **Native platform plumbing** — GitLab needs docker-in-docker services, GitHub's VM has a daemon built in. That difference lives in the wrappers, where it belongs.

## Prove it to yourself

```sh
# Pull the SAME commit's image from both registries and ask each who built it
docker run --rm -p 8080:8080 ghcr.io/seab4ng/test-agnostic-ci:<sha>          # login first if private
curl -s localhost:8080 | jq          # -> "builtBy": "github-actions"

docker run --rm -p 8080:8080 registry.gitlab.com/_alucard/test-agnostic-ci:<sha>
curl -s localhost:8080 | jq          # -> "builtBy": "gitlab-ci"
```

Same `version`, same `commit`, same binary logic — only `builtBy` differs.

## Run the whole pipeline on your laptop (no CI at all)

```sh
task compile                                   # vet + test + build -> bin/app
REGISTRY=local.dev IMAGE=poc task run:local    # build image + run it on :8080
curl -s localhost:8080 | jq                    # -> "builtBy": "local"
```

This is the bonus you don't get with logic buried in Jenkinsfiles/YAML:
debugging CI without a commit-push-wait loop.

## Adding Jenkins (or any other CI) = one thin file

```groovy
pipeline {
  agent { label 'linux-docker' }
  stages {
    stage('compile') {
      agent { docker { image 'golang:1.25' } }        // bake `task` into this image
      steps { sh 'task compile' }
      post { always { junit 'reports/junit.xml' } }   // same file feeds Jenkins UI
    }
    stage('image') {
      environment { REGISTRY = 'artifactory.internal'; IMAGE = 'poc/test-agnostic-ci'; BUILD_ORIGIN = 'jenkins' }
      steps {
        withCredentials([usernamePassword(credentialsId: 'registry',
            usernameVariable: 'REGISTRY_USER', passwordVariable: 'REGISTRY_PASS')]) {
          sh 'task image:build image:push'
        }
      }
    }
  }
}
```

No script changes. That is the migration cost of switching CI platforms with this pattern.

## Notes / deliberate POC simplifications

- The wrappers install the `task` binary (pinned v3.53.1) and `gotestsum` at run time; in a real org — especially air-gapped — you bake both into your internal toolchain images and delete those bootstrap lines.
- The two CI jobs each build independently (the docker stage recompiles inside the multi-stage Dockerfile). Good enough here; a real setup would pass `bin/app` as an artifact or use registry layer caching.
- `image-push.sh` assumes the registry host has no `:port` when deriving the `:latest` tag.
