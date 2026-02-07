#!/bin/bash
set -e

# Run static code analysis (cppcheck). If cppcheck is not available locally,
# build the builder image and run cppcheck inside it (unless --no-build).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"

usage() {
  echo "Usage: $0 [--no-build]"
  echo "  --no-build   Don't attempt to build the builder image; require local cppcheck"
  exit 1
}

NO_BUILD=0
if [ "$1" = "--no-build" ]; then
  NO_BUILD=1
elif [ -n "$1" ]; then
  usage
fi

if command -v cppcheck >/dev/null 2>&1; then
  echo "Running cppcheck locally..."
  REPORT_DIR="$DIR/reports"
  mkdir -p "$REPORT_DIR"
  XML_OUT="$REPORT_DIR/cppcheck.xml"
  SARIF_OUT="$REPORT_DIR/cppcheck.sarif"
  cppcheck --enable=all --suppress=missingIncludeSystem -Iinclude -Dslots -Dsignals -Demit -DQ_OBJECT --suppressions-list=config/cppcheck/suppressions.txt --xml-version=2 src 2> "$XML_OUT" || true
  if command -v python3 >/dev/null 2>&1; then
    echo "Converting cppcheck XML to SARIF..."
    python3 scripts/analysis/convert_cppcheck_xml_to_sarif.py "$XML_OUT" "$SARIF_OUT" || true
    echo "SARIF saved to $SARIF_OUT"
  else
    echo "Python3 not found; SARIF conversion skipped. XML at $XML_OUT"
  fi
  exit 0
fi

if [ $NO_BUILD -eq 1 ]; then
  echo "cppcheck not installed locally and --no-build specified. Aborting."
  exit 2
fi

# Local cppcheck not found — build/use container and produce reports
echo "Local cppcheck not found — building builder image and running inside container..."
# Build builder image if not present
if ! docker image inspect bookme-silly:ci-builder >/dev/null 2>&1; then
  docker build --target builder -t bookme-silly:ci-builder -f config/docker/Dockerfile .
fi

echo "Running cppcheck inside builder image..."
REPORT_DIR="$DIR/reports"
mkdir -p "$REPORT_DIR"
XML_OUT="/build/reports/cppcheck.xml"
SARIF_OUT="/build/reports/cppcheck.sarif"
docker run --rm -v "$DIR":/build bookme-silly:ci-builder \
  bash -c "mkdir -p /build/reports && cppcheck --enable=all --suppress=missingIncludeSystem -I/build/include -Dslots -Dsignals -Demit -DQ_OBJECT --suppressions-list=/build/config/cppcheck/suppressions.txt --xml-version=2 /build/src 2> $XML_OUT || true && python3 /build/scripts/analysis/convert_cppcheck_xml_to_sarif.py $XML_OUT $SARIF_OUT || true"

echo "Reports available in $DIR/reports/"
exit 0
