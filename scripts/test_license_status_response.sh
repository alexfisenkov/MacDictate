#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-license-status-response"

cat >"$TEST_SWIFT" <<'SWIFT'
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \(message)\n", stderr)
        exit(1)
    }
}

func decode(_ json: String) -> LicenseStatusResponse {
    do {
        return try JSONDecoder().decode(
            LicenseStatusResponse.self,
            from: Data(json.utf8)
        )
    } catch {
        fputs("Failed to decode license status: \(error)\n", stderr)
        exit(1)
    }
}

let booleanResponse = decode("""
{
  "deviceId": "MD-BOOLEAN",
  "isPaid": true,
  "isActive": true,
  "expiresAt": "2027-06-05T09:12:54.480Z",
  "daysLeft": 392
}
""")
expect(booleanResponse.isPaid, "expected boolean isPaid")
expect(booleanResponse.isActive, "expected boolean isActive")

let numericResponse = decode("""
{
  "deviceId": "MD-NUMERIC",
  "isPaid": 1,
  "isActive": 1,
  "expiresAt": "2027-06-05T09:12:54.480Z",
  "daysLeft": 392
}
""")
expect(numericResponse.isPaid, "expected numeric isPaid to decode")
expect(numericResponse.isActive, "expected numeric isActive to decode")

let stringResponse = decode("""
{
  "deviceId": "MD-STRING",
  "isPaid": "false",
  "isActive": "0",
  "expiresAt": null,
  "daysLeft": 0
}
""")
expect(!stringResponse.isPaid, "expected string false isPaid")
expect(!stringResponse.isActive, "expected string false isActive")
expect(stringResponse.expiresAt == nil, "expected null expiresAt")

print("License status response decode test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/License/LicenseSnapshot.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
