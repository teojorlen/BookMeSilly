#!/bin/bash
#
# Desktop Build Script for BookMeSilly
# Builds the full desktop application with Qt GUI
#
# Usage: ./desktop-build.sh [options]
#   -v, --variant     Build variant: debug or release (default: release)
#   -b, --backend     Backend-only build (no Qt, no GUI)
#   -l, --local       Build locally without Docker (requires Qt6 installed)
#   -c, --clean       Clean build (remove build directory first)
#   -r, --run         Run the application after building
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
BACKEND_ONLY=false
USE_DOCKER=true
CLEAN_BUILD=false
RUN_AFTER_BUILD=false
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Functions
print_help() {
    cat << EOF
${BLUE}BookMeSilly Desktop Application Builder${NC}

${GREEN}Usage:${NC}
  $(basename "$0") [OPTIONS]

${GREEN}Options:${NC}
  -v, --variant VARIANT     Build variant: debug or release (default: release)
  -b, --backend             Backend-only build (no Qt GUI, pure C++)
  -l, --local               Build locally without Docker (requires Qt6)
  -c, --clean               Remove build directory before building
  -r, --run                 Run the application after successful build
  -h, --help                Display this help message

${GREEN}Examples:${NC}
  # Most common: build release desktop app with Docker (no Qt setup needed!)
  $(basename "$0")

  # Build debug version and run it
  $(basename "$0") -v debug -r

  # Build backend-only (no Qt dependencies)
  $(basename "$0") -b

  # Clean build
  $(basename "$0") -c

  # Local build with system-installed Qt6
  $(basename "$0") -l

${GREEN}Quick Start${NC}
  Just run the script - Docker handles all dependencies!
  
  $(basename "$0")

  The first build downloads Qt6 and dependencies (~800MB, 3-7 minutes).
  Subsequent builds are fast (~1 minute) due to Docker layer caching.

${GREEN}Requirements${NC}
  ${YELLOW}For Docker builds (recommended):${NC}
  - Docker installed
  - Internet connection (to download Qt6 on first build)
  - ~1GB disk space

  ${YELLOW}For local builds (optional):${NC}
  - CMake 3.10+
  - Ninja build system
  - Qt6 with Core, Gui, and Widgets components
  - C++17 compatible compiler (GCC 7+, Clang 5+)

${GREEN}What Gets Installed in Docker${NC}
  - Ubuntu 24.04 LTS base system
  - Build tools: CMake 3.28+, Ninja, GCC 13
  - Qt6: Core, Gui, Widgets modules
  - Development libraries: X11, OpenGL
  - Testing: Catch2 framework
  - Total: ~1.2GB Docker image (compressed), ~3GB uncompressed

${GREEN}Build Modes${NC}
  ${YELLOW}Full Desktop Build (default):${NC}
  - Complete Qt6 GUI application
  - Calculator window with interactive buttons
  - Desktop executable with all features

  ${YELLOW}Backend-Only Build (-b):${NC}
  - Pure C++ library, no Qt dependency
  - Headless calculator logic
  - Useful for embedded systems or servers

${GREEN}Output${NC}
  - Executable: build/app (or build/BookMeSilly)
  - Backend library: build/libbackend.a
  - Frontend library: build/libfrontend.a (if not backend-only)
  - Tests: build/test_calculator (always built)

${GREEN}Documentation${NC}
  See docs/ for more information:
  - docs/ARCHITECTURE.md: Project structure and design
  - docs/CONTRIBUTING.md: Development guidelines
  - docs/DEPENDENCIES.md: Dependency management

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

clean_build_dir() {
    local build_dir="${PROJECT_ROOT}/build"
    if [[ -d "$build_dir" ]]; then
        print_section "Removing existing build directory..."
        rm -rf "$build_dir"
        print_success "Build directory cleaned"
    else
        print_section "Build directory does not exist, skipping clean"
    fi
}

build_with_docker() {
    print_section "Building desktop application with Docker"
    print_section "Variant: $BUILD_VARIANT"
    if $BACKEND_ONLY; then
        print_section "Mode: Backend-only (no Qt GUI)"
    else
        print_section "Mode: Full desktop application with Qt GUI"
    fi

    # Check if image already exists
    if docker image inspect bookmesilly:builder &>/dev/null; then
        print_section "Using cached Docker image (bookmesilly:builder)"
    else
        print_section "Building Docker image with Qt6 and development tools..."
        print_section "First build downloads ~800MB (Qt6 cached for future builds)"
        print_section "Estimated time: 3-7 minutes on first build, ~1 minute afterwards"
        
        if ! docker build \
            -f "${PROJECT_ROOT}/config/docker/Dockerfile" \
            -t "bookmesilly:builder" \
            --target builder \
            ${DOCKER_BUILD_ARGS:+${DOCKER_BUILD_ARGS}} \
            "${PROJECT_ROOT}"; then
            print_error "Docker image build failed"
            return 1
        fi
        print_success "Docker image built successfully with Qt6 included"
    fi

    # Prepare build arguments
    local cmake_build_type
    if [[ "$BUILD_VARIANT" = "debug" ]]; then
        cmake_build_type="Debug"
    else
        cmake_build_type="Release"
    fi

    local backend_only_flag=""
    if $BACKEND_ONLY; then
        backend_only_flag="-DBACKEND_ONLY=ON"
    fi

    # Run build in container
    print_section "Running desktop build in Docker container..."
    BUILD_OUTPUT_DIR="${PROJECT_ROOT}/build"
    mkdir -p "${BUILD_OUTPUT_DIR}"

    if ! docker run --rm \
        -v "${PROJECT_ROOT}:/build" \
        -w /build \
        "bookmesilly:builder" \
        bash -c "
            set -euo pipefail
            mkdir -p build && cd build
            cmake .. -GNinja -DCMAKE_BUILD_TYPE=${cmake_build_type} ${backend_only_flag}
            ninja
        "; then
        print_error "Docker build failed"
        print_section "Check output above for details"
        return 1
    fi

    print_success "Desktop build completed successfully"
    print_section "Build directory: ${BUILD_OUTPUT_DIR}"
    
    if ! $BACKEND_ONLY && [[ -f "${BUILD_OUTPUT_DIR}/app" ]]; then
        print_success "Executable created: ${BUILD_OUTPUT_DIR}/app"
    fi
}

build_locally() {
    print_section "Building desktop application locally (without Docker)"

    # Check for required tools
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

    # Check for Qt6 (only if not backend-only build)
    if ! $BACKEND_ONLY; then
        if ! cmake --find-package -DNAME=Qt6 -DCOMPILER_ID=GNU -DLANGUAGE=CXX -DMODE=EXIST &>/dev/null; then
            print_section "Qt6 may not be installed or not in CMAKE_PREFIX_PATH"
            print_section "Install Qt6 with:"
            print_section "  Ubuntu/Debian: sudo apt-get install qt6-base-dev"
            print_section "  macOS: brew install qt@6"
            print_section ""
            print_section "Or use backend-only mode: $(basename "$0") -b"
        fi
    fi

    print_section "Build variant: $BUILD_VARIANT"
    if $BACKEND_ONLY; then
        print_section "Backend-only mode: Pure C++ library (no Qt)"
    else
        print_section "Full desktop mode: Qt6 GUI application"
    fi

    BUILD_DIR="${PROJECT_ROOT}/build"
    mkdir -p "${BUILD_DIR}"
    cd "${BUILD_DIR}"

    # Prepare CMake arguments
    local cmake_build_type
    if [[ "$BUILD_VARIANT" = "debug" ]]; then
        cmake_build_type="Debug"
    else
        cmake_build_type="Release"
    fi

    local cmake_args="-GNinja -DCMAKE_BUILD_TYPE=${cmake_build_type}"
    if $BACKEND_ONLY; then
        cmake_args="${cmake_args} -DBACKEND_ONLY=ON"
    fi

    print_section "Configuring CMake..."
    if ! cmake .. "${cmake_args}"; then
        print_error "CMake configuration failed"
        return 1
    fi

    print_section "Building with Ninja..."
    if ! ninja; then
        print_error "Ninja build failed"
        return 1
    fi

    print_success "Local desktop build completed"
    print_section "Build directory: ${BUILD_DIR}"
    
    if ! $BACKEND_ONLY && [[ -f "${BUILD_DIR}/app" ]]; then
        print_success "Executable: ${BUILD_DIR}/app"
    fi
}

run_application() {
    if $BACKEND_ONLY; then
        print_section "Cannot run backend-only build (no executable)"
        return 0
    fi

    local app_path="${PROJECT_ROOT}/build/app"
    if [[ ! -f "$app_path" ]]; then
        print_error "Application not found at: $app_path"
        return 1
    fi

    if [[ ! -x "$app_path" ]]; then
        print_section "Application is not executable, making it executable..."
        chmod +x "$app_path"
    fi

    print_section "Running application: $app_path"
    print_section "----------------------------------------"
    "$app_path"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--variant)
            BUILD_VARIANT="$2"
            validate_variant "$BUILD_VARIANT" || exit 1
            shift 2
            ;;
        -b|--backend)
            BACKEND_ONLY=true
            shift
            ;;
        -l|--local)
            USE_DOCKER=false
            shift
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            shift
            ;;
        -r|--run)
            RUN_AFTER_BUILD=true
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
print_header "BookMeSilly Desktop Build"
print_section "Project root: ${PROJECT_ROOT}"

# Clean if requested
if $CLEAN_BUILD; then
    clean_build_dir
fi

# Execute build
if $USE_DOCKER; then
    build_with_docker || exit 1
else
    build_locally || exit 1
fi

print_success "Desktop build completed successfully!"
print_section "Build artifacts are in: ${PROJECT_ROOT}/build/"

if ! $BACKEND_ONLY; then
    if [[ -f "${PROJECT_ROOT}/build/app" ]]; then
        print_success "Application executable: ${PROJECT_ROOT}/build/app"
        print_section "Run with: ./build/app"
        print_section "Or use: $(basename "$0") -r"
    fi
fi

# Run if requested
if $RUN_AFTER_BUILD; then
    echo ""
    run_application
fi
