#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$PROJECT_DIR"

echo "🚀 Начинаем сборку 100% Native macOS приложения MacDictate (Swift)..."

APP_NAME="MacDictate.app"
BUILD_DIR="$PROJECT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
LLAMA_BIN_DIR="$RESOURCES_DIR/bin"
LLAMA_LIB_DIR="$RESOURCES_DIR/lib"
BUNDLE_LLAMA_RUNTIME="${MACDICTATE_BUNDLE_LLAMA_RUNTIME:-required}"
LLAMA_RUNTIME_SOURCE="${MACDICTATE_LLAMA_RUNTIME_PATH:-}"
BUNDLE_WHISPER_RUNTIME="${MACDICTATE_BUNDLE_WHISPER_RUNTIME:-required}"
WHISPER_RUNTIME_SOURCE="${MACDICTATE_WHISPER_RUNTIME_PATH:-}"
GGML_BACKEND_SOURCE="${MACDICTATE_GGML_BACKEND_PATH:-}"
SIGN_IDENTITY="${MACDICTATE_SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}"
SIGN_IDENTITY="${SIGN_IDENTITY:-"-"}"
SIGN_MODE="ad-hoc"
if [ "$SIGN_IDENTITY" != "-" ]; then
    SIGN_MODE="developer-id"
fi
DEFAULT_ENTITLEMENTS="$PROJECT_DIR/assets/MacDictate.entitlements"
SIGN_ENTITLEMENTS="${MACDICTATE_CODESIGN_ENTITLEMENTS:-}"
NOTARY_PROFILE="${MACDICTATE_NOTARY_PROFILE:-}"
NOTARIZE_MODE="${MACDICTATE_NOTARIZE:-auto}"
DMG_SRC_PARENT=""
SIGNED_APP_PARENT=""
SIGNED_APP_DIR=""

cleanup_build_temp() {
    if [ -n "$DMG_SRC_PARENT" ] && [ -d "$DMG_SRC_PARENT" ]; then
        rm -rf "$DMG_SRC_PARENT"
    fi
    if [ -n "$SIGNED_APP_PARENT" ] && [ -d "$SIGNED_APP_PARENT" ]; then
        rm -rf "$SIGNED_APP_PARENT"
    fi
}
trap cleanup_build_temp EXIT

if [ "$SIGN_MODE" = "developer-id" ]; then
    if [ -z "$SIGN_ENTITLEMENTS" ] && [ -f "$DEFAULT_ENTITLEMENTS" ]; then
        SIGN_ENTITLEMENTS="$DEFAULT_ENTITLEMENTS"
    fi

    if ! security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
        echo "❌ Signing identity not found in Keychain: $SIGN_IDENTITY" >&2
        echo "   Install a Developer ID Application certificate or set MACDICTATE_SIGN_IDENTITY correctly." >&2
        exit 1
    fi

    if [ -n "$SIGN_ENTITLEMENTS" ] && [ ! -f "$SIGN_ENTITLEMENTS" ]; then
        echo "❌ Entitlements file not found: $SIGN_ENTITLEMENTS" >&2
        exit 1
    fi
fi

# 1. Очистка и создание структуры
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$LLAMA_BIN_DIR"
mkdir -p "$LLAMA_LIB_DIR"

# 2. Копирование Info.plist
cp "$PROJECT_DIR/assets/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$PROJECT_DIR/assets/mic_menubar.png" "$RESOURCES_DIR/mic_menubar.png"
cp "$PROJECT_DIR/assets/mic_menubar@2x.png" "$RESOURCES_DIR/mic_menubar@2x.png"

# 3. Компиляция Swift-файлов
echo "📦 Компиляция Swift-кода (arm64)... это займет пару секунд!"
SWIFT_FILES=()
while IFS= read -r file; do
  SWIFT_FILES+=("$file")
done < <(find "$PROJECT_DIR/src" -name "*.swift" | sort)

swiftc -O -target arm64-apple-macosx11.0 \
    "${SWIFT_FILES[@]}" \
    -o "$MACOS_DIR/MacDictate"

