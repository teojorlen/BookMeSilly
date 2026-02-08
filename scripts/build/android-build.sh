#!/bin/bash
#
# Android APK Build Script for BookMeSilly
# Builds the application for Android devices using Docker
#
# Usage: ./android-build.sh [options]
#   -v, --variant     Build variant: debug or release (default: release)
#   -a, --arch        Android architecture: armeabi-v7a, arm64-v8a, x86, x86_64 (default: arm64-v8a)
#   -a, --api         Android API level (default: 34)
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
  -l, --local               Build locally (requires Android NDK)
  -h, --help                Display this help message

${GREEN}Examples:${NC}
  # Build release APK for arm64-v8a using Docker (NDK auto-mounted)
  # Note: requires ANDROID_NDK environment variable set
  $(basename "$0")

  # Build debug APK locally (requires local NDK setup)
  $(basename "$0") -v debug --local

  # Build for 32-bit ARM
  $(basename "$0") -a armeabi-v7a

${GREEN}Requirements:${NC}
  ${YELLOW}Essential:${NC}
  - Android NDK (v21 or newer) - required for building
  - CMake 3.22+
  - Ninja build tool
  - Java 17+ (OpenJDK)

  ${YELLOW}For Docker builds:${NC}
  - Docker installed
  - ANDROID_NDK environment variable pointing to NDK installation
  - NDK will be mounted read-only to Docker container

  ${YELLOW}For local builds:${NC}
  - All requirements above installed locally

${GREEN}Setup Instructions${NC}
  See docs/ANDROID_BUILD.md for:
  - How to install Android NDK
  - How to set ANDROID_NDK environment variable
  - How to build APKs for distribution
  - APK signing and deployment

${GREEN}Environment Variables:${NC}
  ANDROID_NDK               Path to Android NDK (required)
  ANDROID_API               Android API level (default: 34)
  BUILD_VARIANT             Build type: debug or release
  DOCKER_BUILD_ARGS         Additional Docker build arguments

${GREEN}Output:${NC}
  Build artifacts: ./android-build/
  Intermediate files: ./android-build/CMakeCache.txt, build.ninja

EOF
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

validate_variant() {
    case "$1" in
        debug|release)
            return 0
            ;;
        *)
            print_error "Invalid build variant: $1"
            print_info "Valid options: debug, release"
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
            print_info "Valid options: armeabi-v7a, arm64-v8a, x86, x86_64"
            return 1
            ;;
    esac
}

validate_api() {
    if [[ ! "$1" =~ ^[0-9]+$ ]] || (( $1 < 21 || $1 > 35 )); then
        print_error "Invalid API level: $1"
        print_info "API level must be between 21 and 35"
        return 1
    fi
    return 0
}

build_with_docker() {
    print_info "Building Android APK with Docker"
    print_info "Variant: $BUILD_VARIANT, Architecture: $ANDROID_ARCH, API: $ANDROID_API"

    # Build Docker image
    print_info "Building Docker image (android-builder)..."
    if ! docker build \
        -f "${PROJECT_ROOT}/config/docker/Dockerfile" \
        -t "bookmesilly:android-builder" \
        --target android-builder \
        ${DOCKER_BUILD_ARGS:-} \
        "${PROJECT_ROOT}"; then
        print_error "Docker image build failed"
        print_error "Unable to build Docker image. For Android builds, you need to set up Android NDK locally."
        print_info "See docs/ANDROID_BUILD.md for setup instructions."
        return 1
    fi

    print_success "Docker image built successfully"

    # Check if ANDROID_NDK is available locally
    if [[ -z "${ANDROID_NDK:-}" ]]; then
        print_warning "ANDROID_NDK environment variable not set"
        print_info "Building Docker image without NDK. For actual APK building, you need:"
        print_warning "1. Install Android NDK locally"
        print_warning "2. Set ANDROID_NDK=/path/to/android-ndk"
        print_warning "3. Mount the NDK directory to Docker"
        print_info ""
        print_info "Running container with bash shell for manual setup..."
        docker run --rm -it \
            -v "${PROJECT_ROOT}:/build" \
            -e "ANDROID_NDK=${ANDROID_NDK:-}" \
            "bookmesilly:android-builder" \
            bash
        return 0
    fi

    # Run build in container with NDK mounted
    print_info "Running build in Docker container..."
    BUILD_OUTPUT_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_OUTPUT_DIR}"

    docker run --rm \
        -v "${PROJECT_ROOT}:/build" \
        -v "${ANDROID_NDK}:${ANDROID_NDK}:ro" \
        -v "${BUILD_OUTPUT_DIR}:/output" \
        -e "ANDROID_NDK=${ANDROID_NDK}" \
        -e "ANDROID_API=${ANDROID_API}" \
        -e "BUILD_VARIANT=${BUILD_VARIANT}" \
        "bookmesilly:android-builder" \
        bash -c "
            set -e
            cd /build
            mkdir -p android-build
            cd android-build

            # Configure CMake for Android
            cmake .. \
                -GNinja \
                -DCMAKE_BUILD_TYPE=\$([ '${BUILD_VARIANT}' = 'debug' ] && echo 'Debug' || echo 'Release') \
                -DCMAKE_SYSTEM_NAME=Android \
                -DCMAKE_SYSTEM_VERSION=${ANDROID_API} \
                -DCMAKE_ANDROID_PLATFORM=android-${ANDROID_API} \
                -DCMAKE_ANDROID_ABI=${ANDROID_ARCH} \
                -DCMAKE_ANDROID_NDK=\${ANDROID_NDK} \
                -DCMAKE_ANDROID_STL=c++_shared

            echo 'Building with Ninja...'
            ninja

            echo 'Build complete!'
        " || {
            print_error "Docker build failed"
            return 1
        }

    print_success "Android APK build completed"
    print_info "Output directory: ${BUILD_OUTPUT_DIR}"
}

