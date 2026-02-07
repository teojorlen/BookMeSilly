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
    python3 \
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
