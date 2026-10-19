#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_ROOT_DIR="$(cd "$ROOT_DIR/../.." && pwd)"
TMP_DIR="$(mktemp -d)"
PORT="${MACDICTATE_TEST_PORT:-18765}"
SERVER_PID=""

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        kill "$SERVER_PID" 2>/dev/null || true
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$TMP_DIR" >/dev/null 2>&1 &
SERVER_PID="$!"

for _ in $(seq 1 30); do
    if /usr/bin/curl -fsS --max-time 1 "http://127.0.0.1:$PORT/" >/dev/null 2>&1; then
        break
    fi
    /bin/sleep 0.1
done

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-license-grace-diagnostic"

cat >"$TEST_SWIFT" <<SWIFT
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \\(message)\\n", stderr)
        exit(1)
    }
}

func makeDefaults(_ name: String) -> UserDefaults {
    guard let defaults = UserDefaults(suiteName: name) else {
        fputs("Unable to create test UserDefaults suite\\n", stderr)
        exit(1)
    }
    defaults.removePersistentDomain(forName: name)
    return defaults
}

func waitForTerminalLicenseState(_ service: LicenseService) -> LicenseState {
    var observedState: LicenseState?
    service.onChange = {
        switch service.state {
        case .checking:
            return
        case .active, .grace, .expired, .serverUnavailable:
            observedState = service.state
        }
    }

    service.checkStatus(promoteCheckingState: true)
    let deadline = Date().addingTimeInterval(5)
    while observedState == nil && Date() < deadline {
        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.05))
    }

    guard let observedState else {
        fputs("Timed out waiting for license state\\n", stderr)
        exit(1)
    }
    return observedState
}

func testCachedSnapshotFailureStaysQuietGrace() {
    let suiteName = "com.alexfisenkov.macdictate.license-grace.\\(UUID().uuidString)"
    let defaults = makeDefaults(suiteName)
    let cache = LicenseCache(userDefaults: defaults)
    let machineID = "MD-GRACEOK"
    defaults.set(machineID, forKey: "MachineID")
    cache.persist(
        LicenseSnapshot(
            machineID: machineID,
            isPaid: true,
            isActive: true,
            daysLeft: 10,
            expiresAt: Date().addingTimeInterval(10 * 24 * 60 * 60),
            checkedAt: Date()
        )
    )

    let service = LicenseService(
        userDefaults: defaults,
        cache: cache,
        statusURLString: "http://127.0.0.1:$PORT/api/license/status",
        refreshInterval: 3600,
        machineIDKey: "MachineID"
    )

    let state = waitForTerminalLicenseState(service)
    switch state {
    case .grace(let snapshot, let deadline):
        expect(snapshot.machineID == machineID, "expected cached snapshot")
        expect(deadline > Date(), "expected future grace deadline")
        expect(service.runtimeDiagnostic == nil, "expected no warning diagnostic while grace allows dictation")
    default:
        fputs("Expected grace state, got \\(state)\\n", stderr)
        exit(1)
    }

    defaults.removePersistentDomain(forName: suiteName)
}

func testNoCacheFailureUsesBoundedFirstRunGrace() {
    let suiteName = "com.alexfisenkov.macdictate.license-unavailable.\\(UUID().uuidString)"
    let defaults = makeDefaults(suiteName)
    defaults.set("MD-NOCACHE", forKey: "MachineID")

    let service = LicenseService(
        userDefaults: defaults,
        cache: LicenseCache(userDefaults: defaults),
        statusURLString: "http://127.0.0.1:$PORT/api/license/status",
        refreshInterval: 3600,
        machineIDKey: "MachineID"
    )

    let state = waitForTerminalLicenseState(service)
    switch state {
    case .grace(let snapshot, let deadline):
        expect(snapshot.machineID == "MD-NOCACHE", "expected first-run grace snapshot")
        expect(!snapshot.isPaid, "expected first-run grace to stay unpaid")
        expect(deadline > Date(), "expected future first-run grace deadline")
        expect(service.runtimeDiagnostic != nil, "expected warning diagnostic while first-run grace is active")
    default:
        fputs("Expected first-run grace state, got \\(state)\\n", stderr)
        exit(1)
    }

    defaults.removePersistentDomain(forName: suiteName)
}

func testExpiredCacheDoesNotGetFreshFirstRunGrace() {
    let suiteName = "com.alexfisenkov.macdictate.license-expired-cache.\(UUID().uuidString)"
    let defaults = makeDefaults(suiteName)
    let cache = LicenseCache(userDefaults: defaults)
    let machineID = "MD-OLDGRACE"
    defaults.set(machineID, forKey: "MachineID")
    cache.persist(
        LicenseSnapshot(
            machineID: machineID,
            isPaid: true,
            isActive: true,
            daysLeft: 0,
            expiresAt: Date().addingTimeInterval(-10 * 24 * 60 * 60),
            checkedAt: Date().addingTimeInterval(-10 * 24 * 60 * 60)
        )
    )

    let service = LicenseService(
        userDefaults: defaults,
        cache: cache,
        statusURLString: "http://127.0.0.1:$PORT/api/license/status",
        refreshInterval: 3600,
        machineIDKey: "MachineID"
    )

    let state = waitForTerminalLicenseState(service)
    switch state {
    case .serverUnavailable(let snapshot):
        expect(snapshot?.machineID == machineID, "expected old snapshot to be retained for diagnostics")
        expect(service.runtimeDiagnostic != nil, "expected warning diagnostic after expired cache")
    default:
        fputs("Expected serverUnavailable for expired cache, got \\(state)\\n", stderr)
        exit(1)
    }

    defaults.removePersistentDomain(forName: suiteName)
}

testCachedSnapshotFailureStaysQuietGrace()
testNoCacheFailureUsesBoundedFirstRunGrace()
testExpiredCacheDoesNotGetFreshFirstRunGrace()
print("License grace diagnostic test passed.")
SWIFT

swiftc \
    "$APP_ROOT_DIR/src/Diagnostics/DiagnosticStatus.swift" \
    "$ROOT_DIR/src/License/LicenseCache.swift" \
    "$ROOT_DIR/src/License/LicenseService.swift" \
    "$ROOT_DIR/src/License/LicenseSnapshot.swift" \
    "$ROOT_DIR/src/License/LicenseState.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