# 4. Bundled runtime для второй локальной модели
bundle_llama_runtime() {
    case "$BUNDLE_LLAMA_RUNTIME" in
        0|false|FALSE|no|NO)
            echo "ℹ️  Bundled llama.cpp runtime skipped by MACDICTATE_BUNDLE_LLAMA_RUNTIME=$BUNDLE_LLAMA_RUNTIME"
            return 0
            ;;
        auto|required|1|true|TRUE|yes|YES)
            ;;
        *)
            echo "❌ Unsupported MACDICTATE_BUNDLE_LLAMA_RUNTIME value: $BUNDLE_LLAMA_RUNTIME" >&2
            echo "   Use required, auto, true, or false." >&2
            exit 1
            ;;
    esac

    echo "🧠 Упаковка llama.cpp runtime для второй нейросети..."
    local bundle_args=(--resources "$RESOURCES_DIR")
    if [ -n "$LLAMA_RUNTIME_SOURCE" ]; then
        bundle_args+=(--runtime "$LLAMA_RUNTIME_SOURCE")
    fi

    if "$PROJECT_DIR/scripts/bundle_llama_runtime.py" "${bundle_args[@]}"; then
        return 0
    fi

    if [ "$BUNDLE_LLAMA_RUNTIME" = "auto" ]; then
        echo "⚠️  llama.cpp runtime не найден; сборка продолжится без bundled text-improvement runtime." >&2
        return 0
    fi

    echo "❌ llama.cpp runtime is required for this build." >&2
    echo "   Install llama.cpp locally or set MACDICTATE_BUNDLE_LLAMA_RUNTIME=false for a developer-only build." >&2
    exit 1
}

bundle_llama_runtime

bundle_whisper_runtime() {
    case "$BUNDLE_WHISPER_RUNTIME" in
        0|false|FALSE|no|NO)
            echo "ℹ️  Bundled whisper.cpp runtime skipped by MACDICTATE_BUNDLE_WHISPER_RUNTIME=$BUNDLE_WHISPER_RUNTIME"
            return 0
            ;;
        auto|required|1|true|TRUE|yes|YES)
            ;;
        *)
            echo "❌ Unsupported MACDICTATE_BUNDLE_WHISPER_RUNTIME value: $BUNDLE_WHISPER_RUNTIME" >&2
            echo "   Use required, auto, true, or false." >&2
            exit 1
            ;;
    esac

    echo "🎙️  Упаковка whisper.cpp runtime для первой нейросети..."
    local bundle_args=(--resources "$RESOURCES_DIR")
    if [ -n "$WHISPER_RUNTIME_SOURCE" ]; then
        bundle_args+=(--runtime "$WHISPER_RUNTIME_SOURCE")
    fi
    if [ -n "$GGML_BACKEND_SOURCE" ]; then
        bundle_args+=(--ggml-backends "$GGML_BACKEND_SOURCE")
    fi

    if "$PROJECT_DIR/scripts/bundle_whisper_runtime.py" "${bundle_args[@]}"; then
        return 0
    fi

    if [ "$BUNDLE_WHISPER_RUNTIME" = "auto" ]; then
        echo "⚠️  whisper.cpp runtime не найден; сборка продолжится без bundled Whisper runtime." >&2
        return 0
    fi

    echo "❌ whisper.cpp runtime is required for this build." >&2
    echo "   Install whisper.cpp locally or set MACDICTATE_BUNDLE_WHISPER_RUNTIME=false for a developer-only build." >&2
    exit 1
}

bundle_whisper_runtime

# 5. Подпись бинарников
echo "🔐 Подписание приложения ($SIGN_MODE)..."
clean_bundle_metadata() {
    local target="$1"
    find "$target" \( -name ".DS_Store" -o -name "._*" \) -type f -delete
    dot_clean -m "$target" >/dev/null 2>&1 || true
    xattr -cr "$target" >/dev/null 2>&1 || true
    xattr -c "$target" >/dev/null 2>&1 || true
    find "$target" -exec xattr -c {} + >/dev/null 2>&1 || true
    xattr -dr com.apple.FinderInfo "$target" >/dev/null 2>&1 || true
    xattr -d com.apple.FinderInfo "$target" >/dev/null 2>&1 || true
    xattr -dr com.apple.ResourceFork "$target" >/dev/null 2>&1 || true
    xattr -d com.apple.ResourceFork "$target" >/dev/null 2>&1 || true
}