build_locally() {
    print_info "Building Android APK locally"
    print_info "This requires Android NDK to be installed and configured"

    # Validate environment
    if [[ -z "${ANDROID_NDK:-}" ]]; then
        print_error "ANDROID_NDK environment variable not set"
        print_info ""
        print_info "Setup steps:"
        print_info "1. Download Android NDK from: https://developer.android.com/ndk/downloads"
        print_info "2. Extract to a location (e.g., ~/Android/ndk)"
        print_info "3. Set environment variable:"
        print_info "   export ANDROID_NDK=~/Android/ndk/android-ndk-r26"
        print_info ""
        print_info "Then run:"
        print_info "  $(basename "$0") --local"
        return 1
    fi

    if ! [[ -d "${ANDROID_NDK}" ]]; then
        print_error "ANDROID_NDK directory does not exist: ${ANDROID_NDK}"
        return 1
    fi

    if ! command -v cmake &>/dev/null; then
        print_error "CMake not found. Please install CMake:"
        print_info "  Ubuntu/Debian: sudo apt-get install cmake"
        print_info "  macOS: brew install cmake"
        return 1
    fi

    if ! command -v ninja &>/dev/null; then
        print_error "Ninja not found. Please install Ninja:"
        print_info "  Ubuntu/Debian: sudo apt-get install ninja-build"
        print_info "  macOS: brew install ninja"
        return 1
    fi

    print_info "ANDROID_NDK: ${ANDROID_NDK}"
    print_info "ANDROID_API: ${ANDROID_API}"
    print_info "Architecture: ${ANDROID_ARCH}"
    print_info "Variant: ${BUILD_VARIANT}"

    BUILD_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    print_info "Configuring CMake for Android..."
    if ! cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE=$([ "$BUILD_VARIANT" = "debug" ] && echo "Debug" || echo "Release") \
        -DCMAKE_SYSTEM_NAME=Android \
        -DCMAKE_SYSTEM_VERSION="${ANDROID_API}" \
        -DCMAKE_ANDROID_PLATFORM="android-${ANDROID_API}" \
        -DCMAKE_ANDROID_ABI="${ANDROID_ARCH}" \
        -DCMAKE_ANDROID_NDK="${ANDROID_NDK}" \
        -DCMAKE_ANDROID_STL=c++_shared; then
        print_error "CMake configuration failed"
        return 1
    fi

    print_info "Building with Ninja..."
    if ! ninja; then
        print_error "Ninja build failed"
        return 1
    fi

    print_success "Local Android build completed"
    print_info "Build directory: ${BUILD_DIR}"
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
            print_info "Use -h or --help for usage information"
            exit 1
            ;;
    esac
done

# Main execution
print_info "BookMeSilly Android Build"
print_info "Project root: ${PROJECT_ROOT}"

if [[ -z "${ANDROID_NDK:-}" ]] && $USE_DOCKER; then
    print_warning "ANDROID_NDK environment variable not set"
    print_info ""
    print_info "To build Android APKs, you need to:"
    print_info ""
    print_info "1. Install Android NDK from:"
    print_info "   https://developer.android.com/ndk/downloads"
    print_info ""
    print_info "2. Set the environment variable:"
    print_info "   export ANDROID_NDK=/path/to/android-ndk"
    print_info ""
    print_info "3. Run this script again:"
    print_info "   ./scripts/build/android-build.sh"
    print_info ""
    print_info "Or run locally with: ./scripts/build/android-build.sh --local"
    print_info ""
    exit 1
fi

if $USE_DOCKER; then
    build_with_docker || exit 1
else
    build_locally || exit 1
fi

print_success "Build process completed successfully!"
print_info "Next steps:"
print_info "  See docs/ANDROID_BUILD.md for APK signing and deployment"
