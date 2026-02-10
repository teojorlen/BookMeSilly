# BookMeSilly

An open source audio book player with high performance and cross-platform support. Synchronize your library and play status across devices.

## Quick Links

- **[Architecture](docs/ARCHITECTURE.md)** - Project structure and design
- **[Contributing](docs/CONTRIBUTING.md)** - How to contribute to the project
- **[Dependencies](docs/setup/DEPENDENCIES.md)** - Required packages and libraries
- **[Docker Guide](docs/docker/DOCKER.md)** - Container setup and usage
- **[CI/CD Setup](docs/ci/CI_SETUP.md)** - Continuous integration configuration
- **[Android Build](docs/ANDROID_BUILD.md)** - Android APK build and deployment
- **[Windows Backend Build](docs/WINDOWS_BACKEND_BUILD.md)** - Windows cross-compilation guide

## Features

- 🎵 High-performance audio playback
- 🔄 Cross-platform support
- ☁️ Library and play status synchronization (planned)
- 📦 Docker containerization
- ✅ Comprehensive test coverage
- 🔒 Security scanning and static analysis

## Quick Start

### Prerequisites
- Docker (recommended)
- CMake 3.10+
- C++17 compiler

### Build and Test
```bash
# Run local CI pipeline
./scripts/ci/ci-test.sh

# Or build manually with Docker
docker build --target builder -t bookme-silly:builder .
docker run bookme-silly:builder ninja test

# Or build with CMake
mkdir build && cd build
cmake ..
ninja
ninja test
```

### Development
```bash
# Run code quality checks
make run-code-quality

# Run security scan
make run-security-scan

# View available make targets
make help
```

### Android Build
```bash
# Build release APK for Android
./scripts/build/android-build.sh

# Build debug APK with 32-bit ARM support
./scripts/build/android-build.sh -v debug -a armeabi-v7a

# For more options
./scripts/build/android-build.sh --help
```

See [docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md) for comprehensive Android build guide.

### Windows Backend Build
```bash
# Build backend library and tests for Windows (cross-compilation)
./scripts/build/windows-backend-build.sh

# Or use make
make windows-backend

# Debug build
make windows-backend-debug
```

Output: `output/windows/test_calculator.exe` (3.6MB, x86_64)

See [docs/WINDOWS_BACKEND_BUILD.md](docs/WINDOWS_BACKEND_BUILD.md) for comprehensive Windows backend build guide.

## Project Organization

The project uses a concern-based organization:

```
docs/           → Documentation (architecture, setup, CI/CD)
src/            → Source code (backend library)
include/        → Header files
config/         → Configuration files (cppcheck, docker)
scripts/        → Automation scripts (CI, analysis, dev)
tests/          → Test suite (unit, integration)
assets/         → Static assets (icons, images, resources)
build/          → CMake build output (generated)
```

For detailed information, see [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Contributing

We welcome contributions! Please see [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) for:
- Development setup instructions
- Code style guidelines
- Testing requirements
- Pull request process
- Code review checklist

## Documentation

Comprehensive documentation is available in the `docs/` directory:

- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Full project structure and design decisions
- **[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md)** - Contribution guidelines
- **[docs/ANDROID_BUILD.md](docs/ANDROID_BUILD.md)** - Android APK build configuration and deployment
- **[docs/WINDOWS_BUILD.md](docs/WINDOWS_BUILD.md)** - Windows 11 cross-compilation and distribution
- **[docs/WINDOWS_BUILD_ANALYSIS.md](docs/WINDOWS_BUILD_ANALYSIS.md)** - Complete Windows build system analysis
- **[docs/ci/](docs/ci/)** - CI/CD workflow and setup
- **[docs/docker/](docs/docker/)** - Docker usage and configuration
- **[docs/setup/](docs/setup/)** - Setup and dependencies

## Build Targets

Common make targets:

```bash
make build              # Build the application
make test               # Run unit tests
make run-code-quality   # Run static analysis
make run-security-scan  # Run security scanning
make ci                 # Run complete CI pipeline locally
```

## License

See the [LICENSE](LICENSE) file for details.

---

Built with ❤️ for audio book enthusiasts
