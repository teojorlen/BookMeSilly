#!/bin/bash
#
# Android APK Build Script for BookMeSilly
# Builds the application for Android devices using Docker
#
# Usage: ./android-build.sh [options]
#   -v, --variant     Build variant: debug or release (default: release)
#   -a, --arch        Android architecture: armeabi-v7a, arm64-v8a, x86, x86_64 (default: arm64-v8a)
#   -a, --api         Android API level (default: 34)
#   -t, --test        Run unit tests after building (requires QEMU)
#   -l, --local       Build locally without Docker (requires NDK/SDK installed)
#   -h, --help        Show this help message

set -euo pipefail

# Color codes for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

# Default configuration
BUILD_VARIANT="release"
ANDROID_ARCH="arm64-v8a"
ANDROID_API="34"
USE_DOCKER=true
RUN_TESTS=false
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Functions
print_help() {
    cat << EOF
${BLUE}BookMeSilly Android APK Builder${NC}

${GREEN}Usage:${NC}
  $(basename "$0") [OPTIONS]

${GREEN}Options:${NC}
  -v, --variant VARIANT     Build variant: debug or release (default: release)
  -a, --arch ARCH           Android architecture (default: arm64-v8a)
                            Options: armeabi-v7a, arm64-v8a, x86, x86_64
  --api API                 Android API level (default: 34)
  -t, --test                Run unit tests after building (uses QEMU)
  -l, --local               Build locally without Docker (requires ANDROID_NDK set)
  -h, --help                Display this help message

${GREEN}Examples:${NC}
  # Most common: build release APK with Docker (no setup needed!)
  $(basename "$0")

  # Build debug APK for 32-bit ARM devices
  $(basename "$0") -v debug -a armeabi-v7a

  # Build and run tests
  $(basename "$0") --test

  # Build debug version with tests for x86_64 emulator
  $(basename "$0") -v debug -a x86_64 --test

  # Build for multiple architectures
  for arch in arm64-v8a armeabi-v7a x86_64; do
    $(basename "$0") -a \$arch
  done

${GREEN}Quick Start${NC}
  Just run the script - that's it!
  
  $(basename "$0")

  Add --test to run unit tests (uses QEMU to run ARM binaries):
  
  $(basename "$0") --test

  The first build downloads Android NDK (~500MB, takes 2-5 minutes).
  Subsequent builds are fast (~30 seconds) due to Docker layer caching.
  Tests add ~5-10 seconds to build time.

${GREEN}Requirements${NC}
  ${YELLOW}For Docker builds (recommended):${NC}
  - Docker installed
  - Internet connection (to download NDK on first build)
  - ~500MB disk space

  ${YELLOW}For testing:${NC}
  - QEMU user-mode emulation (included in Docker image)
  - Runs ARM binaries on x86_64 hosts
  - Tests backend-only (no GUI components)

  ${YELLOW}For local builds (optional):${NC}
  - Docker OR (CMake + Ninja + openjdk-17 + Android NDK installed)
  - ANDROID_NDK environment variable set
  - QEMU (qemu-user-static) for running tests

${GREEN}What Gets Installed in Docker${NC}
  - Ubuntu 24.04 LTS base system
  - Build tools: CMake, Ninja, GCC/Clang
  - Java: OpenJDK 17
  - Android: NDK r26 with multiple architectures
  - Total: ~900MB Docker image (compressed), ~2GB uncompressed

${GREEN}Supported Architectures${NC}
  - arm64-v8a: Modern phones and tablets (default, recommended)
  - armeabi-v7a: Older devices (Android 5.0+)
  - x86: Emulators (32-bit)
  - x86_64: Emulators and some tablets

${GREEN}Documentation${NC}
  See docs/ANDROID_BUILD.md for:
  - APK signing for Play Store releases
  - Installation on Android devices
  - Troubleshooting and advanced setup
  - CI/CD integration examples

EOF
}

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_section() {
    echo -e "\n${YELLOW}→ $1${NC}"
}

validate_variant() {
    case "$1" in
        debug|release)
            return 0
            ;;
        *)
            print_error "Invalid build variant: $1"
            print_section "Valid options: debug, release"
            return 1
            ;;
    esac
}

validate_arch() {
    case "$1" in
        armeabi-v7a|arm64-v8a|x86|x86_64)
            return 0
            ;;
        *)
            print_error "Invalid architecture: $1"
            print_section "Valid options: armeabi-v7a, arm64-v8a, x86, x86_64"
            return 1
            ;;
    esac
}

validate_api() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 21 || $1 > 35 )); then
        print_error "Invalid API level: $1"
        print_section "API level must be between 21 and 35"
        return 1
    fi
    return 0
}

