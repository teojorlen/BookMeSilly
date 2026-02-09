#!/bin/bash
################################################################################
# BookMeSilly Local CI Pipeline
# Run this script locally before pushing to verify the build works
# Usage: ./scripts/ci-test.sh [stages...] [--no-cleanup]
# Stages: all, setup, builder, tests, production, slim, verify (default: all)
################################################################################

set -e  # Exit on error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CLEANUP=true
STAGES=()

# Valid stages
VALID_STAGES=("setup" "builder" "tests" "production" "slim" "verify" "android-builder" "android-build" "android-tests")

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

print_usage() {
    cat <<EOF
${BLUE}BookMeSilly Local CI Pipeline${NC}

${GREEN}Usage:${NC}
  ./scripts/ci-test.sh [stages...] [--no-cleanup]

${GREEN}Stages:${NC}
  setup          - Verify prerequisites (Docker, files)
  builder        - Build builder image (desktop)
  tests          - Run tests (requires: builder)
  production     - Build production image (requires: builder)
  slim           - Build slim image (requires: builder)
  verify         - Verify Docker images (requires: production, slim)
  android-builder - Build Android builder image with NDK
  android-build   - Build Android backend (requires: android-builder)
  android-tests   - Run Android tests (requires: android-build)
  all            - Run all stages (default)

${GREEN}Options:${NC}
  --no-cleanup  - Keep Docker images after completion
  -h, --help    - Show this help message

${GREEN}Examples:${NC}
  ./scripts/ci-test.sh                         # Run all stages (default)
  ./scripts/ci-test.sh all                     # Run all stages
  ./scripts/ci-test.sh tests                   # Run tests (builder auto-added)
  ./scripts/ci-test.sh builder tests           # Run builder and tests
  ./scripts/ci-test.sh android-build           # Build Android backend
  ./scripts/ci-test.sh tests --no-cleanup      # Run tests, keep images

${YELLOW}Note:${NC} Stage dependencies are automatically added. For example,
running 'tests' alone will automatically add 'builder' if needed.

EOF
}

# Check if a stage should be run
should_run_stage() {
    local stage=$1
    for s in "${STAGES[@]}"; do
        if [ "$s" = "$stage" ]; then
            return 0
        fi
    done
    return 1
}

# Add stage dependencies to STAGES array
add_stage_dependencies() {
    local modified=false
    
    # Tests depends on builder
    if should_run_stage "tests" && ! should_run_stage "builder"; then
        STAGES+=("builder")
        modified=true
    fi
    
    # Production depends on builder
    if should_run_stage "production" && ! should_run_stage "builder"; then
        STAGES+=("builder")
        modified=true
    fi
    
    # Slim depends on builder
    if should_run_stage "slim" && ! should_run_stage "builder"; then
        STAGES+=("builder")
        modified=true
    fi
    
    # Verify depends on production and slim
    if should_run_stage "verify"; then
        if ! should_run_stage "production"; then
            STAGES+=("production")
            modified=true
        fi
        if ! should_run_stage "slim"; then
            STAGES+=("slim")
            modified=true
        fi
    fi
    
    # Android-build depends on android-builder
    if should_run_stage "android-build" && ! should_run_stage "android-builder"; then
        STAGES+=("android-builder")
        modified=true
    fi
    
    # Android-tests depends on android-build
    if should_run_stage "android-tests" && ! should_run_stage "android-build"; then
        STAGES+=("android-build")
        modified=true
    fi
    
    # Re-sort to remove duplicates and ensure proper order
    if [ "$modified" = true ]; then
        mapfile -t STAGES < <(printf '%s\n' "${STAGES[@]}" | sort -u)
    fi
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            print_usage
            exit 0
            ;;
        --no-cleanup)
            CLEANUP=false
            shift
            ;;
        all)
            STAGES=("${VALID_STAGES[@]}")
            shift
            ;;
        setup|builder|tests|production|slim|verify|android-builder|android-build|android-tests)
            STAGES+=("$1")
            shift
            ;;
        *)
            echo -e "${RED}Unknown option or stage: $1${NC}"
            print_usage
            exit 1
            ;;
    esac
done

