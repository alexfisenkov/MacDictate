#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-"$ROOT_DIR/build/MacDictate.app"}"
if [[ "$APP_PATH" != /* ]]; then
  APP_PATH="$PWD/$APP_PATH"
fi
RESOURCES_DIR="$APP_PATH/Contents/Resources"
BIN_DIR="$RESOURCES_DIR/bin"
LIB_DIR="$RESOURCES_DIR/lib"
GGML_BACKEND_DIR="$RESOURCES_DIR/libexec/ggml"
RUNTIME="$BIN_DIR/whisper-cli"
status=0

fail() {
  echo "❌ $*" >&2
  status=1
}

if [ ! -d "$APP_PATH" ]; then
  fail "App bundle not found: $APP_PATH"
  exit "$status"
fi

if [ ! -x "$RUNTIME" ]; then
  fail "Bundled whisper-cli runtime not found in $BIN_DIR"
  exit "$status"
fi

if ! file "$RUNTIME" | grep -q 'arm64'; then
  fail "Bundled whisper-cli runtime is not arm64: $RUNTIME"
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

check_macho_file "$RUNTIME"

if [ ! -d "$LIB_DIR" ]; then
  fail "Bundled lib directory not found: $LIB_DIR"
else
  while IFS= read -r -d '' macho_file; do
    check_macho_file "$macho_file"
  done < <(find "$LIB_DIR" -type f \( -name "*.dylib" -o -name "*.so" \) -print0)
fi

if [ ! -d "$GGML_BACKEND_DIR" ]; then
  fail "Bundled ggml backend directory not found: $GGML_BACKEND_DIR"
else
  while IFS= read -r -d '' backend; do
    check_macho_file "$backend"
  done < <(find "$GGML_BACKEND_DIR" -type f -name "*.so" -print0)
fi

runtime_stderr="$(mktemp)"
if GGML_BACKEND_PATH="$GGML_BACKEND_DIR" "$RUNTIME" --help >/dev/null 2>"$runtime_stderr"; then
  :
fi
if grep -Eiq 'dyld|Library not loaded|image not found' "$runtime_stderr"; then
  fail "Bundled whisper-cli failed to launch because of a dynamic library error."
  cat "$runtime_stderr" >&2
fi
rm -f "$runtime_stderr"

if [ "$status" -eq 0 ]; then
  echo "Bundled whisper runtime check passed: $RUNTIME"
fi

exit "$status"
