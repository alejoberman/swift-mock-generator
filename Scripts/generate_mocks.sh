#!/bin/bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  generate_mocks.sh --sources PATH --output PATH [options]

Downloads (when needed), builds, and runs SwiftMockGenerator's `mockgen` executable.

Required:
  --sources PATH          Swift source file or directory containing protocols to mock
  --output PATH           Directory for generated Mock*.swift files (must belong to test target)

Options:
  --repository URL        Git repository URL
                          (default: $SWIFT_MOCK_GENERATOR_REPOSITORY or the official project URL)
  --ref REF               Git branch, tag, or commit to build
                          (default: $SWIFT_MOCK_GENERATOR_REF or main; pin a tag/commit for CI)
  --generator-root PATH   Use an existing checkout instead of downloading one
  --cache-dir PATH        Checkout/cache directory (default: $SWIFT_MOCK_GENERATOR_CACHE
                          or ~/Library/Caches/SwiftMockGenerator on macOS)
  --clean                 Delete top-level Mock*.swift files in the output directory first
  --scope used --tests PATH generates only mocks referenced by the test target.
  -h, --help              Show this help

Environment equivalents:
  SWIFT_MOCK_GENERATOR_REPOSITORY, SWIFT_MOCK_GENERATOR_REF,
  SWIFT_MOCK_GENERATOR_PATH, SWIFT_MOCK_GENERATOR_CACHE
USAGE
}

CALLER_DIR="$(pwd)"
REPOSITORY="${SWIFT_MOCK_GENERATOR_REPOSITORY:-https://github.com/alejoberman/SwiftMockGenerator.git}"
REF="${SWIFT_MOCK_GENERATOR_REF:-main}"
GENERATOR_ROOT="${SWIFT_MOCK_GENERATOR_PATH:-}"
CACHE_DIR="${SWIFT_MOCK_GENERATOR_CACHE:-${HOME}/Library/Caches/SwiftMockGenerator}"
SOURCES=""
OUTPUT=""
CLEAN=0
SCOPE="all"
TESTS=""
MODULE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repository) [[ $# -ge 2 ]] || { echo "Missing value for --repository" >&2; exit 2; }; REPOSITORY="$2"; shift 2 ;;
    --ref) [[ $# -ge 2 ]] || { echo "Missing value for --ref" >&2; exit 2; }; REF="$2"; shift 2 ;;
    --generator-root) [[ $# -ge 2 ]] || { echo "Missing value for --generator-root" >&2; exit 2; }; GENERATOR_ROOT="$2"; shift 2 ;;
    --cache-dir) [[ $# -ge 2 ]] || { echo "Missing value for --cache-dir" >&2; exit 2; }; CACHE_DIR="$2"; shift 2 ;;
    --sources) [[ $# -ge 2 ]] || { echo "Missing value for --sources" >&2; exit 2; }; SOURCES="$2"; shift 2 ;;
    --output) [[ $# -ge 2 ]] || { echo "Missing value for --output" >&2; exit 2; }; OUTPUT="$2"; shift 2 ;;
    --scope) SCOPE="$2"; shift 2 ;;
    --tests) TESTS="$2"; shift 2 ;;
    --module) MODULE="$2"; shift 2 ;;
    --clean) CLEAN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

[[ -n "$SOURCES" ]] || { echo "Missing --sources." >&2; usage >&2; exit 2; }
[[ -n "$OUTPUT" ]] || { echo "Missing --output." >&2; usage >&2; exit 2; }
[[ -e "$SOURCES" ]] || { echo "Source path not found: $SOURCES" >&2; exit 2; }
[[ "$SCOPE" == "all" || "$SCOPE" == "used" ]] || { echo "--scope must be all or used." >&2; exit 2; }
if [[ "$SCOPE" == "used" ]]; then
  [[ -n "$TESTS" && -d "$TESTS" ]] || { echo "--scope used requires --tests pointing to a directory." >&2; exit 2; }
fi
command -v git >/dev/null 2>&1 || { echo "git is required to download SwiftMockGenerator." >&2; exit 1; }
command -v xcrun --sdk macosx swift >/dev/null 2>&1 || { echo "Swift 6 toolchain (swift) is required to build SwiftMockGenerator." >&2; exit 1; }

if [[ -z "$GENERATOR_ROOT" ]]; then
  mkdir -p "$CACHE_DIR"
  GENERATOR_ROOT="$CACHE_DIR/checkout"
  if [[ ! -d "$GENERATOR_ROOT/.git" ]]; then
    echo "Cloning SwiftMockGenerator ($REF) into $GENERATOR_ROOT"
    rm -rf "$GENERATOR_ROOT"
    git clone --filter=blob:none "$REPOSITORY" "$GENERATOR_ROOT"
  fi

  # Fetch the requested ref and check it out detached so a pinned tag/commit is reproducible.
  git -C "$GENERATOR_ROOT" fetch --tags origin "$REF"
  git -C "$GENERATOR_ROOT" checkout --detach FETCH_HEAD
else
  [[ -d "$GENERATOR_ROOT" ]] || { echo "Generator checkout not found: $GENERATOR_ROOT" >&2; exit 2; }
fi

GENERATOR_ROOT="$(cd "$GENERATOR_ROOT" && pwd)"
[[ -f "$GENERATOR_ROOT/Package.swift" ]] || { echo "Not a Swift package: $GENERATOR_ROOT" >&2; exit 2; }

# Normalize input/output paths before changing into the generator checkout.
if [[ "$SOURCES" != /* ]]; then SOURCES="$CALLER_DIR/$SOURCES"; fi
if [[ "$OUTPUT" != /* ]]; then OUTPUT="$CALLER_DIR/$OUTPUT"; fi
[[ -e "$SOURCES" ]] || { echo "Source path not found: $SOURCES" >&2; exit 2; }
mkdir -p "$OUTPUT"
OUTPUT="$(cd "$OUTPUT" && pwd)"

if [[ "$CLEAN" -eq 1 ]]; then
  find "$OUTPUT" -maxdepth 1 -type f -name 'Mock*.swift' -delete
fi

cd "$GENERATOR_ROOT"
echo "Building mockgen from $GENERATOR_ROOT"
xcrun --sdk macosx swift build -c release --product mockgen
MOCKGEN="$GENERATOR_ROOT/.build/release/mockgen"
[[ -x "$MOCKGEN" ]] || { echo "mockgen executable was not produced: $MOCKGEN" >&2; exit 1; }

echo "Generating mocks from $SOURCES into $OUTPUT"
if [[ -n "$TESTS" ]]; then
  "$MOCKGEN" "$SOURCES" "$OUTPUT" --scope "$SCOPE" --tests "$TESTS" --module "$MODULE"
else
  "$MOCKGEN" "$SOURCES" "$OUTPUT" --scope "$SCOPE" --module "$MODULE"
fi
echo "Mock generation complete. Ensure $OUTPUT is included in the test target's Compile Sources."
