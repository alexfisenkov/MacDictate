#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-"$ROOT_DIR/build/MacDictate.app"}"
if [[ "$APP_PATH" != /* ]]; then
  APP_PATH="$PWD/$APP_PATH"
fi
RESOURCES_DIR="$APP_PATH/Contents/Resources"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
BIN_DIR="$RESOURCES_DIR/bin"
LIB_DIR="$RESOURCES_DIR/lib"
WHISPER_LIB_DIR="$RESOURCES_DIR/lib/whisper"
GGML_BACKEND_DIR="$RESOURCES_DIR/libexec/ggml-whisper"
if [ ! -d "$WHISPER_LIB_DIR" ]; then
  WHISPER_LIB_DIR="$LIB_DIR"
fi
if [ ! -d "$GGML_BACKEND_DIR" ]; then
  GGML_BACKEND_DIR="$RESOURCES_DIR/libexec/ggml"
fi
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

app_min_version="$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST" 2>/dev/null || true)"
version_greater_than() {
  /usr/bin/python3 - "$1" "$2" <<'PY'
import sys

def parse(value):
    return tuple(int(part) for part in value.split(".") if part.isdigit())

left = parse(sys.argv[1])
right = parse(sys.argv[2])
max_len = max(len(left), len(right))
left += (0,) * (max_len - len(left))
right += (0,) * (max_len - len(right))
sys.exit(0 if left > right else 1)
PY
}

check_deployment_target() {
  local file_path="$1"
  if [ -z "$app_min_version" ]; then
    fail "Unable to read LSMinimumSystemVersion from $INFO_PLIST"
    return
  fi

  local minos
  minos="$(/usr/bin/vtool -show-build "$file_path" 2>/dev/null | /usr/bin/awk '/minos/{print $2; exit}')"
  if [ -n "$minos" ] && version_greater_than "$minos" "$app_min_version"; then
    fail "Bundled Mach-O deployment target is newer than app minimum macOS: $file_path minos=$minos app=$app_min_version"
  fi
}

if ! file "$RUNTIME" | grep -q 'arm64'; then
  fail "Bundled whisper-cli runtime is not arm64: $RUNTIME"
fi

check_macho_file() {
  local file_path="$1"
  check_deployment_target "$file_path"

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

if [ ! -d "$WHISPER_LIB_DIR" ]; then
  fail "Bundled whisper lib directory not found: $WHISPER_LIB_DIR"
else
  while IFS= read -r -d '' macho_file; do
    check_macho_file "$macho_file"
  done < <(find "$WHISPER_LIB_DIR" -type f \( -name "*.dylib" -o -name "*.so" \) -print0)
fi

if [ ! -d "$GGML_BACKEND_DIR" ]; then
  fail "Bundled ggml backend directory not found: $GGML_BACKEND_DIR"
else
  while IFS= read -r -d '' backend; do
    check_macho_file "$backend"
  done < <(find "$GGML_BACKEND_DIR" -type f -name "*.so" -print0)
fi

runtime_stderr="$(mktemp)"
runtime_backend=""
for candidate in \
  "$GGML_BACKEND_DIR/libggml-cpu-apple_m1.so" \
  "$GGML_BACKEND_DIR/libggml-cpu-apple_m2_m3.so" \
  "$GGML_BACKEND_DIR/libggml-cpu-apple_m4.so" \
  "$GGML_BACKEND_DIR/libggml-metal.so" \
  "$GGML_BACKEND_DIR/libggml-blas.so"; do
  if [ -f "$candidate" ]; then
    runtime_backend="$candidate"
    break
  fi
done

if [ -z "$runtime_backend" ]; then
  fail "No bundled ggml backend file found in $GGML_BACKEND_DIR"
fi

if [ -n "$runtime_backend" ] && GGML_BACKEND_PATH="$runtime_backend" "$RUNTIME" --help >/dev/null 2>"$runtime_stderr"; then
  :
fi
if grep -Eiq 'dyld|Library not loaded|image not found|failed to load|no backends are loaded|no usable GPU found' "$runtime_stderr"; then
  fail "Bundled whisper-cli failed to launch cleanly with bundled ggml backend."
  cat "$runtime_stderr" >&2
fi
rm -f "$runtime_stderr"

if [ "$status" -eq 0 ]; then
  echo "Bundled whisper runtime check passed: $RUNTIME"
fi

exit "$status"
