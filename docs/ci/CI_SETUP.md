# CI/CD Setup Guide for BookMeSilly

This guide helps you set up the CI/CD pipeline for BookMeSilly development.

## Quick Start (5 minutes)

### 1. Initial Setup

```bash
# Clone the repository
git clone https://github.com/your-username/bookme-silly.git
cd bookme-silly

# Verify Docker is installed
docker --version
docker run hello-world
```

### 2. First Local Build

```bash
# Test the build locally (recommended before any push)
./scripts/ci-test.sh

# This will:
# ✓ Build all Docker images
# ✓ Run unit tests
# ✓ Verify everything works
# ✓ Report image sizes
```

### 3. Make Your Changes

```bash
# Create a feature branch
git checkout -b feature/my-feature

# Make changes to src code
# Run tests locally
./scripts/ci-test.sh

# Commit and push
git add .
git commit -m "Add my feature"
git push origin feature/my-feature
```

### 4. Create Pull Request

- Go to GitHub → Pull Requests → New
- Select your branch
- GitHub Actions will automatically run CI checks
- All checks must pass before merging

---

## GitHub Actions Setup

### Enable Actions

1. Go to your repository on GitHub
2. Click **Settings** → **Actions** → **General**
3. Ensure "Allow all actions and reusable workflows" is selected

### Configure Branch Protection (Optional but Recommended)

1. Go to **Settings** → **Branches**
2. Click "Add rule" for `main` branch
3. Enable:
   - ✅ Require a pull request before merging
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date before merging
4. Select required status checks:
   - `build-and-test`
   - `code-quality`
   - `security-scan`

### Container Registry Authentication

To push to GitHub Container Registry (GHCR):

1. GitHub Actions automatically uses `GITHUB_TOKEN` secret
2. No additional setup needed!
3. Images appear at:
   - `ghcr.io/username/bookme-silly:main`
   - `ghcr.io/username/bookme-silly:v1.0.0` (on release tags)

---

## Development Workflow

### Local Testing (Before Every Push)

```bash
# Quick test (builds all images, runs tests)
./scripts/ci-test.sh

# Keep test images for inspection
./scripts/ci-test.sh --no-cleanup

# View available test images
docker images | grep bookme-silly:ci
```

### Branches and CI Behavior

| Branch | CI Runs | Pushes to GHCR | Notes |
|--------|---------|----------------|-------|
| `main` | ✓ Full CI | ✓ Yes | Protected, requires PR |
| `develop` | ✓ Full CI | ✗ No | Development branch |
| Feature | ✓ Full CI | ✗ No | PR required to merge |
| `v*` tag | ✓ Release | ✓ Yes | Triggers release workflow |

### Typical Development Flow

```bash
# 1. Create feature branch
git checkout -b feature/add-new-feature

# 2. Make changes
# ... edit files ...

# 3. Build locally
./scripts/ci-test.sh

# 4. Commit
git add .
git commit -m "Add new feature"

# 5. Push
git push origin feature/add-new-feature

# 6. Create PR on GitHub
# GitHub Actions will run automatically
# Wait for all checks to pass

# 7. Merge PR
# After approval from maintainers
```

---

## Release Process

### Creating a Release

```bash
# 1. Ensure everything is merged to main
git checkout main
git pull origin main

# 2. Create and push a version tag
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0

# That's it! GitHub Actions will:
# ✓ Build production image
# ✓ Build slim image
# ✓ Push to GHCR
# ✓ Create GitHub Release with instructions
```

### Using Released Images

After a release, images are available:

```bash
# Pull from GitHub Container Registry
docker pull ghcr.io/username/bookme-silly:v1.0.0
docker pull ghcr.io/username/bookme-silly:slim-v1.0.0

# Run the application
docker run --rm ghcr.io/username/bookme-silly:v1.0.0
```

---

## Docker Compose Alternative

### Using Docker Compose for CI Testing

```bash
# Run builder and tests
docker-compose -f docker-compose.yml -f docker-compose.ci.yml run builder

# Run comprehensive testing
docker-compose -f docker-compose.yml -f docker-compose.ci.yml run tester

# Build all images with CI profile
docker-compose -f docker-compose.yml -f docker-compose.ci.yml build --profile ci

# Clean up test containers
docker-compose -f docker-compose.yml -f docker-compose.ci.yml down
```

