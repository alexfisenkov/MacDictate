#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-debug-session-logger"

cat > "$TEST_SWIFT" <<SWIFT
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \\(message)\\n", stderr)
        exit(1)
    }
}

let baseURL = URL(fileURLWithPath: "$TMP_DIR").appendingPathComponent("debug-sessions")
let defaults = UserDefaults(suiteName: "macdictate-debug-test-\(UUID().uuidString)")!
defaults.set(true, forKey: DebugSessionLogger.enabledKey)

let logger = DebugSessionLogger(baseDirectory: baseURL, userDefaults: defaults)
guard let session = logger.startSession(context: DebugSessionContext(
    appVersion: "test",
    textImprovementEnabled: true,
    machineID: "MD-TEST"
)) else {
    fputs("Expected debug session\\n", stderr)
    exit(1)
}

let audioURL = URL(fileURLWithPath: "$TMP_DIR").appendingPathComponent("audio.wav")
try Data("audio-bytes".utf8).write(to: audioURL)

session.copyAudio(from: audioURL.path)
session.writeTextFile("01_whisper_raw.txt", "сырой текст")
session.writeTextFile("02_whisper_cleaned.txt", "чистый текст")
session.record("qwen_finished", details: ["rawCharacters": "10", "finalCharacters": "12"])
session.finish(finalText: "финальный текст", warning: nil)

let files = try FileManager.default.contentsOfDirectory(atPath: session.directoryURL.path)
expect(files.contains("metadata.json"), "metadata should exist")
expect(files.contains("events.jsonl"), "events should exist")
expect(files.contains("audio.wav"), "audio copy should exist")
expect(files.contains("01_whisper_raw.txt"), "whisper raw should exist")
expect(files.contains("02_whisper_cleaned.txt"), "whisper cleaned should exist")
expect(files.contains("07_final_inserted.txt"), "final text should exist")

let metadata = try String(contentsOf: session.directoryURL.appendingPathComponent("metadata.json"), encoding: .utf8)
expect(metadata.contains("\"textImprovementEnabled\" : true") || metadata.contains("\"textImprovementEnabled\":true"), "metadata should include improvement flag")
expect(metadata.contains("MD-TEST"), "metadata should include machine ID")

let events = try String(contentsOf: session.directoryURL.appendingPathComponent("events.jsonl"), encoding: .utf8)
expect(events.contains("qwen_finished"), "events should include qwen event")
expect(events.contains("session_finished"), "events should include finish event")

let finalText = try String(contentsOf: session.directoryURL.appendingPathComponent("07_final_inserted.txt"), encoding: .utf8)
expect(finalText == "финальный текст", "final text should match")

defaults.set(false, forKey: DebugSessionLogger.enabledKey)
expect(logger.startSession(context: DebugSessionContext(appVersion: "test", textImprovementEnabled: false, machineID: "MD-TEST")) == nil, "disabled logger should not create session")

print("DebugSessionLogger test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Diagnostics/DebugSessionLogger.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