sign_nested_code() {
    local target="$1"
    local nested_root="$target/Contents/Resources"
    [ -d "$nested_root" ] || return 0

    while IFS= read -r -d '' nested; do
        if file "$nested" | grep -q "Mach-O"; then
            local nested_args=(--force --sign "$SIGN_IDENTITY")
            if [ "$SIGN_MODE" = "developer-id" ]; then
                nested_args+=(--timestamp --options runtime)
            fi
            codesign "${nested_args[@]}" "$nested" >/dev/null
            codesign --verify --strict --verbose=2 "$nested" >/dev/null
        fi
    done < <(find "$nested_root/bin" "$nested_root/lib" "$nested_root/libexec" -type f \( -perm -111 -o -name "*.dylib" -o -name "*.so" \) -print0 2>/dev/null || true)
}

sign_and_verify_app() {
    local target="$1"
    local output=""
    local attempt=1
    local codesign_args=()

    while [ "$attempt" -le 3 ]; do
        clean_bundle_metadata "$target"
        sign_nested_code "$target"
        clean_bundle_metadata "$target"
        codesign_args=(--force --sign "$SIGN_IDENTITY")
        if [ "$SIGN_MODE" = "developer-id" ]; then
            codesign_args+=(--timestamp --options runtime)
            if [ -n "$SIGN_ENTITLEMENTS" ]; then
                codesign_args+=(--entitlements "$SIGN_ENTITLEMENTS")
            fi
        fi
        codesign_args+=("$target")

        if output="$(codesign "${codesign_args[@]}" 2>&1)"; then
            clean_bundle_metadata "$target"
            if verify_strict_app_copy "$target" >/dev/null 2>&1; then
                clean_bundle_metadata "$target"
                return 0
            fi
            output="$(verify_strict_app_copy "$target" 2>&1)" || true
        fi

        if [ "$attempt" -lt 3 ]; then
            sleep 0.2
        fi
        attempt=$((attempt + 1))
    done

    printf '%s\n' "$output" >&2
    return 1
}

sign_and_verify_dmg() {
    local target="$1"

    if [ "$SIGN_MODE" != "developer-id" ]; then
        return 0
    fi

    codesign --force --timestamp --sign "$SIGN_IDENTITY" "$target" >/dev/null
    codesign --verify --verbose=2 "$target" >/dev/null
}

copy_app_without_extended_attrs() {
    local source="$1"
    local destination="$2"
    rm -rf "$destination"
    mkdir -p "$(dirname "$destination")"
    cp -R -X "$source" "$destination"
    clean_bundle_metadata "$destination"
}

notarize_dmg_if_requested() {
    local target="$1"

    if [ "$SIGN_MODE" != "developer-id" ]; then
        return 0
    fi

    case "$NOTARIZE_MODE" in
        0|false|FALSE|no|NO)
            echo "ℹ️  Notarization skipped by MACDICTATE_NOTARIZE=$NOTARIZE_MODE"
            return 0
            ;;
        auto)
            if [ -z "$NOTARY_PROFILE" ]; then
                echo "ℹ️  Notarization skipped: MACDICTATE_NOTARY_PROFILE is not set."
                echo "   Set MACDICTATE_NOTARY_PROFILE and rerun for release notarization."
                return 0
            fi
            ;;
        1|true|TRUE|yes|YES)
            if [ -z "$NOTARY_PROFILE" ]; then
                echo "❌ MACDICTATE_NOTARY_PROFILE is required when MACDICTATE_NOTARIZE=$NOTARIZE_MODE" >&2
                exit 1
            fi
            ;;
        *)
            echo "❌ Unsupported MACDICTATE_NOTARIZE value: $NOTARIZE_MODE" >&2
            echo "   Use auto, true, or false." >&2
            exit 1
            ;;
    esac

    echo "☁️  Notarizing DMG with notarytool profile '$NOTARY_PROFILE'..."
    xcrun notarytool submit "$target" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$target"
    xcrun stapler validate "$target"
    spctl -a -vv -t open --context context:primary-signature "$target" >/dev/null
}

