#!/bin/bash
set -e

# Run security scan using Grype (open-source vulnerability scanner).
# If Grype isn't installed locally, build in the builder image.

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"

# Colors for output
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No Color

print_header() {
    echo -e "\n${BLUE}===================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}===================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}" >&2
}

print_section() {
    echo -e "\n${YELLOW}→ $1${NC}"
}

REPORT_DIR="$DIR/reports"
mkdir -p "$REPORT_DIR"

IMAGE=bookme-silly:security-scan

print_header "Security Vulnerability Scan"

# Build a production image for scanning if not present
if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  print_section "Building production image for scanning: $IMAGE"
  docker build --target production -t "$IMAGE" -f config/docker/Dockerfile .
fi

if command -v grype >/dev/null 2>&1; then
  print_section "Running Grype (local) against $IMAGE"
  SARIF_OUT="$REPORT_DIR/grype-results.sarif"
  grype "docker:$IMAGE" --output sarif --file "$SARIF_OUT" || true
  print_success "Grype SARIF saved to $SARIF_OUT"
  exit 0
fi

# Fallback: run Grype inside builder image
print_section "Grype not found locally — running inside builder image..."
if ! docker image inspect bookme-silly:ci-builder >/dev/null 2>&1; then
  docker build --target builder -t bookme-silly:ci-builder -f config/docker/Dockerfile .
fi

SARIF_OUT="/build/reports/grype-results.sarif"
docker run --rm -v "$DIR":/build -v /var/run/docker.sock:/var/run/docker.sock bookme-silly:ci-builder \
  bash -c "grype 'docker:$IMAGE' --output sarif --file $SARIF_OUT || true"

print_success "Grype SARIF saved to $DIR/reports/grype-results.sarif"
exit 0
