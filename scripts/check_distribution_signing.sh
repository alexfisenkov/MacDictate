#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-"$ROOT_DIR/build/MacDictate.app"}"
SIGN_IDENTITY="${MACDICTATE_SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}"
NOTARY_PROFILE="${MACDICTATE_NOTARY_PROFILE:-}"
DEFAULT_ENTITLEMENTS="$ROOT_DIR/assets/MacDictate.entitlements"
status=0

echo "== MacDictate distribution signing readiness =="
echo "Project: $ROOT_DIR"

developer_id_identities="$(
    security find-identity -v -p codesigning 2>/dev/null \
        | grep '"Developer ID Application:' \
        || true
)"

if [ -z "$developer_id_identities" ]; then
    echo "❌ No Developer ID Application signing identity found in Keychain."
    echo "   Create/download it from Apple Developer Account or Xcode Accounts."
    status=1
else
    echo "✅ Developer ID Application identity is available:"
    printf '%s\n' "$developer_id_identities"
fi

if [ -n "$SIGN_IDENTITY" ]; then
    if security find-identity -v -p codesigning | grep -Fq "$SIGN_IDENTITY"; then
        echo "✅ MACDICTATE_SIGN_IDENTITY is present: $SIGN_IDENTITY"
    else
        echo "❌ MACDICTATE_SIGN_IDENTITY not found in Keychain: $SIGN_IDENTITY"
        status=1
    fi
else
    echo "ℹ️  MACDICTATE_SIGN_IDENTITY is not set."
fi

if [ -n "$NOTARY_PROFILE" ]; then
    if xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
        echo "✅ Notary keychain profile works: $NOTARY_PROFILE"
    else
        echo "❌ Notary keychain profile failed: $NOTARY_PROFILE"
        status=1
    fi
else
    echo "ℹ️  MACDICTATE_NOTARY_PROFILE is not set; notarized release builds will be skipped unless it is configured."
fi

if [ -f "$DEFAULT_ENTITLEMENTS" ]; then
    if /usr/libexec/PlistBuddy -c "Print :com.apple.security.device.audio-input" "$DEFAULT_ENTITLEMENTS" 2>/dev/null | grep -q '^true$'; then
        echo "✅ Default release entitlements include microphone audio input: $DEFAULT_ENTITLEMENTS"
    else
        echo "❌ Default release entitlements are missing com.apple.security.device.audio-input: $DEFAULT_ENTITLEMENTS"
        status=1
    fi
else
    echo "❌ Default release entitlements file is missing: $DEFAULT_ENTITLEMENTS"
    status=1
fi

if [ -d "$APP_PATH" ]; then
    echo "== Installed/build app signing state =="
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,80p'
    entitlements="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)"
    if printf '%s\n' "$entitlements" | grep -q 'com.apple.security.device.audio-input'; then
        echo "✅ App entitlements include microphone audio input."
    else
        echo "❌ App entitlements are missing com.apple.security.device.audio-input."
        echo "   Developer ID + hardened runtime builds must include this entitlement for microphone access."
        status=1
    fi
    if spctl -a -vv --type execute "$APP_PATH" >/dev/null 2>&1; then
        echo "✅ spctl accepts app: $APP_PATH"
    else
        echo "⚠️  spctl does not accept app yet: $APP_PATH"
        echo "   This is expected for ad-hoc local builds or unsigned/not-notarized artifacts."
    fi

    if "$ROOT_DIR/scripts/check_bundled_llama_runtime.sh" "$APP_PATH"; then
        echo "✅ Bundled llama.cpp runtime is self-contained."
    else
        echo "❌ Bundled llama.cpp runtime check failed."
        status=1
    fi
else
    echo "ℹ️  App not found for inspection: $APP_PATH"
fi

exit "$status"
