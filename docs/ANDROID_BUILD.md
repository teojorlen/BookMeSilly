# Android Build Configuration

This document describes how to build BookMeSilly for Android devices using Docker with a complete, pre-configured Android NDK environment.

## Overview

The Android build is fully containerized using Docker. Everything needed to build Android APKs is included:
- Ubuntu 24.04 LTS base system
- Build tools: CMake, Ninja, GCC/Clang
- Java: OpenJDK 17
- **Android NDK r26**: Fully installed with all architectures (arm64-v8a, armeabi-v7a, x86, x86_64)

**Zero setup required!** Just have Docker installed.

## Quick Start

That's literally it:

```bash
./scripts/build/android-build.sh
```

This builds a release APK for arm64-v8a (modern Android devices).

### First Build
- Downloads ~500MB (Android NDK)
- Takes ~2-5 minutes
- Docker layers are cached for future builds

### Subsequent Builds
- Uses cached layers
- Takes ~30 seconds

### Other Variations

```bash
# Debug build (includes symbols for debugging)
./scripts/build/android-build.sh -v debug

# Build for 32-bit ARM (Android 5.0+, older devices)
./scripts/build/android-build.sh -a armeabi-v7a

# Build for tablet emulator
./scripts/build/android-build.sh -a x86_64

# See all options
./scripts/build/android-build.sh --help
```

## Why This Approach?

Docker provides several advantages:

| Aspect | Docker | Local Install |
|--------|--------|---------------|
| **Setup Time** | 0 minutes | 30-60 minutes |
| **Disk Space** | ~900MB | 1-2GB |
| **Maintenance** | Auto-updated with project | Manual updates |
| **Reproducibility** | Always identical | Varies by machine |
| **CI/CD** | Native support | Complex setup |
| **Cleanup** | `docker prune` | Uninstall NDK |

## Prerequisites

## Prerequisites

Just Docker:

```bash
# Linux (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install docker.io

# Start Docker daemon (Linux)
sudo systemctl start docker

# macOS (with Homebrew)
brew install docker

# Windows
# Download Docker Desktop from docker.com
```

Verify Docker is installed:

```bash
docker --version
docker run hello-world
```

That's all you need!

## How It Works

### Docker Image Build Process

When you run `./scripts/build/android-build.sh`:

1. **Check for cached image** (~instant if image exists)
   - Script checks if `bookmesilly:android-builder` Docker image exists
   - Uses cached image if available (no re-download needed)

2. **Build Docker image** (first time only, ~2-5 minutes)
   - Downloads base Ubuntu 24.04 image (~80MB)
   - Installs build tools and dependencies (~100MB)
   - Downloads Android NDK r26 (~500MB)
   - Total: ~900MB compressed, ~2GB extracted
   - Docker caches each layer for reuse

3. **Run build in container** (~30 seconds)
   - Mounts project source code
   - Configures CMake with Android NDK cross-compiler
   - Compiles C++ code to native Android binaries
   - Outputs build artifacts to `./android-build/`

### Supported Architectures

The Android NDK included in Docker supports:

| Architecture | ABI | Device Type | Notes |
|---|---|---|---|
| **arm64-v8a** | 64-bit ARM | Modern phones & tablets | 99% of devices (default) |
| **armeabi-v7a** | 32-bit ARM | Older devices | Android 5.0+ support |
| **x86** | 32-bit Intel | Emulator (legacy) | Android Studio emulator |
| **x86_64** | 64-bit Intel | Emulator & high-end | Modern Android Studio |

**Recommendation**: Use `arm64-v8a` as default (covers 99% of devices).

For production releases, build multiple architectures:

```bash
for arch in arm64-v8a armeabi-v7a x86_64; do
  ./scripts/build/android-build.sh -a "$arch"
done
```

## Build Variants

### Debug Builds

```bash
./scripts/build/android-build.sh -v debug
```

**Characteristics:**
- Includes debug symbols for troubleshooting
- Allows debugger attachment (Android Studio)
- Larger APK file size
- Slightly slower execution
- Perfect for development and testing

### Release Builds

```bash
./scripts/build/android-build.sh  # default
```

**Characteristics:**
- Optimized for performance
- Smaller APK file size
- No debug symbols
- Requires signing before distribution
- Ready for production deployment

## Local Builds (Optional)

If you prefer to build without Docker (requires manual NDK installation):

```bash
# Set up Android NDK locally
export ANDROID_NDK=/path/to/android-ndk

# Install build dependencies
# Ubuntu: sudo apt-get install cmake ninja-build openjdk-17-jdk

# Run local build
./scripts/build/android-build.sh --local
```

This approach uses your system compilers instead of Docker's containerized environment.

## Build Output## Supported Architectures

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
