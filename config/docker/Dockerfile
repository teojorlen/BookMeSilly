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
# Stage 5: Android Builder (Cross-compilation environment)
# Note: This stage requires Android SDK/NDK to be pre-installed locally
# or uses builder stage output. See docs/ANDROID_BUILD.md for setup.
# ============================================================================
FROM ubuntu:24.04 AS android-builder

LABEL maintainer="BookMeSilly"
LABEL description="BookMeSilly Android Build Environment Base"

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8

# Install base dependencies for Android development
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build tools
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    \
    # Java for Android tooling
    openjdk-17-jdk \
    \
    # Required libraries
    libstdc++6 \
    libncurses5 \
    libncurses6 \
    \
    # Additional tools
    curl \
    wget \
    unzip \
    python3 \
    \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set Java home
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=$PATH:/usr/lib/jvm/java-17-openjdk-amd64/bin

# Create project workspace
WORKDIR /build
COPY . /build/

# Create build directory
RUN mkdir -p /build/build

# Script to run Android builds when SDK/NDK are available
RUN echo '#!/bin/bash\n\
set -e\n\
echo "Android Build Environment Setup"\n\
echo "==============================="\n\
if [ -z "$ANDROID_NDK" ]; then\n\
    echo "Error: ANDROID_NDK environment variable not set"\n\
    echo ""\n\
    echo "To set up Android builds:"\n\
    echo "  export ANDROID_NDK=/path/to/android-ndk"\n\
    echo "  export ANDROID_API=34"\n\
    exit 1\n\
fi\n\
\n\
BUILD_DIR="${PWD}/android-build"\n\
BUILD_TYPE=${1:-Release}\n\
ABI=${2:-arm64-v8a}\n\
\n\
mkdir -p "$BUILD_DIR"\n\
cd "$BUILD_DIR"\n\
\n\
cmake .. \\\n\
    -GNinja \\\n\
    -DCMAKE_BUILD_TYPE="$BUILD_TYPE" \\\n\
    -DCMAKE_SYSTEM_NAME=Android \\\n\
    -DCMAKE_SYSTEM_VERSION=$((ANDROID_API:=34)) \\\n\
    -DCMAKE_ANDROID_PLATFORM=android-$ANDROID_API \\\n\
    -DCMAKE_ANDROID_ABI="$ABI" \\\n\
    -DCMAKE_ANDROID_NDK="$ANDROID_NDK" \\\n\
    -DCMAKE_ANDROID_STL=c++_shared\n\
\n\
ninja\n\
' > /usr/local/bin/build-android.sh && \
    chmod +x /usr/local/bin/build-android.sh

# Default command
CMD ["/bin/bash"]

