#!/bin/bash
################################################################################
# BookMeSilly Local CI Pipeline
# Run this script locally before pushing to verify the build works
# Usage: ./scripts/ci-test.sh [--no-cleanup]
################################################################################

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLEANUP=true

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Cleanup function
cleanup() {
    if [ "$CLEANUP" = true ]; then
        echo -e "${YELLOW}Cleaning up test images...${NC}"
        docker rmi -f bookme-silly:ci-builder 2>/dev/null || true
        docker rmi -f bookme-silly:ci-production 2>/dev/null || true
        docker rmi -f bookme-silly:ci-slim 2>/dev/null || true
    fi
}

# Trap to cleanup on exit
trap cleanup EXIT

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_section() {
    echo -e "\n${YELLOW}→ $1${NC}"
}

cd "$PROJECT_ROOT"

# ============================================================================
# Header
# ============================================================================
print_header "BookMeSilly Local CI Pipeline"

# ============================================================================
# Stage 1: Setup Check
# ============================================================================
print_section "Stage 1: Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi
print_success "Docker is installed"

DOCKER_VERSION=$(docker --version)
print_success "Using: $DOCKER_VERSION"

if ! [ -f "config/docker/Dockerfile" ]; then
    print_error "Dockerfile not found at config/docker/Dockerfile"
    exit 1
fi
print_success "Dockerfile found"

if ! [ -f "CMakeLists.txt" ]; then
    print_error "CMakeLists.txt not found"
    exit 1
fi
print_success "CMakeLists.txt found"

# ============================================================================
# Stage 2: Build - Builder Image
# ============================================================================
print_section "Stage 2: Building builder image..."
if docker build --target builder -t bookme-silly:ci-builder -f config/docker/Dockerfile . > /dev/null 2>&1; then
    print_success "Builder image built successfully"
    BUILDER_SIZE=$(docker images bookme-silly:ci-builder --format "{{.Size}}")
    print_success "Builder image size: $BUILDER_SIZE"
else
    print_error "Failed to build builder image"
    exit 1
fi

# ============================================================================
# Stage 3: Tests
# ============================================================================
print_section "Stage 3: Running tests..."
set +e
TEST_OUTPUT=$(docker run --rm \
    bookme-silly:ci-builder \
    bash -c "cd /build/build && ninja test 2>&1" 2>&1)
TEST_RESULT=$?
set -e

if [ $TEST_RESULT -eq 0 ]; then
    print_success "All tests passed"
    echo "$TEST_OUTPUT" | grep -E "(100% tests passed|Test project)" || true
else
    print_error "Tests failed"
    echo "$TEST_OUTPUT"
    exit 1
fi

# ============================================================================
# Stage 4: Build - Production Image
# ============================================================================
print_section "Stage 4: Building production image..."
if docker build --target production -t bookme-silly:ci-production -f config/docker/Dockerfile . > /dev/null 2>&1; then
    print_success "Production image built successfully"
    PROD_SIZE=$(docker images bookme-silly:ci-production --format "{{.Size}}")
    print_success "Production image size: $PROD_SIZE"
else
    print_error "Failed to build production image"
    exit 1
fi

# ============================================================================
# Stage 5: Build - Slim Image
# ============================================================================
print_section "Stage 5: Building slim image..."
if docker build -f config/docker/Dockerfile.slim -t bookme-silly:ci-slim . > /dev/null 2>&1; then
    print_success "Slim image built successfully"
    SLIM_SIZE=$(docker images bookme-silly:ci-slim --format "{{.Size}}")
    print_success "Slim image size: $SLIM_SIZE"
else
    print_error "Failed to build slim image"
    exit 1
fi

# ============================================================================
# Stage 6: Verification
# ============================================================================
print_section "Stage 6: Verifying images..."

# Check production image has the binary
set +e
docker run --rm --entrypoint="" bookme-silly:ci-production test -x /usr/local/bin/bookme-silly 2>/dev/null
PROD_CHECK=$?
set -e

if [ $PROD_CHECK -eq 0 ]; then
    print_success "Production image contains executable"
else
    print_error "Production image missing executable"
    exit 1
fi

# Check slim image has the binary
set +e
docker run --rm --entrypoint="" bookme-silly:ci-slim test -x /usr/local/bin/bookme-silly 2>/dev/null
SLIM_CHECK=$?
set -e

if [ $SLIM_CHECK -eq 0 ]; then
    print_success "Slim image contains executable"
else
    print_error "Slim image missing executable"
    exit 1
fi

# ============================================================================
# Final Summary
# ============================================================================
print_header "CI Pipeline Complete - All Checks Passed!"

echo -e "${GREEN}Summary:${NC}"
echo "  Builder Image Size:     $BUILDER_SIZE"
echo "  Production Image Size:  $PROD_SIZE"
echo "  Slim Image Size:        $SLIM_SIZE"
echo "  Tests:                  PASSED ✓"
echo "  Binary Verification:    PASSED ✓"

echo -e "\n${GREEN}Ready to push changes!${NC}\n"

if [ "$CLEANUP" = true ]; then
    echo "Tip: Use --no-cleanup flag to keep test images for inspection:"
    echo "    ./scripts/ci-test.sh --no-cleanup"
    echo ""
    echo "View test images:"
    echo "    docker images | grep bookme-silly:ci"
else
    echo "Test images preserved for inspection:"
    docker images | grep bookme-silly:ci || echo "No images found"
fi
