#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-"$ROOT_DIR/build/MacDictate.app"}"
SIGN_IDENTITY="${MACDICTATE_SIGN_IDENTITY:-${DEVELOPER_ID_APPLICATION:-}}"
NOTARY_PROFILE="${MACDICTATE_NOTARY_PROFILE:-}"
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

if [ -d "$APP_PATH" ]; then
    echo "== Installed/build app signing state =="
    codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n '1,80p'
    if spctl -a -vv --type execute "$APP_PATH" >/dev/null 2>&1; then
        echo "✅ spctl accepts app: $APP_PATH"
    else
        echo "⚠️  spctl does not accept app yet: $APP_PATH"
        echo "   This is expected for ad-hoc local builds or unsigned/not-notarized artifacts."
    fi
else
    echo "ℹ️  App not found for inspection: $APP_PATH"
fi

exit "$status"