---

## Troubleshooting

### "Docker not found" when running ci-test.sh

```bash
# Install Docker
# Ubuntu/Debian:
sudo apt-get install docker.io docker-compose

# macOS:
brew install docker docker-compose

# Start Docker daemon
sudo systemctl start docker  # Linux
#  Docker Desktop handles this on macOS/Windows
```

### Build fails locally but passes in CI

```bash
# 1. Clear Docker caches
docker system prune -a

# 2. Rebuild from scratch
./scripts/ci-test.sh

# 3. Check Docker version matches CI
docker --version
```

### CI Jobs Taking Too Long

- First build: Normal (90s)
- Subsequent builds: Should be faster (~30-60s) due to caching
- If still slow, GitHub Actions cache may have expired
- Manually trigger workflow to rebuild cache

### Permission Denied Running ci-test.sh

```bash
# Make script executable
chmod +x ./scripts/ci-test.sh

# Then run it
./scripts/ci-test.sh
```

### Tests Pass Locally but Fail in CI

- Check GitHub Actions logs: Click on the failed workflow
- Look at the error messages in "Run tests in builder container"
- Common issues:
  - Environment variable differences
  - Cache compatibility
  - Docker version differences

---

## Monitoring CI

### View Workflow Runs

1. Go to your repository
2. Click **Actions** tab
3. Select a workflow to see history
4. Click a run to see details

### Check Status Badge

Add to your README.md:

```markdown
[![CI/CD Pipeline](https://github.com/username/BookMeSilly/workflows/CI%20-%20Build%20and%20Test/badge.svg)](https://github.com/username/BookMeSilly/actions)
[![Release](https://github.com/username/BookMeSilly/workflows/Release%20Docker%20Image/badge.svg)](https://github.com/username/BookMeSilly/actions)
```

### Common Workflow Files

| File | Purpose | Triggers |
|------|---------|----------|
| `.github/workflows/ci.yml` | Main build and test | Push to main/develop, PRs |
| `.github/workflows/build-preview.yml` | Quick preview | PRs to develop |
| `.github/workflows/release.yml` | Create releases | Git tags v* |

---

## Best Practices

### Before Pushing

- ✅ Always run `./scripts/ci-test.sh` locally
- ✅ Fix any issues before pushing
- ✅ Saves CI minutes (free tier gets 2000/month)
- ✅ Faster feedback loop

### Commit Messages

- ✅ Use descriptive messages: "Fix: Resolve CMake build error"
- ✅ Reference issues: "Closes #123: Add feature X"
- ✗ Avoid generic: "fix" or "update"

### Branching Strategy

```
main (stable, protected)
 ↑
develop (integration)
 ↑
feature/* (your work)
 ↑
bugfix/* (patches)
```

### Image Security

- Images run as non-root user
- All multi-stage builds included
- Trivy scans for vulnerabilities
- Base image regularly updated

---

## Advanced Configuration

### Custom Environment Variables

For sensitive data in CI:

1. Go to **Settings** → **Secrets and variables** → **Actions**
2. Click **New repository secret**
3. Add variables (e.g., `REGISTRY_USERNAME`)
4. Use in workflows: `${{ secrets.REGISTRY_USERNAME }}`

### Disable/Modify Workflows

1. Edit `.github/workflows/*.yml`
2. Modify `on:` section to change triggers
3. Comment out jobs with `#` if needed
4. Push changes to enable

### Performance Tuning

```bash
# Enable BuildKit (faster)
export DOCKER_BUILDKIT=1

# Use local cache
docker build --cache-from type=local,src=.docker-cache .

# View build progress
docker build --progress=plain .
```

---

## Support

For issues:

1. Check [CI.md](CI.md) for detailed documentation
2. Review GitHub Actions logs
3. Run `./scripts/ci-test.sh --no-cleanup` for debugging
4. Check Docker installation: `docker --version`

---

## See Also

- [CI.md](CI.md) - Detailed CI/CD documentation
- [DOCKER.md](DOCKER.md) - Docker build information
- [Dockerfile](Dockerfile) - Multi-stage build definition
- [Contributing Guidelines](CONTRIBUTING.md) (if available)
