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

# 1. Очистка и создание структуры
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR/bin"

# 2. Копирование Info.plist
cp "$PROJECT_DIR/assets/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$PROJECT_DIR/assets/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

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

# 5. Ad-Hoc подпись бинарников
echo "🔐 Подписание приложения..."
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

    while [ "$attempt" -le 3 ]; do
        clean_bundle_metadata "$target"
        if output="$(codesign --force --deep --sign - "$target" 2>&1)"; then
            clean_bundle_metadata "$target"
            if codesign --verify --deep --verbose=2 "$target" >/dev/null 2>&1; then
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

sign_and_verify_app "$APP_DIR"

# 6. Сборка легкого DMG-образа
DMG_NAME="MacDictate_Final_v1.4.2.dmg"
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
  --volname "MacDictate_v1_4_2" \
  --volicon "assets/AppIcon.icns" \
  --background "assets/dmg_background.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "MacDictate.app" 140 190 \
  --app-drop-link 460 190 \
  --eula "assets/license.txt" \
  --no-internet-enable \
  "$DMG_PATH" \
  "$DMG_SRC_DIR"

sign_and_verify_app "$APP_DIR"
sign_and_verify_app "$DMG_SRC_DIR/$APP_NAME"
hdiutil verify "$DMG_PATH" >/dev/null

echo "✅ ГОТОВО! Ваш нативный профессиональный дистрибутив (с иконками): $DMG_PATH"
echo "ℹ️  Для release перенесите DMG/build log в releases/versions/<version>/artifacts/ и обновите registry."