build_with_docker() {
    print_section "Building Android APK with Docker"
    print_section "Variant: $BUILD_VARIANT, Architecture: $ANDROID_ARCH, API: 34"
    if $RUN_TESTS; then
        print_section "Tests: Will run after build (using QEMU)"
    fi

    # Check if image already exists
    if docker image inspect bookmesilly:android-builder &>/dev/null; then
        print_section "Using cached Docker image (bookmesilly:android-builder)"
    else
        print_section "Building Docker image with Android NDK..."
        print_section "First build downloads ~500MB (NDK cached for future builds)"
        print_section "Estimated time: 2-5 minutes on first build, 30 seconds afterwards"
        
        if ! docker build \
            -f "${PROJECT_ROOT}/config/docker/Dockerfile" \
            -t "bookmesilly:android-builder" \
            --target android-builder \
            ${DOCKER_BUILD_ARGS:+${DOCKER_BUILD_ARGS}} \
            "${PROJECT_ROOT}"; then
            print_error "Docker image build failed"
            return 1
        fi
        print_success "Docker image built successfully with Android NDK included"
    fi

    # Run build in container
    print_section "Running Android build in Docker container..."
    BUILD_OUTPUT_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_OUTPUT_DIR}"

    docker run --rm \
        -v "${PROJECT_ROOT}:/build" \
        -v "${BUILD_OUTPUT_DIR}:/output" \
        "bookmesilly:android-builder" \
        build-android.sh "$([ "$BUILD_VARIANT" = "debug" ] && echo "Debug" || echo "Release")" "$ANDROID_ARCH" "$RUN_TESTS" || {
        print_error "Docker build failed"
        print_section "Check output above for details"
        return 1
    }

    print_success "Android APK build completed successfully"
    print_section "Output directory: ${BUILD_OUTPUT_DIR}"
}

build_locally() {
    print_section "Building Android APK locally (without Docker)"

    # Validate environment
    if [[ -z "${ANDROID_NDK:-}" ]]; then
        print_error "ANDROID_NDK environment variable not set"
        return 1
    fi

    if ! [[ -d "${ANDROID_NDK}" ]]; then
        print_error "ANDROID_NDK directory does not exist: ${ANDROID_NDK}"
        return 1
    fi

    if ! command -v cmake &>/dev/null; then
        print_error "CMake not found. Install with:"
        print_section "  Ubuntu/Debian: sudo apt-get install cmake"
        print_section "  macOS: brew install cmake"
        return 1
    fi

    if ! command -v ninja &>/dev/null; then
        print_error "Ninja not found. Install with:"
        print_section "  Ubuntu/Debian: sudo apt-get install ninja-build"
        print_section "  macOS: brew install ninja"
        return 1
    fi

    print_section "ANDROID_NDK: ${ANDROID_NDK}"
    print_section "Architecture: ${ANDROID_ARCH}"
    print_section "Variant: ${BUILD_VARIANT}"

    BUILD_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    print_section "Configuring CMake for Android..."
    if ! cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE="$([ "$BUILD_VARIANT" = "debug" ] && echo "Debug" || echo "Release")" \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION="34" \
        -DCMAKE_ANDROID_PLATFORM="android-34" \
        -DCMAKE_ANDROID_ABI="${ANDROID_ARCH}" \
        -DCMAKE_ANDROID_NDK="${ANDROID_NDK}" \
        -DCMAKE_ANDROID_STL=c++_shared; then
        print_error "CMake configuration failed"
        return 1
    fi

    print_section "Building with Ninja..."
    if ! ninja; then
        print_error "Ninja build failed"
        return 1
    fi

    print_success "Local Android build completed"
    print_section "Build directory: ${BUILD_DIR}"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--variant)
            BUILD_VARIANT="$2"
            validate_variant "$BUILD_VARIANT" || exit 1
            shift 2
            ;;
        -a|--arch)
            ANDROID_ARCH="$2"
            validate_arch "$ANDROID_ARCH" || exit 1
            shift 2
            ;;
        --api)
            ANDROID_API="$2"
            validate_api "$ANDROID_API" || exit 1
            shift 2
            ;;
        -t|--test)
            RUN_TESTS=true
            shift
            ;;
        -l|--local)
            USE_DOCKER=false
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            print_section "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
print_header "BookMeSilly Android Build"
print_section "Project root: ${PROJECT_ROOT}"

if $USE_DOCKER; then
    build_with_docker || exit 1
else
    print_section "Local build mode (without Docker)"
    print_section "Requires ANDROID_NDK to be set"
    if [[ -z "${ANDROID_NDK:-}" ]]; then
        print_error "ANDROID_NDK environment variable not set"
        print_section ""
        print_section "Set ANDROID_NDK and try again:"
        print_section "  export ANDROID_NDK=/path/to/android-ndk"
        print_section "  ./scripts/build/android-build.sh --local"
        exit 1
    fi
    build_locally || exit 1
fi

print_success "Android build completed successfully!"
print_section "Build artifacts are in: ${PROJECT_ROOT}/android-build/"
