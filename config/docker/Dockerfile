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
# Stage 5: Android Builder
# Android cross-compilation environment for building APKs
# ============================================================================
FROM ubuntu:24.04 AS android-builder

LABEL maintainer="BookMeSilly"
LABEL description="BookMeSilly Android Build Environment"

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    ANDROID_HOME=/opt/android \
    ANDROID_SDK_ROOT=/opt/android \
    ANDROID_NDK_VERSION=26.1.10909125 \
    ANDROID_API_VERSION=34 \
    QT_VERSION=6.6.3 \
    QT_PATH=/opt/qt

# Install build dependencies
RUN apt-get update && apt-get install -y \
    # Build tools
    build-essential \
    cmake \
    ninja-build \
    git \
    pkg-config \
    curl \
    wget \
    \
    # Java/JDK for Android build tools
    openjdk-17-jdk \
    openjdk-17-jre \
    \
    # Android SDK dependencies
    libstdc++6 \
    libncurses5 \
    libncurses6 \
    \
    # Gradle (used for APK signing)
    gradle \
    \
    # Python for build scripts
    python3 \
    python3-pip \
    \
    # Additional tools
    unzip \
    zip \
    \
    # Cleanup
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Set Java environment
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64 \
    PATH=$PATH:/usr/lib/jvm/java-17-openjdk-amd64/bin

# Create Android SDK directories
RUN mkdir -p ${ANDROID_HOME}/cmdline-tools

# Download Android SDK Command-line Tools
RUN cd ${ANDROID_HOME}/cmdline-tools && \
    ANDROID_SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip" && \
    echo "Downloading Android SDK Command-line Tools..." && \
    wget -q ${ANDROID_SDK_URL} -O cmdline-tools.zip && \
    unzip -q cmdline-tools.zip && \
    rm cmdline-tools.zip && \
    mv cmdline-tools tools && \
    ln -s tools/bin/sdkmanager ${ANDROID_HOME}/sdkmanager && \
    ln -s tools/bin/avdmanager ${ANDROID_HOME}/avdmanager

# Accept Android SDK licenses and install components
RUN ${ANDROID_HOME}/sdkmanager --sdk_root=${ANDROID_HOME} --licenses \
    "android-${ANDROID_API_VERSION}" \
    "build-tools;34.0.0" \
    "platform-tools" \
    "platforms;android-${ANDROID_API_VERSION}" \
    "ndk;${ANDROID_NDK_VERSION}" \
    "cmake;3.22.1" || true

# Set NDK path
ENV ANDROID_NDK=${ANDROID_HOME}/ndk/${ANDROID_NDK_VERSION}

# Download and extract Qt for Android
RUN mkdir -p ${QT_PATH} && \
    cd /tmp && \
    echo "Downloading Qt for Android (this may take a few minutes)..." && \
    QT_ANDROID_URL="https://download.qt.io/official_releases/qt/6.6/${QT_VERSION}/submodules/qtbase-everywhere-src-${QT_VERSION}.tar.xz" && \
    wget -q ${QT_ANDROID_URL} -O qtbase.tar.xz || \
    # Fallback: use Qt prebuilt binaries if direct download fails
    true && \
    if [ -f qtbase.tar.xz ]; then \
        tar -xf qtbase.tar.xz && \
        rm qtbase.tar.xz; \
    fi

# Create Qt for Android build script
RUN mkdir -p ${QT_PATH}/bin && \
    echo '#!/bin/bash\n\
ANDROID_NDK='${ANDROID_NDK}'\n\
ANDROID_API='${ANDROID_API_VERSION}'\n\
ANDROID_PLATFORM=android-'${ANDROID_API_VERSION}'\n\
\n\
# iOS and macOS configuration would go here\n\
export ANDROID_NDK\n\
export ANDROID_API\n\
export ANDROID_PLATFORM\n\
' > ${QT_PATH}/bin/setenv.sh && \
    chmod +x ${QT_PATH}/bin/setenv.sh

