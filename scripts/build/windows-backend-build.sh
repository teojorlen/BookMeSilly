#!/usr/bin/env bash
################################################################################
# BookMeSilly - Windows Backend Cross-Compilation Script
# Purpose: Build Windows backend library and tests using MinGW-w64
# Usage: ./scripts/build/windows-backend-build.sh [OPTIONS]
################################################################################

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# Default configuration
BUILD_TYPE="Release"
OUTPUT_DIR="${PROJECT_ROOT}/output/windows"
IMAGE_NAME="bookme-silly:windows-backend"
DOCKERFILE="${PROJECT_ROOT}/config/docker/Dockerfile.windows-backend"
CLEAN_BUILD=false
VERIFY_ONLY=false
RUN_TESTS=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

################################################################################
# Functions
################################################################################

print_usage() {
    cat << EOF
${BLUE}BookMeSilly Windows Backend Cross-Compilation${NC}

${YELLOW}Usage:${NC}
    $0 [OPTIONS]

${YELLOW}Options:${NC}
    -h, --help              Show this help message
    -c, --clean             Clean build (remove existing image)
    -v, --verify            Only verify the build (don't extract)
    -t, --test              Run unit tests with Wine
    -o, --output DIR        Output directory (default: output/windows)
    -b, --type TYPE         Build type: Release or Debug (default: Release)
    
${YELLOW}Examples:${NC}
    # Standard build
    $0
    
    # Build and run tests
    $0 --test
    
    # Clean build
    $0 --clean
    
    # Debug build with tests
    $0 --type Debug --test
    
    # Custom output directory
    $0 --output /tmp/windows-build

${YELLOW}Output:${NC}
    - test_calculator.exe   Windows test executable
    - libbackend.a          Windows static library
    - BUILD_INFO.txt        Build metadata

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

check_docker() {
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed or not in PATH"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        print_error "Docker daemon is not running"
        exit 1
    fi
    
    print_success "Docker is available"
}

clean_previous_build() {
    print_section "Cleaning previous build artifacts..."
    
    # Remove output directory
    if [ -d "${OUTPUT_DIR}" ]; then
        rm -rf "${OUTPUT_DIR}"
        print_success "Removed ${OUTPUT_DIR}"
    fi
    
    # Remove Docker image
    if docker image inspect "${IMAGE_NAME}" &> /dev/null; then
        docker rmi "${IMAGE_NAME}" || print_section "Failed to remove image ${IMAGE_NAME}"
        print_success "Removed Docker image ${IMAGE_NAME}"
    fi
}

build_windows_backend() {
    print_section "Building Windows backend with MinGW-w64..."
    print_section "Dockerfile: ${DOCKERFILE}"
    print_section "Build type: ${BUILD_TYPE}"
    
    local start_time=$(date +%s)
    
    # Build the Docker image
    if docker build \
        -f "${DOCKERFILE}" \
        --target verify \
        -t "${IMAGE_NAME}" \
        --build-arg BUILD_TYPE="${BUILD_TYPE}" \
        "${PROJECT_ROOT}"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "Build completed in ${duration} seconds"
        return 0
    else
        print_error "Build failed"
        return 1
    fi
}

extract_binaries() {
    print_section "Extracting Windows binaries to ${OUTPUT_DIR}..."
    
    # Create output directory
    mkdir -p "${OUTPUT_DIR}"
    
    # Extract binaries using docker build with export stage
    if docker build \
        -f "${DOCKERFILE}" \
        --target export \
        -o "${OUTPUT_DIR}" \
        "${PROJECT_ROOT}"; then
        
        print_success "Binaries extracted to ${OUTPUT_DIR}"
        
        # List extracted files
        print_section "Build artifacts:"
        ls -lh "${OUTPUT_DIR}"
        
        # Display build info
        if [ -f "${OUTPUT_DIR}/BUILD_INFO.txt" ]; then
            echo ""
            cat "${OUTPUT_DIR}/BUILD_INFO.txt"
        fi
        
        return 0
    else
        print_error "Failed to extract binaries"
        return 1
    fi
}

verify_build() {
    print_section "Verifying Windows build..."
    
    # Check if test executable exists in the image
    if docker run --rm "${IMAGE_NAME}" \
        bash -c "[ -f build-windows/test_calculator.exe ] && [ -f build-windows/libbackend.a ]"; then
        print_success "Build verification passed"
        
        # Show file information
        docker run --rm "${IMAGE_NAME}" bash -c "file build-windows/*.exe build-windows/*.a"
        
        return 0
    else
        print_error "Build verification failed"
        return 1
    fi
}

run_tests() {
    print_section "Running Windows unit tests with Wine..."
    
    local start_time=$(date +%s)
    
    # Build and run test stage
    if docker build \
        -f "${DOCKERFILE}" \
        --target test \
        -t "${IMAGE_NAME}-test" \
        "${PROJECT_ROOT}"; then
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        print_success "All tests passed in ${duration} seconds"
        return 0
    else
        print_error "Tests failed"
        return 1
    fi
}

################################################################################
# Main
################################################################################

main() {
    cd "${PROJECT_ROOT}"
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -c|--clean)
                CLEAN_BUILD=true
                shift
                ;;
            -v|--verify)
                VERIFY_ONLY=true
                shift
                ;;
            -t|--test)
                RUN_TESTS=true
                shift
                ;;
            -o|--output)
                OUTPUT_DIR="$2"
                shift 2
                ;;
            -b|--type)
                BUILD_TYPE="$2"
                if [[ ! "${BUILD_TYPE}" =~ ^(Release|Debug)$ ]]; then
                    print_error "Invalid build type: ${BUILD_TYPE}"
                    print_error "Must be 'Release' or 'Debug'"
                    exit 1
                fi
                shift 2
                ;;
            *)
                print_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
    done
    
    # Display configuration
    print_header "Windows Backend Cross-Compilation"
    echo "Project: ${PROJECT_ROOT}"
    echo "Build Type: ${BUILD_TYPE}"
    echo "Output: ${OUTPUT_DIR}"
    echo "Image: ${IMAGE_NAME}"
    echo ""
    
    # Check prerequisites
    check_docker
    
    # Clean if requested
    if [ "${CLEAN_BUILD}" = true ]; then
        clean_previous_build
    fi
    
    # Build Windows backend
    if ! build_windows_backend; then
        exit 1
    fi
    
    # Verify build
    if ! verify_build; then
        exit 1
    fi
    
    # Run tests if requested
    if [ "${RUN_TESTS}" = true ]; then
        if ! run_tests; then
            exit 1
        fi
    fi
    
    # Extract binaries unless verify-only
    if [ "${VERIFY_ONLY}" = false ]; then
        if ! extract_binaries; then
            exit 1
        fi
    fi
    
    echo ""
    print_success "Windows backend build completed successfully!"
    echo ""
    print_section "Next steps:"
    echo "  • Test on Windows: wine ${OUTPUT_DIR}/test_calculator.exe"
    echo "  • Link your app: g++ -o myapp.exe main.cpp ${OUTPUT_DIR}/libbackend.a"
    echo ""
}

main "$@"
