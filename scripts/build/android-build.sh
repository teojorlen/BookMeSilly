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
  -l, --local               Build locally (requires Android NDK/SDK)
  -h, --help                Display this help message

${GREEN}Examples:${NC}
  # Build release APK for arm64-v8a (default)
  $(basename "$0")

  # Build debug APK for armeabi-v7a
  $(basename "$0") -v debug -a armeabi-v7a

  # Build locally with hosted Android SDK
  $(basename "$0") --local -v release

${GREEN}Environment Variables:${NC}
  ANDROID_HOME              Path to Android SDK (used for local builds)
  ANDROID_NDK               Path to Android NDK (used for local builds)
  DOCKER_BUILD_ARGS         Additional Docker build arguments

${GREEN}Output:${NC}
  APK files will be generated in:
  - ./android-build/app/build/outputs/apk/

${GREEN}Requirements:${NC}
  - Docker (for Docker builds)
  - Android SDK/NDK with API ${ANDROID_API} (for local builds)
  - CMake 3.22+
  - Ninja build tool

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
        return 1
    fi

    print_success "Docker image built successfully"

    # Run build in container
    print_info "Running build in Docker container..."
    BUILD_OUTPUT_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_OUTPUT_DIR}"

    docker run --rm \
        -v "${PROJECT_ROOT}:/build" \
        -v "${BUILD_OUTPUT_DIR}:/output" \
        -e "BUILD_VARIANT=${BUILD_VARIANT}" \
        -e "ANDROID_ARCH=${ANDROID_ARCH}" \
        -e "ANDROID_API=${ANDROID_API}" \
        "bookmesilly:android-builder" \
        bash -c "
            set -e
            echo 'Starting Android build in container...'
            mkdir -p /build/android-build
            cd /build/android-build

            # Configure CMake for Android
            cmake .. \
                -GNinja \
                -DCMAKE_BUILD_TYPE=$([ '${BUILD_VARIANT}' = 'debug' ] && echo 'Debug' || echo 'Release') \
                -DCMAKE_TOOLCHAIN_FILE=\${QT_PATH}/cmake/android-toolchain.cmake \
                -DANDROID_NDK=\${ANDROID_NDK} \
                -DANDROID_PLATFORM=android-${ANDROID_API} \
                -DANDROID_ABI=${ANDROID_ARCH} \
                -DCMAKE_INSTALL_PREFIX=/app

            echo 'Building with Ninja...'
            ninja
            ninja install

            # Copy output to mounted volume
            echo 'Copying build artifacts...'
            if [ -d build/app/outputs/apk ]; then
                cp -r build/app/outputs/apk /output/ || true
            fi

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
    print_warning "This requires Android SDK/NDK and build tools to be installed"

    # Validate environment
    if [[ -z "${ANDROID_HOME:-}" ]]; then
        print_error "ANDROID_HOME environment variable not set"
        print_info "Please set ANDROID_HOME to your Android SDK installation path"
        return 1
    fi

    if [[ -z "${ANDROID_NDK:-}" ]]; then
        print_error "ANDROID_NDK environment variable not set"
        print_info "Please set ANDROID_NDK to your Android NDK installation path"
        return 1
    fi

    print_info "ANDROID_HOME: ${ANDROID_HOME}"
    print_info "ANDROID_NDK: ${ANDROID_NDK}"

    BUILD_DIR="${PROJECT_ROOT}/android-build"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    print_info "Configuring CMake for Android..."
    cmake .. \
        -GNinja \
        -DCMAKE_BUILD_TYPE=$([ "$BUILD_VARIANT" = "debug" ] && echo "Debug" || echo "Release") \
        -DCMAKE_TOOLCHAIN_FILE="${ANDROID_NDK}/build/cmake/android.toolchain.cmake" \
        -DANDROID_SDK_ROOT="${ANDROID_HOME}" \
        -DANDROID_NDK="${ANDROID_NDK}" \
        -DANDROID_PLATFORM="android-${ANDROID_API}" \
        -DANDROID_ABI="${ANDROID_ARCH}" \
        -DCMAKE_INSTALL_PREFIX=/app || {
        print_error "CMake configuration failed"
        return 1
    }

    print_info "Building with Ninja..."
    if ! ninja; then
        print_error "Ninja build failed"
        return 1
    fi

    print_info "Installing artifacts..."
    if ! ninja install; then
        print_error "Installation failed"
        return 1
    fi

    print_success "Local Android build completed"
    print_info "Output directory: ${BUILD_DIR}"
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

if $USE_DOCKER; then
    build_with_docker || exit 1
else
    build_locally || exit 1
fi

print_success "Build process completed successfully!"
print_info "Next steps:"
print_info "1. Test the APK on an Android device or emulator"
print_info "2. For release builds, sign the APK with your keystore"
print_info "3. Upload to Google Play Store or distribute directly"
