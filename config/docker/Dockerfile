################################################################################
# BookMeSilly - Multi-stage Docker Build
# Build: Ubuntu 24.04 LTS (Latest Stable)
# Purpose: Qt6-based Audiobook Player with Cross-Platform Support
################################################################################

# ============================================================================
# Stage 1: Builder
# Contains all build tools and dependencies needed to compile the application
# ============================================================================
FROM ubuntu:24.04 AS builder

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Update package lists
RUN apt-get update && apt-get install -y \
    # Build tools and compilers
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    curl \
    wget \
    \
    # Code analysis and scripting
    cppcheck \
    shellcheck \
    python3 \
    python3-pip \
    \
    # Qt6 development packages
    qt6-base-dev \
    qt6-base-dev-tools \
    qmake6 \
    \
    # X11 and display libraries
    libx11-dev \
    libxcb1-dev \
    libxkbcommon-dev \
    libxkbcommon-x11-dev \
    libxkbcommon-x11-0 \
    libxcb-xkb-dev \
    libxcb-keysyms1 \
    libxcb-render-util0 \
    libxcb-shape0 \
    libxcb-icccm4 \
    libxcb-image0 \
    \
    # Graphics and OpenGL
    libgl-dev \
    libglx-dev \
    libopengl-dev \
    libvulkan-dev \
    \
    # Wayland support
    libwayland-dev \
    wayland-protocols \
    \
    # Input device support
    libinput-dev \
    libmtdev-dev \
    libevdev-dev \
    libts-dev \
    libwacom-dev \
    \
    # Additional system libraries
    libpthread-stubs0-dev \
    libproxy-dev \
    libgudev-1.0-dev \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Install grype for vulnerability scanning
