# Android Build Configuration

This document describes how to build BookMeSilly for Android devices using Docker and the Android SDK/NDK.

## Overview

The Android build configuration adds a new `android-builder` Docker stage to the existing multi-stage build setup. This provides a complete, isolated Android development and build environment without requiring local Android SDK/NDK installation.

### Key Components

- **Android SDK**: Command-line tools for Android platform and build tools
- **Android NDK**: Native development kit for C++ compilation to Android native code
- **Qt for Android**: Qt framework configured for Android cross-compilation
- **Java Development Kit**: OpenJDK 17 for Android build tools
- **CMake & Ninja**: Cross-platform build system and build generator
- **Gradle**: Build tool for final APK packaging

## Quick Start

### Prerequisites

Before you can build for Android, you need to install Android NDK:

1. **Download Android NDK**: Get the latest LTS version from https://developer.android.com/ndk/downloads
2. **Extract**: Save to a location like `~/Android/ndk`
3. **Set Environment Variable**: 
   ```bash
   export ANDROID_NDK=~/Android/ndk
   ```

### Building (with Docker)

Once you have `ANDROID_NDK` set, building is simple:

```bash
# Build release APK for arm64-v8a (most devices)
./scripts/build/android-build.sh

# Build debug APK for 32-bit ARM (older devices)
./scripts/build/android-build.sh -v debug -a armeabi-v7a

# Build for x86_64 (emulators, some tablets)
./scripts/build/android-build.sh -a x86_64
```

The script automatically:
- Uses Docker to provide a clean build environment
- Mounts your NDK directory into the container
- Configures CMake with Android cross-compilation settings
- Builds the native code

### Building Locally (Alternative)

If you prefer not to use Docker:

```bash
# Ensure ANDROID_NDK is set
export ANDROID_NDK=~/Android/ndk

# Run local build
./scripts/build/android-build.sh --local
```

This approach uses your local build tools instead of Docker.

## Setup Instructions

### Installing Android NDK

#### Linux

```bash
# Create Android directory
mkdir -p ~/Android/ndk

# Download (check for latest version at developer.android.com/ndk/downloads)
wget https://dl.google.com/android/repository/android-ndk-r26-linux.zip

# Extract
unzip android-ndk-r26-linux.zip
mv android-ndk-r26 ~/Android/ndk/

# Set environment variable
export ANDROID_NDK=~/Android/ndk
```

#### macOS

```bash
# Using Homebrew (recommended)
brew install android-ndk

# Then find the path:
echo "$(brew --prefix)/share/android-ndk"

# Set environment variable  
export ANDROID_NDK="$(brew --prefix)/share/android-ndk"
```

Or download from: https://developer.android.com/ndk/downloads

#### Windows

1. Download from https://developer.android.com/ndk/downloads
2. Extract to a location (e.g., `C:\Android\ndk`)
3. Set environment variable in PowerShell:
   ```powershell
   [Environment]::SetEnvironmentVariable("ANDROID_NDK", "C:\Android\ndk", "User")
   ```

### Install Build Dependencies

#### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  openjdk-17-jdk \
  python3-dev
```

#### macOS
```bash
brew install cmake ninja openjdk@17
```

### Verify Installation

```bash
# Check NDK
$ANDROID_NDK/toolchains/llvm/prebuilt/linux-x86_64/bin/clang --version

# Check CMake
cmake --version

