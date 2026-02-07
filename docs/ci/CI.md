# BookMeSilly CI/CD Configuration

This document describes the continuous integration and deployment setup for BookMeSilly using Docker containers.

## Overview

BookMeSilly uses **GitHub Actions** for automated building, testing, and releasing. All CI pipelines leverage the project's multi-stage Dockerfile to ensure consistency between local development and production deployments.

## CI Workflows

### 1. **Main CI Pipeline** (`.github/workflows/ci.yml`)

Runs on every push to `main` and `develop` branches, and on all pull requests.

#### What it does:
- ✅ Builds the builder Docker image
- ✅ Runs unit tests (`ninja test`)
- ✅ Builds the production Docker image
- ✅ Builds the slim Docker image
- ✅ Reports image sizes
- ✅ Runs code quality checks (cppcheck)
- ✅ Scans for security vulnerabilities (Trivy)
- ✅ Pushes to GitHub Container Registry (main branch only)

#### Triggers:
```yaml
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main, develop]
```

#### Key Jobs:
- `build-and-test`: Builds images and runs tests
- `code-quality`: Runs static analysis
- `security-scan`: Vulnerability scanning
- `summary`: Final status summary

**Duration**: ~5-10 minutes

---

### 2. **Build Preview Workflow** (`.github/workflows/build-preview.yml`)

Lightweight preview for pull requests to `develop` branch.

#### What it does:
- ✅ Quick build of all three image targets
- ✅ Provides fast feedback (2-3 minutes)

#### Triggers:
```yaml
on:
  pull_request:
    branches: [develop]
```

**Duration**: ~2-3 minutes

---

### 3. **Release Workflow** (`.github/workflows/release.yml`)

Triggered when a version tag is pushed (e.g., `v1.0.0`).

#### What it does:
- ✅ Builds production and slim images
- ✅ Pushes images to GitHub Container Registry
- ✅ Creates GitHub Release with pull instructions
- ✅ Tags images with version numbers

#### Triggers:
```yaml
on:
  push:
    tags:
      - 'v*'
```

#### Release Tags:
- `v1.2.3` → Production image tagged as `v1.2.3`, `1.2`, `latest`
- `v1.2.3` → Slim image tagged as `slim-v1.2.3`, `slim-latest`

**Duration**: ~5 minutes

---

## Local Testing

### Quick Start

Run the local CI test script before pushing:

```bash
./scripts/ci-test.sh
```

#### What it does:
1. Checks Docker is installed
2. Builds builder image
3. Runs tests
4. Builds production image
5. Builds slim image
6. Verifies binaries exist
7. Reports image sizes
8. Cleans up test images (default)

#### Output Example:
```
===================================================
BookMeSilly Local CI Pipeline
===================================================

→ Stage 1: Checking prerequisites...
✓ Docker is installed
✓ Using: Docker version 20.10.21
✓ Dockerfile found
✓ CMakeLists.txt found

→ Stage 2: Building builder image...
✓ Builder image built successfully
✓ Builder image size: 1.67GB

→ Stage 3: Running tests...
✓ All tests passed

→ Stage 4: Building production image...
✓ Production image built successfully
✓ Production image size: 891MB

→ Stage 5: Building slim image...
✓ Slim image built successfully
✓ Slim image size: 506MB

→ Stage 6: Verifying images...
✓ Production image contains executable
✓ Slim image contains executable

===================================================
CI Pipeline Complete - All Checks Passed!
===================================================
```

### Options

```bash
# Keep test images for inspection
./scripts/ci-test.sh --no-cleanup

# View test images
docker images | grep bookme-silly:ci

# Inspect a test image
docker run --rm bookme-silly:ci-production bash
```

**Duration**: ~2-3 minutes

---

## Container Registry

### GitHub Container Registry (GHCR)

Images are automatically pushed to:
- `ghcr.io/your-username/bookme-silly:latest` (main branch)
- `ghcr.io/your-username/bookme-silly:v1.2.3` (tagged releases)
- `ghcr.io/your-username/bookme-silly:slim-v1.2.3` (slim variant)

### Pulling Images

```bash
# Latest development build
docker pull ghcr.io/your-username/bookme-silly:main

# Latest release
docker pull ghcr.io/your-username/bookme-silly:latest

# Specific version
docker pull ghcr.io/your-username/bookme-silly:v1.2.3

# Slim variant
docker pull ghcr.io/your-username/bookme-silly:slim-v1.2.3
```