RUN curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# Install Python linting tools via apt
RUN apt-get update && apt-get install -y \
    pylint \
    && rm -rf /var/lib/apt/lists/*

# Create build directory
WORKDIR /build

# Copy source code
COPY . /build/

# Create build output directory
RUN mkdir -p /build/build

# Configure with CMake and Ninja
WORKDIR /build/build
RUN cmake .. -GNinja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/app

# Build with Ninja
RUN ninja

# Run tests (optional - comment out to skip)
RUN ninja test || true

# ============================================================================
# Stage 2: Runtime Base
# Minimal image with only runtime dependencies
# ============================================================================
FROM ubuntu:24.04 AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install only runtime dependencies
RUN apt-get update && apt-get install -y \
    # C++ runtime
    libstdc++6 \
    \
    # Qt6 runtime libraries
    libqt6core6t64 \
    libqt6gui6t64 \
    libqt6widgets6t64 \
    libqt6concurrent6t64 \
    \
    # X11 libraries
    libx11-6 \
    libxcb1 \
    libxkbcommon-x11-0 \
    \
    # Graphics libraries
    libgl1 \
    libglx0 \
    libopengl0 \
    \
    # Input support
    libinput10 \
    libmtdev1t64 \
    libevdev2 \
    \
    # Additional libraries
    libpcre2-16-0 \
    libdouble-conversion3 \
    libb2-1 \
    libproxy1v5 \
    libwacom9 \
    libgudev-1.0-0 \
    libxkbcommon0 \
    \
    # Optional: Wayland support for modern compositors
    libqt6waylandclient6 \
    libqt6waylandcompositor6 \
    qt6-wayland \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# ============================================================================
# Stage 3: Production Image (Final)
# Lightweight runtime image with the compiled application
# ============================================================================
FROM runtime AS production

LABEL maintainer="BookMeSilly"
LABEL description="BookMeSilly - Audiobook Player with Sync"
LABEL version="1.0"

# Copy compiled executable from builder
COPY --from=builder /build/build/app /usr/local/bin/bookme-silly
COPY --from=builder /build/build/test_calculator /usr/local/bin/test_calculator

# Make executable
RUN chmod +x /usr/local/bin/bookme-silly /usr/local/bin/test_calculator

# Create non-root user for security
RUN useradd -m --no-log-init appuser && \
    mkdir -p /home/appuser/audiobooks && \
    mkdir -p /home/appuser/.config/bookme-silly && \
    chown -R appuser:appuser /home/appuser

USER appuser
WORKDIR /home/appuser

# Health check (simple: test executable exists)
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD test -x /usr/local/bin/bookme-silly

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/bookme-silly"]

# ============================================================================
# Stage 4: Development Image
# Full development environment with all tools
# ============================================================================
FROM builder AS development

LABEL maintainer="BookMeSilly"
LABEL description="BookMeSilly Development Environment"

# Install additional development tools
RUN apt-get update && apt-get install -y \
    # Version control
    git \
    \
    # Editors and IDEs support
    vim \
    nano \
    \
    # Debugging tools
    gdb \
    valgrind \
    \
    # Documentation
    doxygen \
    graphviz \
    \
    # Code analysis
    clang-tools \
    cppcheck \
    \
    # Additional build systems
    make \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set working directory
WORKDIR /workspace

# Create a script for building
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Building BookMeSilly..."\n\
cd /workspace/build\n\
cmake .. -GNinja -DCMAKE_BUILD_TYPE=Release\n\
ninja\n\
echo "Running tests..."\n\
ninja test\n\
echo "Build complete!"\n\
' > /usr/local/bin/build.sh && chmod +x /usr/local/bin/build.sh

# Create a script for running the app
RUN echo '#!/bin/bash\n\
exec /workspace/build/app "$@"\n\
' > /usr/local/bin/run-app.sh && chmod +x /usr/local/bin/run-app.sh

# Default command for development
CMD ["/bin/bash"]

# ============================================================================
# Stage 5: Android Builder with NDK
# Complete Android development environment with NDK pre-installed
# ============================================================================
FROM ubuntu:24.04 AS android-builder

LABEL maintainer="BookMeSilly"
LABEL description="BookMeSilly Android Build Environment - Complete with NDK"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ANDROID_HOME=/opt/android \
    ANDROID_NDK_VERSION=r26 \
    ANDROID_API=34

# Install dependency packages (minimal for backend-only C++ builds)
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    \
    # Java for Android (NDK tooling uses Java)
    openjdk-17-jdk \
    openjdk-17-jre \
    \
    # Required system libraries
    libstdc++6 \
    libncurses6 \
    libncurses-dev \
    libc6-dev \
    \
    # Download and extraction tools
    curl \
    wget \
    unzip \
    \
    # Additional utilities
    python3 \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set Java and path environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=$JAVA_HOME/bin:/opt/android/ndk/bin:$PATH

# Create Android home directory
RUN mkdir -p ${ANDROID_HOME}/ndk

# Download and extract Android NDK
# Note: This layer will be cached after first build, making subsequent builds fast
RUN cd ${ANDROID_HOME} && \
    echo "Downloading Android NDK ${ANDROID_NDK_VERSION}..." && \
    wget -q https://dl.google.com/android/repository/android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    echo "Extracting Android NDK..." && \
    unzip -q android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    rm android-ndk-${ANDROID_NDK_VERSION}-linux.zip && \
    mv android-ndk-${ANDROID_NDK_VERSION} ndk/android-ndk && \
    ln -s ${ANDROID_HOME}/ndk/android-ndk/toolchains/llvm/prebuilt/linux-x86_64/bin ${ANDROID_HOME}/ndk/bin && \
    echo "Android NDK installation complete"

# Set NDK path
ENV ANDROID_NDK=${ANDROID_HOME}/ndk/android-ndk

# Copy project source
WORKDIR /build
COPY . /build/

# Create build directory
RUN mkdir -p /build/android-build

# Create build script for Android
RUN install -m 755 /dev/stdin /usr/local/bin/build-android.sh << 'EOF'
#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

BUILD_TYPE=${1:-Release}
ANDROID_ABI=${2:-arm64-v8a}
BUILD_DIR="/build/android-build"

echo -e "${BLUE}Android Build Configuration${NC}"
echo "Build type: $BUILD_TYPE"
echo "Architecture: $ANDROID_ABI"
echo "Android NDK: $ANDROID_NDK"
echo "Android API: $ANDROID_API"
echo ""

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo -e "${BLUE}Configuring CMake for Android...${NC}"
cmake .. \
    -GNinja \
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \
    -DCMAKE_SYSTEM_NAME=Android \
    -DCMAKE_SYSTEM_VERSION=$ANDROID_API \
    -DCMAKE_ANDROID_PLATFORM=android-$ANDROID_API \
    -DCMAKE_ANDROID_ABI="$ANDROID_ABI" \
    -DCMAKE_ANDROID_NDK="$ANDROID_NDK" \
    -DCMAKE_ANDROID_STL=c++_shared \
    -DBACKEND_ONLY=ON

echo -e "${BLUE}Building with Ninja...${NC}"
ninja

echo -e "${GREEN}Build complete!${NC}"
echo "Backend library: $BUILD_DIR/libbackend.a"
echo "Output: $BUILD_DIR"
EOF

# Create info script
RUN install -m 755 /dev/stdin /usr/local/bin/android-info.sh << 'EOF'
#!/bin/bash
echo "Android Build Environment Initialized (Backend Only)"
echo "====================================================="
echo "Android Home: $ANDROID_HOME"
echo "Android NDK: $ANDROID_NDK"
echo "Android API: $ANDROID_API"
echo "Java Home: $JAVA_HOME"
echo ""
echo "This build configuration creates backend C++ libraries only."
echo "No Qt/GUI components are included."
echo ""
echo "To build the backend library:"
echo "  build-android.sh [Release|Debug] [arm64-v8a|armeabi-v7a|x86|x86_64]"
echo ""
echo "Examples:"
echo "  build-android.sh Release arm64-v8a"
echo "  build-android.sh Debug armeabi-v7a"
EOF

# Verify NDK installation
RUN if [ ! -d "$ANDROID_NDK" ]; then \
        echo "ERROR: Android NDK not found at $ANDROID_NDK"; \
        exit 1; \
    fi && \
    echo "Android NDK verified at $ANDROID_NDK"

# Default command
CMD ["/bin/bash"]

