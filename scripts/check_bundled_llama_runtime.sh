#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-"$ROOT_DIR/build/MacDictate.app"}"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
BIN_DIR="$RESOURCES_DIR/bin"
LIB_DIR="$RESOURCES_DIR/lib"
status=0

fail() {
  echo "❌ $*" >&2
  status=1
}

info() {
  echo "ℹ️  $*"
}

if [ ! -d "$APP_PATH" ]; then
  fail "App bundle not found: $APP_PATH"
  exit "$status"
fi

runtime=""
for candidate in "$BIN_DIR/llama-completion" "$BIN_DIR/llama-cli"; do
  if [ -x "$candidate" ]; then
    runtime="$candidate"
    break
  fi
done

if [ -z "$runtime" ]; then
  fail "Bundled llama runtime not found in $BIN_DIR"
  exit "$status"
fi

if ! file "$runtime" | grep -q 'arm64'; then
  fail "Bundled llama runtime is not arm64: $runtime"
fi

check_macho_file() {
  local file_path="$1"

  if ! codesign --verify --strict --verbose=2 "$file_path" >/dev/null 2>&1; then
    fail "Nested Mach-O signature verification failed: $file_path"
  fi

  local deps
  deps="$(otool -L "$file_path")"
  if printf '%s\n' "$deps" | grep -E '/opt/homebrew|/usr/local|/Cellar/' >/dev/null; then
    fail "Bundled Mach-O still references local Homebrew paths: $file_path"
    printf '%s\n' "$deps" >&2
  fi
}

check_macho_file "$runtime"

if [ ! -d "$LIB_DIR" ]; then
  fail "Bundled llama lib directory not found: $LIB_DIR"
else
  while IFS= read -r -d '' dylib; do
    check_macho_file "$dylib"
  done < <(find "$LIB_DIR" -type f -name "*.dylib" -print0)
fi

runtime_stderr="$(mktemp)"
if "$runtime" --help >/dev/null 2>"$runtime_stderr"; then
  :
fi
if grep -Eiq 'dyld|Library not loaded|image not found' "$runtime_stderr"; then
  fail "Bundled llama runtime failed to launch because of a dynamic library error."
  cat "$runtime_stderr" >&2
fi
rm -f "$runtime_stderr"

if [ "$status" -eq 0 ]; then
  echo "Bundled llama runtime check passed: $runtime"
fi

exit "$status"
