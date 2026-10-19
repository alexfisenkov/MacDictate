#!/usr/bin/env bash
set -euo pipefail

DEPLOYMENT_TARGET="${MACDICTATE_RUNTIME_DEPLOYMENT_TARGET:-11.0}"
SRC_ROOT="${MACDICTATE_RUNTIME_SRC_ROOT:-$HOME/.macdictate/runtime-src}"
BUILD_ROOT="${MACDICTATE_RUNTIME_BUILD_ROOT:-$HOME/.macdictate/runtime-build}"
LLAMA_REF="${MACDICTATE_LLAMA_CPP_REF:-master}"
WHISPER_REF="${MACDICTATE_WHISPER_CPP_REF:-master}"
REFRESH_SOURCES="${MACDICTATE_REFRESH_RUNTIME_SOURCES:-false}"

download_source() {
  local name="$1"
  local repo="$2"
  local ref="$3"
  local destination="$4"
  local archive_path
  archive_path="$(mktemp "/tmp/macdictate-${name}.XXXXXX.tar.gz")"

  echo "⬇️  Downloading ${repo}@${ref}..."
  curl -fL "https://codeload.github.com/${repo}/tar.gz/refs/heads/${ref}" -o "$archive_path"
  rm -rf "$destination"
  mkdir -p "$destination"
  tar -xzf "$archive_path" -C "$destination" --strip-components 1
  rm -f "$archive_path"
}

ensure_source() {
  local name="$1"
  local repo="$2"
  local ref="$3"
  local destination="$4"

  if [ "$REFRESH_SOURCES" = "true" ] || [ "$REFRESH_SOURCES" = "1" ] || [ ! -f "$destination/CMakeLists.txt" ]; then
    download_source "$name" "$repo" "$ref" "$destination"
  else
    echo "ℹ️  Using existing source: $destination"
  fi
}

validate_minos() {
  local file_path="$1"
  local minos
  minos="$(vtool -show-build "$file_path" 2>/dev/null | awk '/minos/{print $2; exit}')"
  if [ "$minos" != "$DEPLOYMENT_TARGET" ]; then
    echo "❌ Unexpected deployment target for $file_path: minos=$minos expected=$DEPLOYMENT_TARGET" >&2
    exit 1
  fi
}

validate_no_homebrew_refs() {
  local file_path="$1"
  if otool -L "$file_path" | grep -E '/opt/homebrew|/usr/local|/Cellar/' >/dev/null; then
    echo "❌ Runtime still references local Homebrew paths: $file_path" >&2
    otool -L "$file_path" >&2
    exit 1
  fi
}

mkdir -p "$SRC_ROOT" "$BUILD_ROOT"
ensure_source "llama" "ggerganov/llama.cpp" "$LLAMA_REF" "$SRC_ROOT/llama.cpp"
ensure_source "whisper" "ggerganov/whisper.cpp" "$WHISPER_REF" "$SRC_ROOT/whisper.cpp"

COMMON_CMAKE=(
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
  -DCMAKE_OSX_ARCHITECTURES=arm64
  -DBUILD_SHARED_LIBS=ON
  -DGGML_BACKEND_DL=ON
  -DGGML_CPU_ALL_VARIANTS=ON
  -DGGML_NATIVE=OFF
  -DGGML_METAL=ON
  -DGGML_ACCELERATE=ON
  -DGGML_OPENMP=OFF
  -DGGML_BLAS=OFF
  -DGGML_CCACHE=OFF
)

rm -rf "$BUILD_ROOT/llama.cpp" "$BUILD_ROOT/whisper.cpp"

cmake -S "$SRC_ROOT/llama.cpp" -B "$BUILD_ROOT/llama.cpp" \
  "${COMMON_CMAKE[@]}" \
  -DLLAMA_OPENSSL=OFF \
  -DLLAMA_BUILD_TESTS=OFF \
  -DLLAMA_BUILD_EXAMPLES=OFF \
  -DLLAMA_BUILD_SERVER=OFF \
  -DLLAMA_BUILD_TOOLS=ON
cmake --build "$BUILD_ROOT/llama.cpp" --target llama-completion -j "$(sysctl -n hw.ncpu)"

cmake -S "$SRC_ROOT/whisper.cpp" -B "$BUILD_ROOT/whisper.cpp" \
  "${COMMON_CMAKE[@]}" \
  -DWHISPER_BUILD_TESTS=OFF \
  -DWHISPER_BUILD_EXAMPLES=ON \
  -DWHISPER_BUILD_SERVER=OFF \
  -DWHISPER_CURL=OFF \
  -DWHISPER_SDL2=OFF
cmake --build "$BUILD_ROOT/whisper.cpp" --target whisper-cli -j "$(sysctl -n hw.ncpu)"

while IFS= read -r -d '' macho_file; do
  validate_minos "$macho_file"
  validate_no_homebrew_refs "$macho_file"
done < <(find "$BUILD_ROOT/llama.cpp/bin" "$BUILD_ROOT/whisper.cpp/bin" "$BUILD_ROOT/whisper.cpp/src" "$BUILD_ROOT/whisper.cpp/ggml/src" \
  -type f \( -name "llama-completion" -o -name "whisper-cli" -o -name "*.dylib" -o -name "*.so" \) -print0)

cat <<EOF
✅ Clean runtimes built for macOS ${DEPLOYMENT_TARGET}

Use for release-style build:

MACDICTATE_LLAMA_RUNTIME_PATH="$BUILD_ROOT/llama.cpp/bin/llama-completion" \\
MACDICTATE_LLAMA_GGML_BACKEND_PATH="$BUILD_ROOT/llama.cpp/bin" \\
MACDICTATE_WHISPER_RUNTIME_PATH="$BUILD_ROOT/whisper.cpp/bin/whisper-cli" \\
MACDICTATE_WHISPER_GGML_BACKEND_PATH="$BUILD_ROOT/whisper.cpp/bin" \\
./build.sh
EOF