# Default to all stages if none specified
if [ ${#STAGES[@]} -eq 0 ]; then
    STAGES=("${VALID_STAGES[@]}")
fi

# Remove duplicates from STAGES
mapfile -t STAGES < <(printf '%s\n' "${STAGES[@]}" | sort -u)

# Add stage dependencies
add_stage_dependencies



# Cleanup function
cleanup() {
    if [ "$CLEANUP" = true ]; then
        echo -e "${YELLOW}Cleaning up test images...${NC}"
        docker rmi -f bookme-silly:ci-builder 2>/dev/null || true
        docker rmi -f bookme-silly:ci-production 2>/dev/null || true
        docker rmi -f bookme-silly:ci-slim 2>/dev/null || true
        docker rmi -f bookme-silly:ci-android-builder 2>/dev/null || true
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
echo -e "${GREEN}Running stages:${NC} $(IFS=, ; echo "${STAGES[*]}")\n"

# ============================================================================
# Stage 1: Setup Check
# ============================================================================
if should_run_stage "setup"; then
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
else
    echo -e "${YELLOW}⊘ Skipping setup stage${NC}"
fi

# ============================================================================
# Stage 2: Build - Builder Image
# ============================================================================
if should_run_stage "builder"; then
print_section "Stage 2: Building builder image..."
if docker build --target builder -t bookme-silly:ci-builder -f config/docker/Dockerfile . > /dev/null 2>&1; then
    print_success "Builder image built successfully"
    BUILDER_SIZE=$(docker images bookme-silly:ci-builder --format "{{.Size}}")
    print_success "Builder image size: $BUILDER_SIZE"
else
    print_error "Failed to build builder image"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping builder stage${NC}"
fi

# ============================================================================
# Stage 3: Tests
# ============================================================================
if should_run_stage "tests"; then
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
else
    echo -e "${YELLOW}⊘ Skipping tests stage${NC}"
fi

# ============================================================================
# Stage 4: Build - Production Image
# ============================================================================
if should_run_stage "production"; then
print_section "Stage 4: Building production image..."
if docker build --target production -t bookme-silly:ci-production -f config/docker/Dockerfile . > /dev/null 2>&1; then
    print_success "Production image built successfully"
    PROD_SIZE=$(docker images bookme-silly:ci-production --format "{{.Size}}")
    print_success "Production image size: $PROD_SIZE"
else
    print_error "Failed to build production image"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping production stage${NC}"
fi

# ============================================================================
# Stage 5: Build - Slim Image
# ============================================================================
if should_run_stage "slim"; then
print_section "Stage 5: Building slim image..."
if docker build -f config/docker/Dockerfile.slim -t bookme-silly:ci-slim . > /dev/null 2>&1; then
    print_success "Slim image built successfully"
    SLIM_SIZE=$(docker images bookme-silly:ci-slim --format "{{.Size}}")
    print_success "Slim image size: $SLIM_SIZE"
else
    print_error "Failed to build slim image"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping slim stage${NC}"
fi

# ============================================================================
# Stage 6: Verification
# ============================================================================
if should_run_stage "verify"; then
print_section "Stage 6: Verifying desktop images..."

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
else
    echo -e "${YELLOW}⊘ Skipping verify stage${NC}"
fi

# ============================================================================
# Stage 7: Android Builder Image
# ============================================================================
if should_run_stage "android-builder"; then
print_section "Stage 7: Building Android builder image with NDK..."
if docker build --target android-builder -t bookme-silly:ci-android-builder -f config/docker/Dockerfile . > /dev/null 2>&1; then
    print_success "Android builder image built successfully"
    ANDROID_BUILDER_SIZE=$(docker images bookme-silly:ci-android-builder --format "{{.Size}}")
    print_success "Android builder image size: $ANDROID_BUILDER_SIZE"
else
    print_error "Failed to build Android builder image"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping android-builder stage${NC}"
fi

# ============================================================================
# Stage 8: Android Backend Build
# ============================================================================
if should_run_stage "android-build"; then
print_section "Stage 8: Building Android backend (arm64-v8a)..."
set +e
ANDROID_BUILD_OUTPUT=$(docker run --rm \
    -v "$PROJECT_ROOT:/build" \
    bookme-silly:ci-android-builder \
    build-android.sh Release arm64-v8a false 2>&1)
ANDROID_BUILD_RESULT=$?
set -e

if [ $ANDROID_BUILD_RESULT -eq 0 ]; then
    print_success "Android backend built successfully"
    echo "$ANDROID_BUILD_OUTPUT" | grep -E "(Build complete|Backend library)" || true
else
    print_error "Android build failed"
    echo "$ANDROID_BUILD_OUTPUT"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping android-build stage${NC}"
fi

# ============================================================================
# Stage 9: Android Tests
# ============================================================================
if should_run_stage "android-tests"; then
print_section "Stage 9: Running Android unit tests with QEMU..."
set +e
ANDROID_TEST_OUTPUT=$(docker run --rm \
    -v "$PROJECT_ROOT:/build" \
    bookme-silly:ci-android-builder \
    build-android.sh Release arm64-v8a true 2>&1)
ANDROID_TEST_RESULT=$?
set -e

if [ $ANDROID_TEST_RESULT -eq 0 ]; then
    print_success "Android unit tests passed"
    echo "$ANDROID_TEST_OUTPUT" | grep -E "(test case|All tests passed|passed|PASSED|Tests passed)" || echo "$ANDROID_TEST_OUTPUT" | tail -5
else
    print_error "Android tests failed"
    echo "$ANDROID_TEST_OUTPUT"
    exit 1
fi
else
    echo -e "${YELLOW}⊘ Skipping android-tests stage${NC}"
fi

# ============================================================================
# Final Summary
# ============================================================================
print_header "CI Pipeline Complete - Selected Stages Passed!"

echo -e "${GREEN}Summary:${NC}"
if should_run_stage "builder"; then
    echo "  Desktop Builder Size:      ${BUILDER_SIZE:-N/A}"
fi
if should_run_stage "production"; then
    echo "  Production Image Size:     ${PROD_SIZE:-N/A}"
fi
if should_run_stage "slim"; then
    echo "  Slim Image Size:           ${SLIM_SIZE:-N/A}"
fi
if should_run_stage "tests"; then
    echo "  Desktop Tests:             PASSED ✓"
fi
if should_run_stage "verify"; then
    echo "  Desktop Binary Verify:     PASSED ✓"
fi
if should_run_stage "android-builder"; then
    echo "  Android Builder Size:      ${ANDROID_BUILDER_SIZE:-N/A}"
fi
if should_run_stage "android-build"; then
    echo "  Android Backend Build:     PASSED ✓"
fi
if should_run_stage "android-tests"; then
    echo "  Android Tests:             PASSED ✓"
fi

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