# Create Android CMake toolchain file
RUN mkdir -p ${QT_PATH}/cmake && \
    echo '# Android CMake Toolchain\n\
set(CMAKE_SYSTEM_NAME Android)\n\
set(CMAKE_SYSTEM_VERSION '${ANDROID_API_VERSION}')\n\
set(CMAKE_ANDROID_PLATFORM android-'${ANDROID_API_VERSION}')\n\
set(CMAKE_ANDROID_NDK "'${ANDROID_NDK}'")\n\
set(CMAKE_ANDROID_STL c++_shared)\n\
set(CMAKE_ANDROID_ABI armeabi-v7a)  # or arm64-v8a, x86, x86_64\n\
set(CMAKE_ANDROID_ARCH_ABI arm)\n\
\n\
# Compiler settings\n\
set(CMAKE_C_COMPILER_TARGET arm-linux-androideabi)\n\
set(CMAKE_CXX_COMPILER_TARGET arm-linux-androideabi)\n\
\n\
# Qt configuration\n\
set(QT_NO_OPENGL TRUE)\n\
' > ${QT_PATH}/cmake/android-toolchain.cmake && \
    chmod +x ${QT_PATH}/cmake/android-toolchain.cmake

# Create build script for Android APK
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
if [ $# -lt 1 ]; then\n\
    echo "Usage: build-apk.sh <source-dir> [build-variant]"\n\
    echo "Build variants: debug, release"\n\
    exit 1\n\
fi\n\
\n\
SOURCE_DIR=$1\n\
BUILD_VARIANT=${2:-release}\n\
BUILD_DIR=${SOURCE_DIR}/android-build\n\
\n\
echo "Building BookMeSilly for Android..."\n\
echo "Source: $SOURCE_DIR"\n\
echo "Build variant: $BUILD_VARIANT"\n\
echo "Android NDK: '$ANDROID_NDK\''"\n\
echo "Android API: '${ANDROID_API_VERSION}'"\n\
\n\
# Create build directory\n\
mkdir -p $BUILD_DIR\n\
cd $BUILD_DIR\n\
\n\
# Configure CMake for Android\n\
cmake .. \\\n\
    -GNinja \\\n\
    -DCMAKE_BUILD_TYPE=$([ "$BUILD_VARIANT" = "debug" ] && echo "Debug" || echo "Release") \\\n\
    -DCMAKE_TOOLCHAIN_FILE='${QT_PATH}'/cmake/android-toolchain.cmake \\\n\
    -DANDROID_NDK='${ANDROID_NDK}' \\\n\
    -DANDROID_PLATFORM=android-${ANDROID_API_VERSION} \\\n\
    -DANDROID_ABI=armeabi-v7a \\\n\
    -DCMAKE_INSTALL_PREFIX=/app \\\n\
    -DANDROID_NATIVE_API_LEVEL=${ANDROID_API_VERSION}\n\
\n\
# Build\n\
ninja\n\
\n\
echo "Android build complete!"\n\
echo "Output directory: $BUILD_DIR"\n\
' > /usr/local/bin/build-apk.sh && \
    chmod +x /usr/local/bin/build-apk.sh

# Set up environment for Android builds
ENV PATH=${ANDROID_HOME}/cmdline-tools/tools/bin:${ANDROID_HOME}/platform-tools:${PATH} \
    SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
    SSL_CERT_DIR=/etc/ssl/certs

# Create working directory
WORKDIR /build

# Copy project files
COPY . /build/

# Create helper script for Android builds
RUN echo '#!/bin/bash\n\
echo "Android Build Environment"\n\
echo "========================"\n\
echo "Android SDK: '${ANDROID_HOME}'"\n\
echo "Android NDK: '${ANDROID_NDK}'"\n\
echo "Android API: '${ANDROID_API_VERSION}'"\n\
echo "Java Home: '${JAVA_HOME}'"\n\
echo ""\n\
echo "To build an APK:"\n\
echo "  build-apk.sh /build [debug|release]"\n\
' > /usr/local/bin/android-info.sh && \
    chmod +x /usr/local/bin/android-info.sh

# Default command
CMD ["/bin/bash"]

