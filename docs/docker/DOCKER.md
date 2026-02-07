# Docker Build Instructions for BookMeSilly

## Overview

This guide provides step-by-step instructions for building and running BookMeSilly using Docker with Ubuntu 24.04 LTS.

## Quick Start

### Option 1: Using Docker Compose (Recommended)

```bash
# Build production image
docker-compose build app

# Run the application
docker-compose up app

# Run development environment
docker-compose run --rm dev

# Build and test
docker-compose run --rm builder
```

### Option 2: Manual Docker Build

```bash
# Build production image (multi-stage)
docker build -t bookme-silly:latest --target production .

# Build development image
docker build -t bookme-silly:dev --target development .

# Build slim image
docker build -f Dockerfile.slim -t bookme-silly:slim .
```

## Build Stages Explained

### 1. Builder Stage
- **Purpose**: Compilation and testing
- **Size**: ~2.5-3 GB
- **Contains**: All build tools, compilers, Qt SDK
- **Command**: `docker build --target builder .`
- **Use Case**: For CI/CD pipelines, building from source
 - **Notable dev packages included**: `libxkbcommon-dev`, `libxkbcommon-x11-dev`, `libxcb-xkb-dev`, `pkg-config`

### 2. Runtime Stage
- **Purpose**: Base image with only runtime libraries
- **Size**: ~500-600 MB
- **Contains**: Qt runtime, system libraries, no build tools
- **Command**: `docker build --target runtime .`
- **Use Case**: Intermediate stage for multi-stage builds

### 3. Production Stage
- **Purpose**: Final deployment image
- **Size**: ~550-650 MB (with app ~550 MB)
- **Contains**: Compiled app + runtime libraries only
- **Command**: `docker build --target production .` or `docker build .`
- **Use Case**: Running the audiobook player

### 4. Development Stage
- **Purpose**: Development and debugging
- **Size**: ~3-3.5 GB
- **Contains**: All build tools + debugging tools (gdb, valgrind, clang-tools)
- **Command**: `docker build --target development .`
- **Use Case**: Local development, debugging, testing

## Detailed Build Examples

### Build Production Image

```bash
docker build -t bookme-silly:1.0.0 --target production .
docker tag bookme-silly:1.0.0 bookme-silly:latest

# Verify the image
docker images | grep bookme-silly
# bookme-silly        latest              <sha256>          550MB
```

### Build for Development

```bash
docker build -t bookme-silly:dev-latest --target development .

# Start development container with bash
docker run -it --rm \
  -v $(pwd):/workspace \
  -w /workspace \
  bookme-silly:dev-latest \
  /bin/bash

# Inside container:
# $ cd build
# $ cmake .. -GNinja
# $ ninja
# $ ninja test
```

### Build Slim Production Image

```bash
# First, build the binary locally or in separate container
docker build -t bookme-silly:builder --target builder .

# Then create slim image
docker build -f Dockerfile.slim -t bookme-silly:slim .

# Compare sizes
docker images | grep bookme-silly
# bookme-silly  slim     <sha256>  450MB (much smaller!)
```

## Run Examples

### Run as Headless Audio Service

```bash
docker run -d \
  --name bookme-silly \
  -v $(pwd)/audiobooks:/home/appuser/audiobooks:ro \
  -e QT_QPA_PLATFORM=offscreen \
  bookme-silly:latest
```

### Run with X11 Display (Linux Host)

```bash
# Allow X11 connection from container
xhost +local:docker

docker run -it \
  --name bookme-silly-gui \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v ~/.Xauthority:/home/appuser/.Xauthority:ro \
  -v $(pwd)/audiobooks:/home/appuser/audiobooks:ro \
  bookme-silly:latest
```

### Run with Docker Compose

```bash
# Run production app
docker-compose up app

# Run development environment
docker-compose run --rm dev

# Build everything
docker-compose build

# View logs
docker-compose logs -f app

# Stop services
docker-compose down

# Clean up volumes
docker-compose down -v
```

### Run Tests Inside Container

```bash
docker run --rm bookme-silly:latest test_calculator

# Or with compose:
docker-compose run --rm app /usr/local/bin/test_calculator
```

## Environment Variables

### Qt Configuration

```bash
# Offscreen mode (headless)
-e QT_QPA_PLATFORM=offscreen

# Wayland
-e QT_QPA_PLATFORM=wayland

# X11
-e QT_QPA_PLATFORM=xcb

# Enable debug output
-e QT_DEBUG_PLUGINS=1

# Disable GUI scaling
-e QT_AUTO_SCREEN_SCALE_FACTOR=0
```

### Build Configuration

```bash
# Debug build
-e CMAKE_BUILD_TYPE=Debug

# Release build (default)
-e CMAKE_BUILD_TYPE=Release

# MinSizeRel (smallest binary)
-e CMAKE_BUILD_TYPE=MinSizeRel
```

