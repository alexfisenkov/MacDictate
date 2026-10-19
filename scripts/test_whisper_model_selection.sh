#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-whisper-model-selection"
MODEL_DIR="$TMP_DIR/models"
mkdir -p "$MODEL_DIR"

cat >"$TEST_SWIFT" <<SWIFT
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \\(message)\\n", stderr)
        exit(1)
    }
}

func writeSparseFile(_ path: String, size: Int64) {
    FileManager.default.createFile(atPath: path, contents: Data())
    guard let handle = FileHandle(forWritingAtPath: path) else {
        fputs("Failed to open sparse file at \\(path)\\n", stderr)
        exit(1)
    }
    handle.truncateFile(atOffset: UInt64(size))
    try? handle.close()
}

let directory = "$MODEL_DIR"
let balancedPath = directory + "/" + ModelLocator.balancedWhisperModelFilename
let maximumPath = directory + "/" + ModelLocator.maximumAccuracyWhisperModelFilename
let legacyPath = directory + "/custom-whisper.bin"

expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .balanced) == nil, "empty model dir should not resolve")

writeSparseFile(balancedPath, size: ModelLocator.minimumBalancedWhisperModelBytes + 1)
expect(ModelLocator.hasInstalledBalancedWhisperModel(in: directory), "balanced turbo should be detected")
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .balanced) == balancedPath, "balanced mode should pick turbo")
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .maximumAccuracy) == balancedPath, "maximum mode should fallback to turbo before large-v3 is installed")

writeSparseFile(maximumPath, size: ModelLocator.minimumMaximumAccuracyWhisperModelBytes + 1)
expect(ModelLocator.hasInstalledMaximumAccuracyWhisperModel(in: directory), "maximum large-v3 should be detected")
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .balanced) == balancedPath, "balanced mode should keep using turbo even when large-v3 exists")
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .maximumAccuracy) == maximumPath, "maximum mode should pick large-v3")

try FileManager.default.removeItem(atPath: balancedPath)
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .balanced) == maximumPath, "balanced mode should fallback to large-v3 when turbo is unavailable")

try FileManager.default.removeItem(atPath: maximumPath)
writeSparseFile(legacyPath, size: ModelLocator.minimumLegacyWhisperModelBytes + 1)
expect(ModelLocator.bestAvailableModelPath(in: directory, mode: .balanced) == legacyPath, "legacy bin fallback should remain available")

let defaults = UserDefaults(suiteName: "macdictate-whisper-model-selection-\(UUID().uuidString)")!
expect(WhisperModelSettings.currentMode(userDefaults: defaults) == .balanced, "default mode should be balanced")
WhisperModelSettings.setMode(.maximumAccuracy, userDefaults: defaults)
expect(WhisperModelSettings.currentMode(userDefaults: defaults) == .maximumAccuracy, "mode should persist")

print("Whisper model selection test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Transcription/WhisperModelSettings.swift" \
    "$ROOT_DIR/src/Transcription/ModelLocator.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