# Check Ninja
ninja --version
```

## Android Build Process

The `android-builder` Docker stage provides a clean environment that:
1. Contains essential build tools (CMake, Ninja, GCC toolchain)
2. Has OpenJDK for any Android-specific tooling
3. Accepts your local Android NDK via volume mount
4. Configures CMake for Android cross-compilation

### Docker Build Step-by-Step

When you run `./scripts/build/android-build.sh`:

1. **Build Docker Image** (first time only)
   - Creates `bookmesilly:android-builder` image
   - Installs build tools (~200MB)
   - Takes ~30 seconds on subsequent runs (cached)

2. **Mount NDK Directory**
   - Your local NDK is mounted into the container
   - Accessed as read-only for extra safety

3. **Configure CMake**
   - Sets up Android-specific CMake variables
   - Configures cross-compilation toolchain
   - Selects architecture (arm64-v8a, armeabi-v7a, x86, x86_64)

4. **Compile**
   - Builds native C++ code for Android
   - Generates native binaries for target architecture
   - Full build takes ~2-5 minutes depending on code size

### Local Build (Without Docker)

When using`--local` flag:

1. Uses your system CMake directly
2. Uses your system compilers (GCC/Clang)
3. Accesses NDK from `$ANDROID_NDK` environment variable
4. Builds in your local `/build` directory

## Architecture Decision

Why use a lightweight Docker stage rather than pre-built Docker image?

1. **No Redundant Downloads**: Android NDK is huge (1-2GB). You only download it once and reuse locally.
2. **Fast Iteration**: Mount the same NDK for multiple builds. No Docker image bloat.
3. **Developer Control**: Developers manage their NDK version independently.
4. **Bandwidth Efficiency**: Perfect for CI systems that cache NDK separately.
5. **Offline Builds**: Works with cached NDK even without internet.
6. **Simplicity**: Main Dockerfile stays focused on core C++ building.

## Supported Architectures

The android-builder supports multiple processor architectures:

| Architecture | ABI | Device Support | Notes |
|---|---|---|---|
| **arm64-v8a** | 64-bit ARM | Modern phones (default) | 99% of modern Android devices |
| **armeabi-v7a** | 32-bit ARM | Older devices | Legacy support for Android 5.0+ |
| **x86** | 32-bit Intel | Emulators | Android Studio emulator (legacy) |
| **x86_64** | 64-bit Intel | Emulators & tablets | High-end tablets, Android Studio emulator |

### Recommended Configuration

For production releases, build multiple architectures:

```bash
# Build for all major architectures
for arch in armeabi-v7a arm64-v8a x86_64; do
  ./scripts/build/android-build.sh -a "$arch"
done
```

## Build Variants

### Debug Builds

```bash
./scripts/build/android-build.sh -v debug
```

**Characteristics:**
- Debuggable APK (allows debugging with Android Studio)
- Larger file size
- Faster compilation
- Contains debug symbols for error analysis
- Can be installed on development devices

### Release Builds

```bash
./scripts/build/android-build.sh -v release
```

**Characteristics:**
- Optimized for performance
- Smaller file size
- Production-ready
- Requires APK signing before distribution
- Code obfuscation possible with ProGuard/R8

## CMake Configuration

The Android build uses a specialized CMake toolchain that:

1. **Sets Android system**: `CMAKE_SYSTEM_NAME=Android`
2. **Specifies API level**: `CMAKE_ANDROID_PLATFORM=android-34`
3. **Selects NDK**: `CMAKE_ANDROID_NDK=/opt/android/ndk/26.1.10909125`
4. **Configures ABI**: `CMAKE_ANDROID_ABI=arm64-v8a` (configurable)
5. **Sets runtime**: `CMAKE_ANDROID_STL=c++_shared` (STL library)

### Custom CMake Configuration

To modify build behavior, edit the CMakeToolchain:

```bash
# After CMake configuration
cmake .. \
  -DCMAKE_ANDROID_ABI=arm64-v8a \
  -DANDROID_PLATFORM=api-34 \
  -DCMAKE_BUILD_TYPE=Release
```

## Environment Variables

### For Docker Builds

```bash
# Optional: Pass additional Docker build arguments
export DOCKER_BUILD_ARGS="--build-arg BUILDKIT_INLINE_CACHE=1"

./scripts/build/android-build.sh
```

### For Local Builds

```bash
# Required for local builds
export ANDROID_HOME=/path/to/android-sdk
export ANDROID_NDK=/path/to/android-ndk

./scripts/build/android-build.sh --local
```

## Output Artifacts

### Build Directory Structure

```
BookMeSilly/
├── android-build/           # Build directory
│   ├── CMakeCache.txt
│   ├── build.ninja
│   ├── app/
│   │   └── outputs/
│   │       └── apk/         # APK files (debug or release)
│   │           ├── app-debug.apk
│   │           └── app-release.apk
│   └── CMakeFiles/
└── scripts/
    └── build/
        └── android-build.sh  # Main build script
```

### Generated APKs

The build produces:

- **Debug APK**: `app-debug.apk` (unsigned, for testing)
- **Release APK**: `app-release-unsigned.apk` (requires signing)

## APK Signing (Release Builds)

For Google Play Store distribution, release APKs must be signed:

```bash
# Create a keystore (one-time setup)
keytool -genkey -v -keystore my-release-key.keystore \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias my-key-alias

