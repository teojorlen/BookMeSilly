# BookMeSilly Architecture

## Project Overview
BookMeSilly is an open source audio book player with high performance and cross-platform support. It aims to synchronize library and play status between devices.

## Directory Structure

The project is organized by concern for better maintainability and scalability:

```
BookMeSilly/
├── docs/                          # Documentation
│   ├── ci/                        # CI/CD documentation
│   │   ├── CI.md                  # CI workflow details
│   │   └── CI_SETUP.md            # CI setup instructions
│   ├── docker/                    # Docker-related documentation
│   │   ├── DOCKER.md              # Docker setup guide
│   │   └── DOCKER_SUMMARY.md      # Docker build summary
│   └── setup/                     # Setup documentation
│       └── DEPENDENCIES.md        # Project dependencies
│
├── src/                           # Source code
│   ├── main.cpp                   # Application entry point
│   ├── backend/                   # Backend library
│   │   └── Calculator.cpp         # Business logic
│   └── frontend/                  # Frontend library
│
├── include/                       # Header files
│   ├── backend/                   # Backend headers
│   └── frontend/                  # Frontend headers
│
├── config/                        # Configuration files
│   ├── cppcheck/                  # Static analysis configuration
│   │   ├── .cppcheckrc            # Cppcheck configuration
│   │   └── suppressions.txt       # Cppcheck suppressions
│   ├── cmake/                     # CMake configuration (reserved)
│   └── docker/                    # Docker configuration
│       ├── Dockerfile            # Production & builder multi-stage
│       ├── Dockerfile.slim       # Slim production image
│       ├── docker-compose.yml    # Development compose
│       └── docker-compose.ci.yml # CI compose
│
├── scripts/                       # Automation scripts
│   ├── ci/                        # CI pipeline scripts
│   │   └── ci-test.sh             # Local CI test runner
│   ├── analysis/                  # Code quality scripts
│   │   ├── run-code-quality.sh    # Run cppcheck analysis
│   │   ├── run-security-scan.sh   # Run vulnerability scan
│   │   └── convert_cppcheck_xml_to_sarif.py # XML to SARIF converter
│   └── dev/                       # Development scripts (reserved)
│
├── tests/                         # Test suite
│   ├── unit/                      # Unit tests
│   │   ├── backend/               # Backend unit tests
│   │   │   └── test_calculator.cpp
│   │   └── frontend/              # Frontend unit tests (reserved)
│   └── integration/               # Integration tests (reserved)
│
├── assets/                        # Static assets
│   ├── icons/                     # Application icons
│   ├── images/                    # Images and screenshots
│   └── resources/                 # Resources (QRC files, etc.)
│
├── build/                         # CMake build output (generated)
├── CMakeLists.txt                 # Main CMake configuration
├── Makefile                       # Convenience build targets
├── .github/workflows/             # GitHub Actions workflows
├── .gitignore                     # Git ignore file
└── README.md                      # Project README
```

## Core Components

### Backend
Located in `src/backend/` and `include/backend/`, contains the business logic and core functionality:
- **Calculator**: Mathematical operations for audio processing

### Frontend
Located in `src/frontend/` and `include/frontend/`, contains the UI components:
- Built with Qt6 (Gui, Widgets, Core)
- Cross-platform support

### Testing
Located in `tests/`, using Catch2 framework:
- Unit tests verify business logic in isolation
- Integration tests (reserved for future expansion)

## Build System

### CMake
- **Minimum version**: 3.10
- **Standard**: C++17
- **Package management**: FetchContent for Catch2
- **Configuration**: `CMakeLists.txt` at project root

### Docker
Multi-stage builds for optimal production images:
1. **Builder Stage**: Includes all development tools, CMake, Qt6, cppcheck
2. **Production Stage**: Slim runtime with only necessary libraries
3. **Slim Stage**: Minimal footprint for resource-constrained environments

## Code Quality

### Static Analysis
- **Tool**: cppcheck
- **Configuration**: `config/cppcheck/.cppcheckrc`
- **Suppressions**: Pattern-based in `config/cppcheck/suppressions.txt`
- **Inline suppressions**: Comments in source files for specific issues

### Security Scanning
- **Tool**: grype (vulnerability scanner)
- **Reports**: SARIF format for GitHub integration

## CI/CD Pipeline

### GitHub Actions
Located in `.github/workflows/`:

**ci.yml** - Code integration checks:
- Docker image builds (builder, production, slim)
- Unit test execution
- Static code analysis with cppcheck
- Security vulnerability scanning with grype
- SARIF report generation

**main.yml** - Production deployment:
- Same checks as ci.yml
- Push images to registry (when configured)

### Local CI Testing
Run `./scripts/ci/ci-test.sh` to verify the entire pipeline locally before pushing.

## Development Workflow

### Prerequisites
- Docker (for containerized builds)
- CMake 3.10+
- C++17 compatible compiler

### Local Development
1. **Build**: `make build` or `docker build --target builder`
2. **Test**: `make test` or `./scripts/ci/ci-test.sh`
3. **Code Quality**: `make run-code-quality`
4. **Security Scan**: `make run-security-scan`

### Configuration Files
- **CMakeLists.txt**: Build configuration and dependencies
- **config/docker/Dockerfile**: Container specifications
- **config/docker/docker-compose.yml**: Development environment
- **config/cppcheck/.cppcheckrc**: Static analysis rules

## File Organization Rationale

### By Concern
- **docs/**: All project documentation (setup, deployment, CI)
- **config/**: Configuration and environment specifications
- **scripts/**: Automation and tooling for development and CI
- **tests/**: All testing code separated from production source
- **assets/**: Static resources (icons, images)

### Benefits
- Clear separation of responsibilities
- Easier to locate and maintain files
- Scalable structure for team growth
- Simplified onboarding for new contributors
- Better CI/CD integration and reproducibility

## Dependencies

See [docs/setup/DEPENDENCIES.md](./setup/DEPENDENCIES.md) for detailed dependency information.

### Key Dependencies
- **Qt6**: GUI framework (Gui, Widgets, Core modules)
- **Catch2**: Testing framework
- **cppcheck**: Static analysis
- **grype**: Security vulnerability scanning

## Next Steps for Development

1. Implement core audio playback functionality
2. Expand test coverage for all modules
3. Add frontend UI components
4. Implement cloud synchronization
5. Add multi-device support

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for contribution guidelines.
