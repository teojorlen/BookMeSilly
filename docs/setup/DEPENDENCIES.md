# BookMeSilly - Dependency Analysis

## Overview
BookMeSilly is a C++ audiobook player built with Qt6. This document outlines all build and runtime dependencies.

## Build Dependencies

### Core Build Tools
| Package | Version | Purpose |
|---------|---------|---------|
| `build-essential` | Latest | GCC/G++ compiler suite with make |
| `cmake` | 3.10+ | Build system generator |
| `ninja-build` | Latest | Fast build system (alternative to make) |
| `git` | Latest | Version control |

### C++ Compiler Support
| Package | Version | Purpose |
|---------|---------|---------|
| `g++` | C++17 capable | C++ compiler (included in build-essential) |
| `gcc` | Latest | C compiler dependency |
| `libstdc++6-dev` | Latest | C++ standard library development files |

### Qt6 Framework (Core)
| Package | Version | Purpose |
|---------|---------|---------|
| `qt6-base-dev` | 6.4+ | Qt6 Core, GUI, Widgets modules |
| `libqt6core6t64` | 6.4+ | Qt6 Core runtime library |
| `libqt6gui6t64` | 6.4+ | Qt6 GUI runtime library |
| `libqt6widgets6t64` | 6.4+ | Qt6 Widgets runtime library |
| `qmake6` | 6.4+ | Qt build tool (alternative to CMake) |

### X11 and Display Libraries
| Package | Version | Purpose |
|---------|---------|---------|
| `libx11-dev` | Latest | X11 protocol client library |
| `libxcb1-dev` | Latest | X11 protocol C binding |
| `libxkbcommon-x11-0` | Latest | XKB keymap support |
| `libxkbcommon-dev` | Latest | XKB development headers |
| `libxcb-keysyms1` | Latest | XCB keyboard symbols |
| `libxcb-render-util0` | Latest | XCB rendering utilities |
| `libxcb-shape0` | Latest | XCB shape extension |
| `libxcb-icccm4` | Latest | XCB ICCCM protocol support |
| `libxcb-image0` | Latest | XCB image utilities |

### Graphics and OpenGL Support
| Package | Version | Purpose |
|---------|---------|---------|
| `libgl-dev` | Latest | OpenGL development headers |
| `libglx-dev` | Latest | GLX protocol support |
| `libopengl-dev` | Latest | OpenGL wrapper development |
| `libvulkan-dev` | Latest | Vulkan SDK (used by modern Qt) |

### Wayland Support (Modern Display Server)
| Package | Version | Purpose |
|---------|---------|---------|
| `libqt6waylandclient6` | 6.4+ | Qt6 Wayland client plugin |
| `libqt6waylandcompositor6` | 6.4+ | Qt6 Wayland compositor |
| `qt6-wayland` | 6.4+ | Qt6 Wayland integration |

### Input Device Support
| Package | Version | Purpose |
|---------|---------|---------|
| `libinput10` | Latest | Input device handling |
| `libinput-bin` | Latest | Input device utilities |
| `libmtdev1t64` | Latest | Multitouch device support |
| `libevdev2` | Latest | Input event device library |
| `libts0t64` | Latest | Touchscreen support |

### Additional System Libraries
| Package | Version | Purpose |
|---------|---------|---------|
| `libpthread-stubs0-dev` | Latest | Thread support |
| `libpcre2-16-0` | Latest | Regular expressions (Qt dependency) |
| `libdouble-conversion3` | Latest | Float conversion (Qt dependency) |
| `libb2-1` | Latest | BLAKE2 hash (Qt dependency) |
| `libproxy1v5` | Latest | Proxy configuration |
| `libwacom-common` | Latest | Wacom device support |
| `libwacom9` | Latest | Wacom device library |
| `libgudev-1.0-0` | Latest | GObject udev bindings |
| `libmd4c0` | Latest | Markdown support |

### Development Tools
| Package | Version | Purpose |
|---------|---------|---------|
| `qt6-base-dev-tools` | 6.4+ | Qt command-line tools (rcc, moc, uic) |
| `qt6-qpa-plugins` | 6.4+ | Qt Platform Abstraction plugins |
| `qt6-gtk-platformtheme` | 6.4+ | GTK platform theme integration |
| `qt6-translations-l10n` | 6.4+ | Internationalization translations |

## Runtime Dependencies (Production)

When running the built application, you need:

### Core Qt Libraries
- `libqt6core6t64` - Qt Core
- `libqt6gui6t64` - Qt GUI
- `libqt6widgets6t64` - Qt Widgets

### System Libraries
- `libstdc++6` - C++ standard library
- `libg lib2.0-0` - GNU C library

### X11/Display (for GUI)
- `libx11-6` - X11 client library
- `libxcb1` - X11 protocol bindings
- `libxkbcommon-x11-0` - XKB support

### Graphics
- `libglx0` - GLX support
- `libopengl0` - OpenGL

### Optional (Wayland Support)
- `libqt6waylandclient6` - Wayland client
- `libqt6waylandcompositor6` - Wayland compositor
- `qt6-wayland` - Wayland plugins

## Platform-Specific Notes

### Ubuntu 24.04 LTS (Recommended)
- **Qt Version**: 6.4.2
- **GCC Version**: 13.3.0
- **CMake Version**: 3.28+
- **Kernel**: 6.8+

All above packages are available in standard Ubuntu repositories.

### Size Estimates
- **Build Packages**: ~500 MB
- **Runtime Libraries**: ~150 MB (compressed), ~500 MB installed
- **Compiled Binary**: ~80-150 KB (stripped)

## Docker Build Stages

### Development Image
- Includes all build tools
- Size: ~2-3 GB
- Used for: Building, testing, development

### Production Image
- Only runtime libraries
- Size: ~800 MB - 1.5 GB
- Used for: Running the application

## Installation Commands

### For Ubuntu 24.04 LTS
```bash
# Update package lists
sudo apt-get update

# Install build tools
sudo apt-get install -y build-essential cmake ninja-build git

# Install Qt6 development
sudo apt-get install -y qt6-base-dev qt6-base-dev-tools

# Install X11 support (already installed with Qt, but explicit)
sudo apt-get install -y libx11-dev libxcb1-dev libxkbcommon-x11-0

# Install all dependencies in one command
sudo apt-get install -y \
  build-essential cmake ninja-build git \
  qt6-base-dev qt6-base-dev-tools \
  libgl-dev libglx-dev libopengl-dev libvulkan-dev \
  libx11-dev libxcb1-dev libxkbcommon-dev \
  libinput-dev libwacom-dev libgudev-1.0-dev
```

## Troubleshooting Missing Dependencies

If CMake fails to find Qt:
```bash
# Qt path might need to be specified
cmake .. -DQt6_DIR=/usr/lib/x86_64-linux-gnu/cmake/Qt6
```

If X11 support is missing:
```bash
# Install XKB headers specifically
sudo apt-get install -y libxkb-dev
```

If Wayland support needed:
```bash
sudo apt-get install -y qt6-wayland wayland-protocols libwayland-dev
```

## Future Enhancement Dependencies

When adding audiobook features, consider:

### Audio Processing
- `libavformat-dev` - Audio format handling
- `libavcodec-dev` - Audio codec support
- `libavutil-dev` - Audio utilities
- `libopus-dev` - Opus codec
- `libvorbis-dev` - Vorbis codec

### Network/Cloud Sync
- `libcurl4-openssl-dev` - HTTP client
- `zlib1g-dev` - Compression

### Database
- `sqlite3` - Local storage
- `sqlite3-dev` - Development headers
