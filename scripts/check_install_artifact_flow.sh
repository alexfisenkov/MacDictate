#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DMG_PATH="${1:-"$ROOT_DIR/build/artifacts/MacDictate_Final_v1.5.2.dmg"}"
TMPROOT="$(mktemp -d /tmp/macdictate-install-flow.XXXXXX)"
MOUNT_DIR="$TMPROOT/mount"
INSTALL_DIR="$TMPROOT/Applications"
APP_NAME="MacDictate.app"

cleanup() {
  hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || true
  rm -rf "$TMPROOT"
}
trap cleanup EXIT

fail() {
  echo "❌ $*" >&2
  exit 1
}

if [ ! -f "$DMG_PATH" ]; then
  fail "DMG not found: $DMG_PATH"
fi

mkdir -p "$MOUNT_DIR" "$INSTALL_DIR"

# The DMG has an EULA resource; hdiutil expects an explicit acceptance on stdin.
printf 'Y\n' | hdiutil attach "$DMG_PATH" -mountpoint "$MOUNT_DIR" -nobrowse -readonly >/dev/null

MOUNTED_APP="$MOUNT_DIR/$APP_NAME"
if [ ! -d "$MOUNTED_APP" ]; then
  fail "MacDictate.app not found inside mounted DMG: $DMG_PATH"
fi

codesign --verify --deep --strict --verbose=2 "$MOUNTED_APP" >/dev/null

if ! codesign -d --entitlements :- "$MOUNTED_APP" 2>/dev/null | grep -q 'com.apple.security.device.audio-input'; then
  fail "Mounted app is missing microphone entitlement."
fi

"$ROOT_DIR/scripts/check_bundled_llama_runtime.sh" "$MOUNTED_APP" >/dev/null
"$ROOT_DIR/scripts/check_bundled_whisper_runtime.sh" "$MOUNTED_APP" >/dev/null

INSTALLED_APP="$INSTALL_DIR/$APP_NAME"
cp -R -X "$MOUNTED_APP" "$INSTALLED_APP"

codesign --verify --deep --strict --verbose=2 "$INSTALLED_APP" >/dev/null

if ! codesign -d --entitlements :- "$INSTALLED_APP" 2>/dev/null | grep -q 'com.apple.security.device.audio-input'; then
  fail "Installed app copy is missing microphone entitlement."
fi

"$ROOT_DIR/scripts/check_bundled_llama_runtime.sh" "$INSTALLED_APP" >/dev/null
"$ROOT_DIR/scripts/check_bundled_whisper_runtime.sh" "$INSTALLED_APP" >/dev/null

echo "Install artifact flow check passed: $DMG_PATH"