# Sign the APK
jarsigner -verbose -sigalg SHA256withRSA -digestalg SHA-256 \
  -keystore my-release-key.keystore \
  android-build/app/outputs/apk/release/app-release-unsigned.apk \
  my-key-alias

# Align the APK (optimize resources)
zipalign -v 4 \
  android-build/app/outputs/apk/release/app-release-unsigned.apk \
  app-release.apk
```

## Deployment

### Testing on Connected Device

```bash
# Install debug APK on connected device
adb install android-build/app/outputs/apk/debug/app-debug.apk

# View app logs
adb logcat | grep BookMeSilly

# Uninstall app
adb uninstall com.bookmesilly.app
```

### Android Emulator

```bash
# Start emulator
emulator -avd Pixel_5 &

# Wait for emulator to boot
adb wait-for-device

# Install APK
adb install android-build/app/outputs/apk/debug/app-debug.apk
```

### Google Play Store

1. Sign the release APK (see APK Signing section)
2. Create Google Play Developer account
3. Create new app in Play Console
4. Upload signed APK
5. Fill in store listing metadata
6. Review and publish

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Android Build

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  android-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Build Android APK
        run: ./scripts/build/android-build.sh -v release
      
      - name: Upload APK Artifacts
        uses: actions/upload-artifact@v3
        with:
          name: android-apk
          path: android-build/app/outputs/apk/release/
```

### GitLab CI Example

```yaml
android-build:
  image: docker:latest
  services:
    - docker:dind
  script:
    - ./scripts/build/android-build.sh -v release
  artifacts:
    paths:
      - android-build/app/outputs/apk/release/
    expire_in: 1 week
```

## Troubleshooting

### 1. Docker Build Fails with SSL Certificate Error

```bash
# Solution: Update CA certificates
docker build --build-arg SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  -t bookmesilly:android-builder .
```

### 2. NDK Download Timeout

```bash
# Solution: Build with increased timeout
timeout 600 ./scripts/build/android-build.sh
```

### 3. CMake Cannot Find Qt

**Debug:**
```bash
# Check Qt installation in Docker
docker run --rm bookmesilly:android-builder ls -la /opt/qt
```

**Solution:** Rebuild Docker image without cache:
```bash
docker build --no-cache -f config/docker/Dockerfile \
  -t bookmesilly:android-builder \
  --target android-builder .
```

### 4. APK Installation Fails on Device

```bash
# Check error details
adb install -r android-build/app/outputs/apk/debug/app-debug.apk

# Common solutions:
# - App not compatible with device architecture
# - Device API level too old (minimum: API 21)
# - Insufficient storage on device
```

## Performance Optimization

### Docker Image Caching

```bash
# First build: ~15-20 minutes
./scripts/build/android-build.sh

# Subsequent builds: ~2-3 minutes (cached layers)
./scripts/build/android-build.sh -v debug
```

### Parallel Architecture Builds

```bash
# Build multiple architectures in parallel
(./scripts/build/android-build.sh -a arm64-v8a &) && \
(./scripts/build/android-build.sh -a armeabi-v7a &) && \
wait
```

### Incremental Builds

The Docker container maintains build artifacts, so rebuilds are incremental:

```bash
# First debug build
./scripts/build/android-build.sh -v debug  # ~5 min

# Subsequent debug builds
./scripts/build/android-build.sh -v debug  # ~1 min
```

## Security Considerations

### 1. Keystore Management

```bash
# Protect your keystore file
chmod 600 my-release-key.keystore

# Backup securely
gpg --symmetric my-release-key.keystore
```

### 2. API Key Management

For production apps requiring API keys:

```gradle
// build.gradle
buildTypes {
    release {
        buildConfigField "String", "API_KEY", "\"${System.getenv('ANDROID_API_KEY')}\""
    }
}
```

### 3. ProGuard Configuration

Protect code in release builds:

```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

## Further Resources

- [Android SDK Guide](https://developer.android.com/studio/command-line/sdkmanager)
- [Android NDK Guide](https://developer.android.com/ndk/guides)
- [Qt for Android](https://doc.qt.io/qt-6/android-getting-started.html)
- [CMake Android Toolchain](https://cmake.org/cmake/help/latest/manual/cmake-toolchains.7.html#android)
- [Google Play Console](https://play.google.com/console)

## Support

For issues or questions regarding Android builds:

1. Check the Troubleshooting section above
2. Review build logs: `docker logs <container-id>`
3. See [CONTRIBUTING.md](../CONTRIBUTING.md) for development setup
4. Report issues in project repository
