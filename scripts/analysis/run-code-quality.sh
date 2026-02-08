#!/bin/bash
set -e

# Run static code analysis (cppcheck for C++, shellcheck for shell scripts, pylint for Python).
# If tools are not available locally, build the builder image and run inside it (unless --no-build).

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$DIR"

usage() {
  echo "Usage: $0 [--no-build]"
  echo "  --no-build   Don't attempt to build the builder image; require local tools"
  echo ""
  echo "Analyzes:"
  echo "  - C++ code with cppcheck"
  echo "  - Shell scripts with shellcheck"
  echo "  - Python files with pylint"
  exit 1
}

NO_BUILD=0
if [ "$1" = "--no-build" ]; then
  NO_BUILD=1
elif [ -n "$1" ]; then
  usage
fi

if command -v cppcheck >/dev/null 2>&1 && command -v shellcheck >/dev/null 2>&1 && command -v pylint >/dev/null 2>&1; then
  echo "Running cppcheck, shellcheck, and pylint locally..."
  REPORT_DIR="$DIR/reports"
  mkdir -p "$REPORT_DIR"
  
  # Run cppcheck
  echo "Running cppcheck..."
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
  
  # Run shellcheck
  echo "Running shellcheck on shell scripts..."
  SHELLCHECK_OUT="$REPORT_DIR/shellcheck.txt"
  if find scripts -type f -name "*.sh" | grep -q .; then
    shellcheck -f gcc scripts/**/*.sh > "$SHELLCHECK_OUT" 2>&1 || true
    if [ -s "$SHELLCHECK_OUT" ]; then
      echo "ShellCheck found issues (see $SHELLCHECK_OUT):"
      cat "$SHELLCHECK_OUT"
    else
      echo "ShellCheck: All scripts passed"
    fi
  else
    echo "No shell scripts found in scripts directory"
  fi
  
  # Run pylint
  echo "Running pylint on Python files..."
  PYLINT_OUT="$REPORT_DIR/pylint.txt"
  if find scripts -type f -name "*.py" | grep -q .; then
    pylint --exit-zero --output-format=parseable scripts/**/*.py > "$PYLINT_OUT" 2>&1 || true
    if [ -s "$PYLINT_OUT" ]; then
      echo "Pylint found issues (see $PYLINT_OUT):"
      cat "$PYLINT_OUT"
    else
      echo "Pylint: All Python files passed"
    fi
  else
    echo "No Python files found in scripts directory"
  fi
  
  exit 0
fi

if [ $NO_BUILD -eq 1 ]; then
  echo "cppcheck, shellcheck, or pylint not installed locally and --no-build specified. Aborting."
  exit 2
fi

# Local tools not found — build/use container and produce reports
echo "Local analysis tools not found — building builder image and running inside container..."
# Build builder image if not present
if ! docker image inspect bookme-silly:ci-builder >/dev/null 2>&1; then
  docker build --target builder -t bookme-silly:ci-builder -f config/docker/Dockerfile .
fi

echo "Running code quality analysis inside builder image..."
REPORT_DIR="$DIR/reports"
mkdir -p "$REPORT_DIR"

# Run cppcheck in Docker
echo "Running cppcheck..."
XML_OUT="/build/reports/cppcheck.xml"
SARIF_OUT="/build/reports/cppcheck.sarif"
docker run --rm -v "$DIR":/build bookme-silly:ci-builder \
  bash -c "mkdir -p /build/reports && cppcheck --enable=all --suppress=missingIncludeSystem -I/build/include -Dslots -Dsignals -Demit -DQ_OBJECT --suppressions-list=/build/config/cppcheck/suppressions.txt --xml-version=2 /build/src 2> $XML_OUT || true && python3 /build/scripts/analysis/convert_cppcheck_xml_to_sarif.py $XML_OUT $SARIF_OUT || true"

# Run shellcheck in Docker
echo "Running shellcheck on shell scripts..."
SHELLCHECK_OUT="/build/reports/shellcheck.txt"
docker run --rm -v "$DIR":/build bookme-silly:ci-builder \
  bash -c "if find /build/scripts -type f -name '*.sh' | grep -q .; then shellcheck -f gcc /build/scripts/**/*.sh > $SHELLCHECK_OUT 2>&1 || true && ([ -s $SHELLCHECK_OUT ] && (echo 'ShellCheck found issues:' && cat $SHELLCHECK_OUT) || echo 'ShellCheck: All scripts passed'); else echo 'No shell scripts found'; fi"

# Run pylint in Docker
echo "Running pylint on Python files..."
PYLINT_OUT="/build/reports/pylint.txt"
docker run --rm -v "$DIR":/build bookme-silly:ci-builder \
  bash -c "if find /build/scripts -type f -name '*.py' | grep -q .; then pylint --exit-zero --output-format=parseable /build/scripts/**/*.py > $PYLINT_OUT 2>&1 || true && ([ -s $PYLINT_OUT ] && (echo 'Pylint found issues:' && cat $PYLINT_OUT) || echo 'Pylint: All Python files passed'); else echo 'No Python files found'; fi"

echo "Reports available in $DIR/reports/"
exit 0
