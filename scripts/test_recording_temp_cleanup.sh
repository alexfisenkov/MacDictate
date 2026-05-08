#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEMP_AUDIO="$TMP_DIR/mac_dictate_dist.wav"
TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-recording-temp-cleanup"

printf 'stale-audio' >"$TEMP_AUDIO"
printf 'stale-text' >"$TEMP_AUDIO.txt"

cat >"$TEST_SWIFT" <<SWIFT
import Foundation

let service = RecordingService(tempWavPath: "$TEMP_AUDIO")

if FileManager.default.fileExists(atPath: "$TEMP_AUDIO") {
    fputs("Expected stale temp audio to be removed on init\\n", stderr)
    exit(1)
}

if FileManager.default.fileExists(atPath: "$TEMP_AUDIO.txt") {
    fputs("Expected stale temp text to be removed on init\\n", stderr)
    exit(1)
}

try "stale-audio".write(toFile: "$TEMP_AUDIO", atomically: true, encoding: .utf8)
try "stale-text".write(toFile: "$TEMP_AUDIO.txt", atomically: true, encoding: .utf8)

service.cleanupTemporaryFiles()

if FileManager.default.fileExists(atPath: "$TEMP_AUDIO") {
    fputs("Expected cleanupTemporaryFiles to remove temp audio\\n", stderr)
    exit(1)
}

if FileManager.default.fileExists(atPath: "$TEMP_AUDIO.txt") {
    fputs("Expected cleanupTemporaryFiles to remove temp text\\n", stderr)
    exit(1)
}

print("RecordingService temp cleanup test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Transcription/RecordingService.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
