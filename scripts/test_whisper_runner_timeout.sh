#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_CLI="$TMP_DIR/whisper-cli"
NOISY_CLI="$TMP_DIR/noisy-whisper-cli"
FAKE_MODEL="$TMP_DIR/model.bin"
FAKE_AUDIO="$TMP_DIR/audio.wav"
NOISY_AUDIO="$TMP_DIR/noisy-audio.wav"
TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-whisper-runner-timeout"

cat >"$FAKE_CLI" <<'SH'
#!/usr/bin/env bash
sleep 5
SH
chmod +x "$FAKE_CLI"

cat >"$NOISY_CLI" <<'SH'
#!/usr/bin/env bash
audio_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      audio_path="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

python3 - "$audio_path" <<'PY'
import os
import sys

audio_path = sys.argv[1]
for _ in range(2048):
    sys.stderr.write("diagnostic line " + ("x" * 1024) + "\n")
sys.stderr.flush()

with open(audio_path + ".txt", "w", encoding="utf-8") as fh:
    fh.write("recognized text")
PY
SH
chmod +x "$NOISY_CLI"

printf 'model' >"$FAKE_MODEL"
printf 'audio' >"$FAKE_AUDIO"
printf 'audio' >"$NOISY_AUDIO"

cat >"$TEST_SWIFT" <<SWIFT
import Foundation

func testTimedOutSleepingProcess() {
    let runner = WhisperRunner(
    timeoutSeconds: 0.2,
    terminationGraceSeconds: 0.1,
    modelPathProvider: { "$FAKE_MODEL" },
    whisperCliPathProvider: { "$FAKE_CLI" }
    )

    let startedAt = Date()
    let result = runner.transcribe(audioPath: "$FAKE_AUDIO")
    let elapsed = Date().timeIntervalSince(startedAt)

    guard elapsed < 2.0 else {
        fputs("Expected timeout recovery in under 2 seconds, got \\(elapsed)\\n", stderr)
        exit(1)
    }

    switch result {
    case .failure(.timedOut(let timeout)):
        guard timeout == 0.2 else {
            fputs("Expected timeout value 0.2, got \\(timeout)\\n", stderr)
            exit(1)
        }
    case .failure(let error):
        fputs("Expected timedOut failure, got \\(error)\\n", stderr)
        exit(1)
    case .success(let text):
        fputs("Expected timedOut failure, got success: \\(text)\\n", stderr)
        exit(1)
    }

    if FileManager.default.fileExists(atPath: "$FAKE_AUDIO") {
        fputs("Expected audio temp file cleanup after timeout\\n", stderr)
        exit(1)
    }
}

func testLargeStderrDoesNotBlockSuccessfulProcess() {
    let runner = WhisperRunner(
        timeoutSeconds: 2.0,
        terminationGraceSeconds: 0.1,
        modelPathProvider: { "$FAKE_MODEL" },
        whisperCliPathProvider: { "$NOISY_CLI" }
    )

    let startedAt = Date()
    let result = runner.transcribe(audioPath: "$NOISY_AUDIO")
    let elapsed = Date().timeIntervalSince(startedAt)

    guard elapsed < 2.0 else {
        fputs("Expected noisy subprocess to finish in under 2 seconds, got \\(elapsed)\\n", stderr)
        exit(1)
    }

    switch result {
    case .success(let text):
        guard text == "recognized text" else {
            fputs("Expected recognized text, got \\(text)\\n", stderr)
            exit(1)
        }
    case .failure(let error):
        fputs("Expected noisy subprocess success, got \\(error)\\n", stderr)
        exit(1)
    }
}

testTimedOutSleepingProcess()
testLargeStderrDoesNotBlockSuccessfulProcess()
print("WhisperRunner timeout test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Transcription/ModelLocator.swift" \
    "$ROOT_DIR/src/Transcription/WhisperRunner.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