## Mounting Data

### Audiobook Library

```bash
# Mount read-only audiobook directory
-v /path/to/audiobooks:/home/appuser/audiobooks:ro
```

### Configuration Persistence

```bash
# Mount configuration directory
-v bookme-silly-config:/home/appuser/.config/bookme-silly

# Or use named volume with docker-compose
volumes:
  bookme-silly-config:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: /path/to/local/config
```

## Multi-Architecture Builds (ARM64, etc.)

### Build for ARM64 (Apple Silicon, Raspberry Pi)

```bash
# Enable buildx for multi-arch
docker buildx create --name mybuilder
docker buildx use mybuilder

# Build for multiple architectures
docker buildx build --platform linux/amd64,linux/arm64 \
  -t bookme-silly:latest \
  --target production \
  --push .

# Or build for specific architecture
docker build --platform linux/arm64 -t bookme-silly:arm64 .
```

## Optimization Tips

### Reduce Layer Size

```bash
# Use .dockerignore to exclude unnecessary files
echo "build/
.git/
.vscode/
tests/
docs/" > .dockerignore
```

### Multi-Stage Optimization

```bash
# Current multi-stage build reduces final image by >60%
# Builder:    ~2.5 GB (with all tools)
# Production: ~550 MB (only runtime)
```

### Build Caching

```bash
# Docker caches layers, so this is optimized:
# FROM ubuntu (cached)
# RUN apt-get update (cached after first build)
# COPY . (invalidates cache if source changes)
# RUN cmake && ninja (recompiled only)
```

## Troubleshooting

### Build Fails with "Qt not found"

```bash
# Ensure CMake can find Qt
docker build --build-arg CMAKE_ARGS="-DQt6_DIR=/usr/lib/x86_64-linux-gnu/cmake/Qt6" .

# Or set in Dockerfile
RUN cmake .. -DQt6_DIR=/usr/lib/x86_64-linux-gnu/cmake/Qt6
```

### Container Won't Start

```bash
# Check logs
docker logs bookme-silly

# Run interactively to debug
docker run -it --entrypoint /bin/bash bookme-silly:latest

# Verify executable exists
docker run --rm bookme-silly:latest ls -la /usr/local/bin/bookme-silly
```

### Display Issues (GUI)

```bash
# If GUI doesn't show, try:
# 1. Use offscreen mode: QT_QPA_PLATFORM=offscreen
# 2. Enable Wayland: QT_QPA_PLATFORM=wayland
# 3. Debug plugins: QT_DEBUG_PLUGINS=1

docker run -it -e QT_DEBUG_PLUGINS=1 bookme-silly:latest
```

### Permission Issues

```bash
# Container runs as UID 1000 (appuser)
# Ensure host files are readable:
sudo chown 1000:1000 audiobooks/*

# Or run as root (not recommended)
docker run --user root bookme-silly:latest
```

## Publishing to Docker Registry

### Docker Hub

```bash
# Login
docker login -u username

# Tag image
docker tag bookme-silly:latest username/bookme-silly:latest
docker tag bookme-silly:latest username/bookme-silly:1.0.0

# Push
docker push username/bookme-silly:latest
docker push username/bookme-silly:1.0.0
```

### Private Registry

```bash
# Tag for your registry
docker tag bookme-silly:latest registry.example.com/bookme-silly:latest

# Push
docker push registry.example.com/bookme-silly:latest
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Build Docker Image

on:
  push:
    branches: [main]
    tags: ['v*']

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2
      
      - name: Build image
        uses: docker/build-push-action@v4
        with:
          context: .
          target: production
          tags: bookme-silly:latest
          push: false
          
      - name: Test
        run: |
          docker build --target builder -t builder .
          docker run --rm builder ninja test
```

## Performance Monitoring

### Build Time

```bash
# Time the build
time docker build -t bookme-silly:latest --target production .

# Expected: 3-5 minutes (depending on system)
```

### Runtime Resource Usage

```bash
# Monitor container resources
docker stats bookme-silly

# Set resource limits in docker-compose.yml
deploy:
  resources:
    limits:
      cpus: '2'
      memory: 512M
```

## Security Best Practices

1. **Non-root User**: App runs as `appuser` (UID 1000)
2. **Read-only Mounts**: Audiobooks mounted as read-only
3. **No Sudo**: Container doesn't have sudo
4. **Health Checks**: Automated health checking
5. **Minimal Layers**: Multi-stage reduces attack surface

## Cleanup

```bash
# Remove stopped containers
docker container prune

# Remove unused images
docker image prune

# Remove build cache
docker builder prune

# Full cleanup (warning: removes all unused Docker objects)
docker system prune -a
```
