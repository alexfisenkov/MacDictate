#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# A free app must not ship a dormant billing client or a purchase action.
if rg -n 'LicenseService|LicenseState|LicenseSnapshot|licenseService|openLicensePage|/api/license/status|MacDictateUID|MacDictateLicenseSnapshot|machineID' "$ROOT_DIR/src"; then
    echo "FAIL: desktop runtime still depends on licensing or billing identity" >&2
    exit 1
fi

cat > "$TMP_DIR/main.swift" <<'SWIFT'
import Cocoa

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

_ = NSApplication.shared
let controller = AppController()
let components = MenuBuilder.build(for: controller)
func titles(_ menu: NSMenu) -> [String] {
    menu.items.flatMap { [$0.title] + ($0.submenu.map(titles) ?? []) }
}
let menuTitles = titles(components.menu).joined(separator: "\n").lowercased()
for forbidden in ["лицензи", "триал", "подписк", "оплат", "grace"] {
    expect(!menuTitles.contains(forbidden), "menu must not contain \(forbidden)")
}
expect(menuTitles.contains("настройки"), "settings must remain available")
let ready = StatusPresentation.idleStatus(environmentIssue: nil, runtimeDiagnostic: nil)
expect(ready.text == "Ready" && ready.icon.isEmpty, "ready without a license or internet")
expect(StatusPresentation.diagnosticsSummary(environmentIssue: nil, runtimeDiagnostic: nil) == "Диагностика: OK", "no licensing diagnostic")
let denied = StatusPresentation.idleStatus(environmentIssue: .microphoneDenied, runtimeDiagnostic: nil)
expect(denied.icon == "⚠️", "microphone protection remains")
let failure = RuntimeDiagnostic(severity: .error, message: "Whisper failed")
expect(StatusPresentation.idleStatus(environmentIssue: nil, runtimeDiagnostic: failure).text == "Whisper failed", "runtime errors remain visible")
print("Free desktop menu and readiness tests passed.")
SWIFT

SOURCES=()
while IFS= read -r source; do
    SOURCES+=("$source")
done < <(find "$ROOT_DIR/src" -name '*.swift' ! -path "$ROOT_DIR/src/main.swift" | sort)
swiftc "${SOURCES[@]}" "$TMP_DIR/main.swift" -o "$TMP_DIR/test-free-desktop"
"$TMP_DIR/test-free-desktop"