### Authentication

For private images, authenticate with:

```bash
echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u USERNAME --password-stdin
```

---

## Docker Caching

All workflows use GitHub Actions Container Build Cache (`type=gha`) for faster builds:

- **First build**: ~90 seconds (full build)
- **Subsequent builds**: ~30-60 seconds (cached layers reused)

Cache is automatically managed by GitHub Actions.

---

## Build Status Badges

Add to your README:

```markdown
![CI/CD Pipeline](https://github.com/your-username/BookMeSilly/workflows/CI%20-%20Build%20and%20Test/badge.svg)
![Release](https://github.com/your-username/BookMeSilly/workflows/Release%20Docker%20Image/badge.svg)
```

---

## Workflow Rules

### When to Test Locally

- ✅ Always run `./scripts/ci-test.sh` before pushing
- ✅ Saves CI minutes and provides instant feedback
- ✅ Faster iteration cycle for large changes

### Branch Protection

Follow these rules:

```
main branch:
  ✓ Require pull request reviews: 1
  ✓ Require status checks to pass: ci.yml
  ✓ Require branches to be up to date before merging

develop branch:
  ✓ Require status checks to pass: build-preview.yml, ci.yml
```

### Release Process

1. **Create Release Branch**
   ```bash
   git checkout -b release/v1.2.3
   ```

2. **Update Version Numbers**
   - Update any version references
   - Update CHANGELOG.md

3. **Create Pull Request**
   - PR to `main`
   - All checks must pass

4. **Merge to Main**
   ```bash
   git merge --no-ff release/v1.2.3
   ```

5. **Create Release Tag**
   ```bash
   git tag -a v1.2.3 -m "Release version 1.2.3"
   git push origin v1.2.3
   ```

6. **Automatic Release** 🎉
   - GitHub Actions builds and pushes images
   - Release notes auto-generated with pull instructions
   - Images available on GHCR

---

## Troubleshooting

### Build Fails Locally

1. **Check Docker**
   ```bash
   docker version
   docker images
   ```

2. **Clean Build**
   ```bash
   docker system prune -a
   ./scripts/ci-test.sh
   ```

3. **Check Dependencies**
   ```bash
   cd /path/to/BookMeSilly
   cmake --version
   ```

### CI Job Stuck

- GitHub Actions has a default 6-hour timeout per job
- BuildKit can be reset in runner settings
- Check Actions logs for details

### Authentication Issues

- Use `secrets.GITHUB_TOKEN` (auto-provided)
- Personal access tokens need `repo` and `write:packages` scopes
- See [GitHub Docs](https://docs.github.com/en/actions/deployment/deploying-to-your-cloud-provider/deploying-with-docker)

### Container Size Too Large

Run locally with `--no-cleanup`:
```bash
./scripts/ci-test.sh --no-cleanup
docker images | grep bookme-silly:ci
```

---

## Performance Tips

### Local Builds

```bash
# Use BuildKit for faster builds
export DOCKER_BUILDKIT=1
docker build --target builder .

# Multi-stage cache optimization
docker build --target production --cache-from bookme-silly:ci-builder .
```

### CI Optimization

- Cache layers are retained for 7 days
- Use `--progress=plain` for detailed logs
- Parallel jobs where possible

---

## Security

### Vulnerability Scanning

- **Trivy**: Container image scanning
- **Results**: Uploaded to GitHub Security tab
- **SARIFs**: Added to Code Scanning alerts

### Best Practices

- ✅ Images run as non-root user (`appuser`)
- ✅ Multi-stage builds minimize image size
- ✅ Base image regularly updated (Ubuntu 24.04 LTS)
- ✅ Secrets handled by GitHub (GITHUB_TOKEN only)

---

## See Also

- [Dockerfile](../Dockerfile) - Production multi-stage build
- [docker-compose.yml](../docker-compose.yml) - Local orchestration
- [CMakeLists.txt](../CMakeLists.txt) - Build configuration
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Docker Buildx](https://docs.docker.com/build/)

---

## Questions?

For issues or suggestions about CI configuration:
1. Check the workflow logs in GitHub Actions
2. Run `./scripts/ci-test.sh --no-cleanup` for local debugging
3. Review [DOCKER.md](../DOCKER.md) for build information
