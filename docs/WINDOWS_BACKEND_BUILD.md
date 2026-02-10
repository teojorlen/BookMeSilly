# Windows Backend Cross-Compilation Guide

Build the BookMeSilly backend library and tests for Windows 11 using MinGW-w64 cross-compilation.

## Overview

- **Build Time**: ~30 seconds (first build), ~10 seconds (cached)
- **Toolchain**: MinGW-w64 (x86_64-w64-mingw32)
- **Target**: Windows 11 x86_64
- **Output**: Static library + test executable

## Quick Start

```bash
# Build Windows backend
make windows-backend

# Or use the script directly
./scripts/build/windows-backend-build.sh
```

## Output Artifacts

The build produces three files in `output/windows/`:

1. **test_calculator.exe** - Windows test executable (~3.6 MB)
2. **libbackend.a** - Static library for linking (~4 KB)
3. **BUILD_INFO.txt** - Build metadata

## Build Options

### Standard Build
```bash
# Default release build
./scripts/build/windows-backend-build.sh
```

### Build and Run Tests
```bash
# Build and run unit tests with Wine
./scripts/build/windows-backend-build.sh --test

# Or via Make
make windows-backend-test
```

### Debug Build
```bash
# Build with debug symbols
./scripts/build/windows-backend-build.sh --type Debug

# Or via Make
make windows-backend-debug
```

### Clean Build
```bash
# Remove previous artifacts and rebuild
./scripts/build/windows-backend-build.sh --clean

# Or via Make
make windows-backend-clean
```

### Verify Only
```bash
# Build but don't extract binaries
./scripts/build/windows-backend-build.sh --verify
```

### Custom Output Directory
```bash
./scripts/build/windows-backend-build.sh --output /path/to/output
```

## Testing

### On Windows
Copy the executable to a Windows machine and run:
```cmd
test_calculator.exe
```

### On Linux with Wine
```bash
# Install wine (Ubuntu/Debian)
sudo apt-get install wine64

# Run tests
wine output/windows/test_calculator.exe
```

## Using the Library

### Linking in Your Project

**Option 1: Static Linking**
```bash
x86_64-w64-mingw32-g++ -o myapp.exe \
    main.cpp \
    output/windows/libbackend.a \
    -Iinclude \
    -std=c++17 \
    -static-libgcc \
    -static-libstdc++
```

**Option 2: CMake Integration**
```cmake
# In your CMakeLists.txt
add_executable(myapp main.cpp)
target_link_libraries(myapp 
    PRIVATE 
    ${CMAKE_SOURCE_DIR}/output/windows/libbackend.a
)
target_include_directories(myapp 
    PRIVATE 
    ${CMAKE_SOURCE_DIR}/include
)
```

### Example Usage

```cpp
#include "backend/Calculator.h"

int main() {
    backend::Calculator calc;
    double result = calc.add(5, 3);
    return 0;
}
```

## Build Architecture

### Docker Stages

1. **windows-backend-builder**: Main build stage
   - Ubuntu 24.04 base
   - MinGW-w64 toolchain
   - CMake + Ninja build

2. **export**: Extract artifacts
   - Minimal stage for binary export
   - Used with `docker build --target export -o output/`

3. **verify**: Validation stage
   - Runs file checks
   - Displays build info

### Build Process

```
┌──────────────────────────────────────────────────────────┐
│ 1. Install MinGW-w64 Cross-Compiler                     │
│    ├─ x86_64-w64-mingw32-g++                            │
│    ├─ x86_64-w64-mingw32-gcc                            │
│    └─ mingw-w64-tools                                   │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ 2. Generate CMake Toolchain File                        │
│    - Set CMAKE_SYSTEM_NAME = Windows                    │
│    - Configure cross-compiler paths                     │
│    - Set static linking flags                           │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ 3. Configure CMake                                       │
│    cmake -B build-windows \                              │
│          -G Ninja \                                      │
│          -DCMAKE_TOOLCHAIN_FILE=...                      │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ 4. Build with Ninja                                      │
│    - Compile backend library                             │
│    - Build test executable                               │
│    - Link with static runtime                            │
└──────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────┐
│ 5. Extract Artifacts                                     │
│    → output/windows/                                     │
│       ├── test_calculator.exe                            │
│       ├── libbackend.a                                   │
│       └── BUILD_INFO.txt                                 │
└──────────────────────────────────────────────────────────┘
```

## Troubleshooting

### Build Fails with "Docker not available"
- Ensure Docker is installed and running
- Check: `docker info`

### Build Fails with CMake Errors
- Verify CMakeLists.txt has no Qt dependencies
- Check that backend source files exist in `src/backend/`

### Executable Won't Run on Windows
- Ensure target is Windows 11 x86_64
- Try running with compatibility mode
- Check for missing DLLs (should be statically linked)

### Large Executable Size
The 3.6 MB size includes:
- Static C/C++ runtime
- Catch2 test framework
- Debug symbols (in Debug builds)

To reduce size:
```bash
# Build release version (default)
./scripts/build/windows-backend-build.sh

# Strip symbols (on Windows)
strip test_calculator.exe
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make windows-backend` | Build Windows backend (release) |
| `make windows-backend-clean` | Clean and rebuild |
| `make windows-backend-debug` | Build with debug symbols |
| `make windows-backend-verify` | Build and verify only |

## Technical Details

### Cross-Compilation Toolchain
- **Compiler**: x86_64-w64-mingw32-g++
- **Target Triple**: x86_64-w64-mingw32
- **Runtime**: Static (libgcc, libstdc++)

### Build Configuration
- **C++ Standard**: C++17
- **Build System**: CMake 3.10+ with Ninja
- **Dependencies**: Catch2 v3.4.0 (testing)

### Linker Flags
```
-static-libgcc      # Static libgcc
-static-libstdc++   # Static libstdc++
```

## Continuous Integration

Add to GitHub Actions:
```yaml
- name: Build Windows Backend
  run: |
    ./scripts/build/windows-backend-build.sh
    
- name: Upload Windows Artifacts
  uses: actions/upload-artifact@v3
  with:
    name: windows-backend
    path: output/windows/
```

## Related Documentation

- [Architecture](ARCHITECTURE.md) - Project structure
- [CMakeLists.txt](../CMakeLists.txt) - Build configuration
- [Dockerfile.windows-backend](../config/docker/Dockerfile.windows-backend) - Build container
- [windows-backend-build.sh](../scripts/build/windows-backend-build.sh) - Build script

## FAQ

**Q: Can I build a Windows GUI application?**
A: This setup is backend-only. For GUI, you'd need to add a Windows-specific frontend (Win32 API, WinForms, etc.) and link against this library.

**Q: Why MinGW-w64 instead of MSVC?**
A: MinGW-w64 allows cross-compilation from Linux. For native MSVC builds, use Windows + Visual Studio.

**Q: Can I target 32-bit Windows?**
A: Yes, modify the Dockerfile to use `i686-w64-mingw32` toolchain instead of `x86_64-w64-mingw32`.

**Q: How do I add dependencies?**
A: Install them in the Dockerfile's package list and update the toolchain file's `CMAKE_FIND_ROOT_PATH`.

## Support

For issues or questions:
- Check [CONTRIBUTING.md](CONTRIBUTING.md)
- Open an issue on GitHub
- Review build logs in the terminal output
