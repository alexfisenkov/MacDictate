#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

FAKE_MODEL="$TMP_DIR/qwen2.5-1.5b-instruct-q4_k_m.gguf"
SUCCESS_CLI="$TMP_DIR/llama-success"
TIMEOUT_CLI="$TMP_DIR/llama-timeout"
FAIL_CLI="$TMP_DIR/llama-fail"
TEST_SWIFT="$TMP_DIR/main.swift"
TEST_BIN="$TMP_DIR/test-text-improvement-runner"

printf "fake model" > "$FAKE_MODEL"

cat > "$SUCCESS_CLI" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
PROMPT_FILE=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -f)
      PROMPT_FILE="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [ -z "$PROMPT_FILE" ] || ! grep -q "превет мир" "$PROMPT_FILE"; then
  echo "prompt did not contain source text" >&2
  exit 9
fi

i=0
while [ "$i" -lt 5000 ]; do
  printf "stderr noise %04d\n" "$i" >&2
  i=$((i + 1))
done

cat <<'OUT'
Исправленный текст:
Привет, мир.
<|im_end|>
OUT
SH

cat > "$TIMEOUT_CLI" <<'SH'
#!/usr/bin/env bash
sleep 30
SH

cat > "$FAIL_CLI" <<'SH'
#!/usr/bin/env bash
echo "fatal llama failure" >&2
exit 7
SH

chmod +x "$SUCCESS_CLI" "$TIMEOUT_CLI" "$FAIL_CLI"

cat > "$TEST_SWIFT" <<SWIFT
import Foundation

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("Assertion failed: \\(message)\\n", stderr)
        exit(1)
    }
}

let fakeModel = "$FAKE_MODEL"
let successCli = "$SUCCESS_CLI"
let timeoutCli = "$TIMEOUT_CLI"
let failCli = "$FAIL_CLI"

let successRunner = TextImprovementRunner(
    timeoutSeconds: 5,
    terminationGraceSeconds: 0.2,
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { successCli }
)

switch successRunner.improve("превет мир") {
case .success(let improved):
    expect(improved == "Привет, мир.", "expected cleaned model output")
case .failure(let error):
    fputs("Expected success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

expect(
    TextImprovementRunner.cleanModelOutput("Improved text:\\nHello world.\\n[end of text]\\n<|endoftext|>") == "Hello world.",
    "expected English prefix cleanup"
)

let missingModelRunner = TextImprovementRunner(
    modelPathProvider: { nil },
    llamaCliPathProvider: { successCli }
)

switch missingModelRunner.improve("hello") {
case .failure(.modelMissing):
    break
default:
    fputs("Expected modelMissing\\n", stderr)
    exit(1)
}

let missingCliRunner = TextImprovementRunner(
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { nil }
)

switch missingCliRunner.improve("hello") {
case .failure(.llamaCliMissing):
    break
default:
    fputs("Expected llamaCliMissing\\n", stderr)
    exit(1)
}

let longInputRunner = TextImprovementRunner(
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { successCli }
)
let longInput = String(repeating: "а", count: 6_001)
switch longInputRunner.improve(longInput) {
case .failure(.inputTooLong(let limit)):
    expect(limit == 6_000, "expected safe input limit")
default:
    fputs("Expected inputTooLong\\n", stderr)
    exit(1)
}

let timeoutRunner = TextImprovementRunner(
    timeoutSeconds: 1,
    terminationGraceSeconds: 0.1,
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { timeoutCli }
)

let start = Date()
switch timeoutRunner.improve("hello") {
case .failure(.timedOut(let timeout)):
    expect(timeout == 1, "expected timeout value")
default:
    fputs("Expected timedOut\\n", stderr)
    exit(1)
}
expect(Date().timeIntervalSince(start) < 5, "timeout path took too long")

let failRunner = TextImprovementRunner(
    timeoutSeconds: 5,
    terminationGraceSeconds: 0.1,
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { failCli }
)

switch failRunner.improve("hello") {
case .failure(.nonZeroExit(let code, let detail)):
    expect(code == 7, "expected exit code 7")
    expect(detail.contains("fatal llama failure"), "expected stderr detail")
default:
    fputs("Expected nonZeroExit\\n", stderr)
    exit(1)
}

print("TextImprovementRunner test passed.")
SWIFT

swiftc \
    "$ROOT_DIR/src/Transcription/ModelLocator.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementRunner.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
