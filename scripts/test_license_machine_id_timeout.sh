#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SUCCESS_IOREG="$TMP_DIR/ioreg-success"
SLEEPING_IOREG="$TMP_DIR/ioreg-sleep"
TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-license-machine-id-timeout"

cat >"$SUCCESS_IOREG" <<'SH'
#!/usr/bin/env bash
printf '    "IOPlatformUUID" = "ABCDEF12-3456-7890-ABCD-EF1234567890"\n'
SH
chmod +x "$SUCCESS_IOREG"

cat >"$SLEEPING_IOREG" <<'SH'
#!/usr/bin/env bash
sleep 5
SH
chmod +x "$SLEEPING_IOREG"

cat >"$TEST_SWIFT" <<SWIFT
import Foundation

func makeDefaults(_ name: String) -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: name) else {
        fputs("Unable to create test UserDefaults suite\\n", stderr)
        exit(1)
    }
    defaults.removePersistentDomain(forName: name)
    return defaults
}

func testParsesAndCachesMachineID() {
    let suiteName = "com.alexfisenkov.macdictate.machine-id.success.\\(UUID().uuidString)"
    let defaults = makeDefaults(suiteName)
    let key = "MachineID"

    let resolved = LicenseService.resolveMachineID(
        userDefaults: defaults,
        machineIDKey: key,
        ioregPath: "$SUCCESS_IOREG",
        timeoutSeconds: 1
    )

    guard resolved == "MD-ABCDEF12" else {
        fputs("Expected parsed machine ID MD-ABCDEF12, got \\(resolved)\\n", stderr)
        exit(1)
    }

    let cached = LicenseService.resolveMachineID(
        userDefaults: defaults,
        machineIDKey: key,
        ioregPath: "$SLEEPING_IOREG",
        timeoutSeconds: 0.2
    )

    guard cached == resolved else {
        fputs("Expected cached machine ID \\(resolved), got \\(cached)\\n", stderr)
        exit(1)
    }

    defaults.removePersistentDomain(forName: suiteName)
}

func testSleepingMachineIDCommandFallsBackQuickly() {
    let suiteName = "com.alexfisenkov.macdictate.machine-id.timeout.\\(UUID().uuidString)"
    let defaults = makeDefaults(suiteName)
    let key = "MachineID"

    let startedAt = Date()
    let resolved = LicenseService.resolveMachineID(
        userDefaults: defaults,
        machineIDKey: key,
        ioregPath: "$SLEEPING_IOREG",
        timeoutSeconds: 0.2
    )
    let elapsed = Date().timeIntervalSince(startedAt)

    guard elapsed < 2.0 else {
        fputs("Expected machine ID timeout fallback in under 2 seconds, got \\(elapsed)\\n", stderr)
        exit(1)
    }

    guard resolved.hasPrefix("MD-"), resolved.count > 3 else {
        fputs("Expected generated MD-* fallback, got \\(resolved)\\n", stderr)
        exit(1)
    }

    guard defaults.string(forKey: key) == resolved else {
        fputs("Expected generated fallback to be cached\\n", stderr)
        exit(1)
    }

    defaults.removePersistentDomain(forName: suiteName)
}

testParsesAndCachesMachineID()
testSleepingMachineIDCommandFallsBackQuickly()
print("LicenseService machine ID timeout test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Diagnostics/DiagnosticStatus.swift" \
    "$ROOT_DIR/src/License/LicenseCache.swift" \
    "$ROOT_DIR/src/License/LicenseService.swift" \
    "$ROOT_DIR/src/License/LicenseSnapshot.swift" \
    "$ROOT_DIR/src/License/LicenseState.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