verify_strict_app_copy() {
    local target="$1"
    local tmp_dir
    local verify_status=0
    tmp_dir="$(mktemp -d)"

    copy_app_without_extended_attrs "$target" "$tmp_dir/$APP_NAME"
    codesign --verify --deep --strict --verbose=2 "$tmp_dir/$APP_NAME" >/dev/null || verify_status=$?
    rm -rf "$tmp_dir"
    return "$verify_status"
}

SIGNED_APP_PARENT="$(mktemp -d /tmp/macdictate-signed-app.XXXXXX)"
SIGNED_APP_DIR="$SIGNED_APP_PARENT/$APP_NAME"
copy_app_without_extended_attrs "$APP_DIR" "$SIGNED_APP_DIR"
sign_and_verify_app "$SIGNED_APP_DIR"
if [ -x "$SIGNED_APP_DIR/Contents/Resources/bin/llama-completion" ] || [ -x "$SIGNED_APP_DIR/Contents/Resources/bin/llama-cli" ]; then
    "$PROJECT_DIR/scripts/check_bundled_llama_runtime.sh" "$SIGNED_APP_DIR"
fi
if [ -x "$SIGNED_APP_DIR/Contents/Resources/bin/whisper-cli" ]; then
    "$PROJECT_DIR/scripts/check_bundled_whisper_runtime.sh" "$SIGNED_APP_DIR"
fi
copy_app_without_extended_attrs "$SIGNED_APP_DIR" "$APP_DIR"

# 6. Сборка легкого DMG-образа
DMG_NAME="MacDictate_Final_v1.5.2.dmg"
DMG_OUTPUT_DIR="$BUILD_DIR/artifacts"
mkdir -p "$DMG_OUTPUT_DIR"
DMG_PATH="$DMG_OUTPUT_DIR/$DMG_NAME"
rm -f "$DMG_PATH"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "💿 Установка create-dmg (утилита AppleScript для DMG)..."
    brew install create-dmg
fi

echo "💿 Упаковка в DMG-образ..."
# Создаем staging для DMG вне Documents/iCloud/File Provider, чтобы не ловить FinderInfo/xattr после подписи.
DMG_SRC_PARENT="$(mktemp -d /tmp/macdictate-dmg-src.XXXXXX)"
DMG_SRC_DIR="$DMG_SRC_PARENT/root"
mkdir -p "$DMG_SRC_DIR"
copy_app_without_extended_attrs "$SIGNED_APP_DIR" "$DMG_SRC_DIR/$APP_NAME"
sign_and_verify_app "$DMG_SRC_DIR/$APP_NAME"
if [ -x "$DMG_SRC_DIR/$APP_NAME/Contents/Resources/bin/llama-completion" ] || [ -x "$DMG_SRC_DIR/$APP_NAME/Contents/Resources/bin/llama-cli" ]; then
    "$PROJECT_DIR/scripts/check_bundled_llama_runtime.sh" "$DMG_SRC_DIR/$APP_NAME"
fi
if [ -x "$DMG_SRC_DIR/$APP_NAME/Contents/Resources/bin/whisper-cli" ]; then
    "$PROJECT_DIR/scripts/check_bundled_whisper_runtime.sh" "$DMG_SRC_DIR/$APP_NAME"
fi

cd "$PROJECT_DIR"
create-dmg \
  --volname "MacDictate_v1_5_2" \
  --volicon "assets/AppIcon.icns" \
  --background "assets/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MacDictate.app" 140 190 \
  --app-drop-link 460 190 \
  --eula "assets/license.txt" \
  --no-internet-enable \
  --skip-jenkins \
  --hdiutil-retries 20 \
  "$DMG_PATH" \
  "$DMG_SRC_DIR"

sign_and_verify_dmg "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
verify_strict_app_copy "$APP_DIR"
notarize_dmg_if_requested "$DMG_PATH"
"$PROJECT_DIR/scripts/check_install_artifact_flow.sh" "$DMG_PATH"

echo "✅ ГОТОВО! Ваш нативный профессиональный дистрибутив (с иконками): $DMG_PATH"
echo "ℹ️  Для release перенесите DMG/build log в releases/versions/<version>/artifacts/ и обновите registry."
