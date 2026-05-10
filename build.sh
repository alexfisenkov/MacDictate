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
mkdir -p "$RESOURCES_DIR/bin"

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

# 4. (Пропущено) Использование whisper-cli напрямую из Homebrew
# Мы используем системный /opt/homebrew/bin/whisper-cli, так как он зависит от
# множества динамических библиотек (libggml, libwhisper) и путей @rpath.

# 5. Подпись бинарников
echo "🔐 Подписание приложения ($SIGN_MODE)..."
clean_bundle_metadata() {
    local target="$1"
    find "$target" \( -name ".DS_Store" -o -name "._*" \) -type f -delete
    dot_clean -m "$target" >/dev/null 2>&1 || true
    xattr -cr "$target" >/dev/null 2>&1 || true
    xattr -c "$target" >/dev/null 2>&1 || true
    xattr -dr com.apple.FinderInfo "$target" >/dev/null 2>&1 || true
    xattr -d com.apple.FinderInfo "$target" >/dev/null 2>&1 || true
}

sign_and_verify_app() {
    local target="$1"
    local output=""
    local attempt=1
    local codesign_args=()

    while [ "$attempt" -le 3 ]; do
        clean_bundle_metadata "$target"
        codesign_args=(--force --deep --sign "$SIGN_IDENTITY")
        if [ "$SIGN_MODE" = "developer-id" ]; then
            codesign_args+=(--timestamp --options runtime)
            if [ -n "$SIGN_ENTITLEMENTS" ]; then
                codesign_args+=(--entitlements "$SIGN_ENTITLEMENTS")
            fi
        fi
        codesign_args+=("$target")

        if output="$(codesign "${codesign_args[@]}" 2>&1)"; then
            clean_bundle_metadata "$target"
            if codesign --verify --deep --verbose=2 "$target" >/dev/null 2>&1; then
                clean_bundle_metadata "$target"
                return 0
            fi
            output="$(codesign --verify --deep --verbose=2 "$target" 2>&1)" || true
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
    tmp_dir="$(mktemp -d)"

    ditto --noextattr --noqtn "$target" "$tmp_dir/$APP_NAME"
    clean_bundle_metadata "$tmp_dir/$APP_NAME"
    codesign --verify --deep --strict --verbose=2 "$tmp_dir/$APP_NAME" >/dev/null
    rm -rf "$tmp_dir"
}

sign_and_verify_app "$APP_DIR"

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
# Создаем фолдер для сборки DMG
DMG_SRC_DIR="$BUILD_DIR/dmg_src"
mkdir -p "$DMG_SRC_DIR"
ditto --noextattr --noqtn "$APP_DIR" "$DMG_SRC_DIR/$APP_NAME"
sign_and_verify_app "$DMG_SRC_DIR/$APP_NAME"

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
  --hdiutil-retries 20 \
  "$DMG_PATH" \
  "$DMG_SRC_DIR"

sign_and_verify_app "$APP_DIR"
sign_and_verify_app "$DMG_SRC_DIR/$APP_NAME"
sign_and_verify_dmg "$DMG_PATH"
hdiutil verify "$DMG_PATH" >/dev/null
verify_strict_app_copy "$APP_DIR"
verify_strict_app_copy "$DMG_SRC_DIR/$APP_NAME"
notarize_dmg_if_requested "$DMG_PATH"

echo "✅ ГОТОВО! Ваш нативный профессиональный дистрибутив (с иконками): $DMG_PATH"
echo "ℹ️  Для release перенесите DMG/build log в releases/versions/<version>/artifacts/ и обновите registry."
