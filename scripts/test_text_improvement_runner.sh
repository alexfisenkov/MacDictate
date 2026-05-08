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

if [ -z "$PROMPT_FILE" ]; then
  echo "prompt file missing" >&2
  exit 9
fi

for required in "не меняй смысл" "DaVinci Resolve" "ChatGPT" "EBITDA" "HbA1c" "нумерованный список"; do
  if ! grep -q "$required" "$PROMPT_FILE"; then
    echo "prompt missing profile term: $required" >&2
    exit 10
  fi
done

if grep -q "ChaiJPT и Gemini" "$PROMPT_FILE"; then
  echo "prompt was not preformatted before Qwen" >&2
  exit 11
fi

i=0
while [ "$i" -lt 5000 ]; do
  printf "stderr noise %04d\n" "$i" >&2
  i=$((i + 1))
done

if grep -q "превет мир" "$PROMPT_FILE"; then
  cat <<'OUT'
Исправленный текст:
Привет, мир.
<|im_end|>
OUT
elif grep -q "1. Мы создали специальный сценарий." "$PROMPT_FILE"; then
  cat <<'OUT'
Исправленный текст:
Мы недавно собирались вместе с ChatGPT и Gemini от Google.

И вот к чему пришли:

1. Мы создали специальный сценарий.
2. Создали специальную штуку, которая обрабатывает этот сценарий.
3. Мы выделили несколько файлов-факторов, которые это все закрывают.
<|im_end|>
OUT
else
  echo "prompt did not contain expected source text" >&2
  exit 9
fi
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

func writeSparseFile(_ path: String, size: Int64) {
    FileManager.default.createFile(atPath: path, contents: Data())
    guard let handle = FileHandle(forWritingAtPath: path) else {
        fputs("Unable to open sparse file \\(path)\\n", stderr)
        exit(1)
    }
    try! handle.truncate(atOffset: UInt64(size))
    try! handle.close()
}

let modelSelectionDir = "$TMP_DIR/model-selection"
try! FileManager.default.createDirectory(atPath: modelSelectionDir, withIntermediateDirectories: true)
let preferredModelPath = modelSelectionDir + "/" + ModelLocator.preferredTextImprovementModelFilename
let legacyModelPath = modelSelectionDir + "/" + ModelLocator.legacyTextImprovementModelFilename
writeSparseFile(legacyModelPath, size: ModelLocator.minimumLegacyTextImprovementModelBytes + 1)
expect(ModelLocator.bestAvailableTextImprovementModelPath(in: modelSelectionDir) == legacyModelPath, "expected legacy 1.5B fallback before preferred model exists")
writeSparseFile(preferredModelPath, size: ModelLocator.minimumPreferredTextImprovementModelBytes - 1)
expect(ModelLocator.bestAvailableTextImprovementModelPath(in: modelSelectionDir) == legacyModelPath, "expected undersized preferred model to be ignored")
writeSparseFile(preferredModelPath, size: ModelLocator.minimumPreferredTextImprovementModelBytes + 1)
expect(ModelLocator.bestAvailableTextImprovementModelPath(in: modelSelectionDir) == preferredModelPath, "expected 3B model to be preferred when installed")

let successRunner = TextImprovementRunner(
    timeoutSeconds: 5,
    terminationGraceSeconds: 0.2,
    profile: .professionalCopyEditor,
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

switch successRunner.improveWithTrace("превет мир") {
case .success(let output):
    expect(output.text == "Привет, мир.", "expected traced improved text")
    expect(output.trace.input == "превет мир", "expected trace input")
    expect(output.trace.preparedInput == "превет мир", "expected trace prepared input")
    expect(output.trace.prompt.contains("превет мир"), "expected trace prompt")
    expect(output.trace.rawOutput.contains("Исправленный текст:"), "expected raw model output")
    expect(output.trace.cleanedOutput == "Привет, мир.", "expected cleaned model output in trace")
    expect(output.trace.finalOutput == "Привет, мир.", "expected final model output in trace")
    expect(output.trace.modelPath == fakeModel, "expected model path in trace")
    expect(output.trace.runtimePath == successCli, "expected runtime path in trace")
case .failure(let error):
    fputs("Expected trace success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let rawDebugSessionInput = "Мы тут недавно собирались вместе с ChaiJPT и Gemini от Google. И вот к чему пришли. Во-первых, мы создали специальный сценарий. Во-вторых, создали специальную штуку, которая обрабатывает этот сценарий. Ну, а в-третьих, мы выделили несколько файлов-факторов, которые это все закрывают."
switch successRunner.improveWithTrace(rawDebugSessionInput) {
case .success(let output):
    expect(output.trace.input.contains("ChaiJPT"), "expected raw trace input to preserve original Whisper text")
    expect(!output.trace.preparedInput.contains("ChaiJPT"), "expected prepared input to fix ChaiJPT before Qwen")
    expect(output.trace.preparedInput.contains("ChatGPT"), "expected prepared input to contain ChatGPT")
    expect(output.trace.preparedInput.contains("И вот к чему пришли:"), "expected prepared input heading")
    expect(output.trace.preparedInput.contains("1. Мы создали специальный сценарий."), "expected prepared input numbered list")
    expect(output.trace.prompt.contains("1. Мы создали специальный сценарий."), "expected Qwen prompt to use prepared numbered list")
    expect(output.text.contains("ChatGPT и Gemini от Google."), "expected real debug text to normalize ChatGPT")
    expect(output.text.contains("И вот к чему пришли:"), "expected real debug text heading")
    expect(output.text.contains("2. Создали специальную штуку, которая обрабатывает этот сценарий."), "expected real debug text to preserve conversational wording")
case .failure(let error):
    fputs("Expected real debug trace success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

expect(
    TextImprovementRunner.cleanModelOutput("Improved text:\\nHello world.\\n[end of text]\\n<|endoftext|>") == "Hello world.",
    "expected English prefix cleanup"
)

let profilePrompt = TextImprovementProfile.professionalCopyEditor.prompt(for: "чат джпт и давинчи резолв")
expect(profilePrompt.contains("чат джпт и давинчи резолв"), "expected source text in profile prompt")
expect(profilePrompt.contains("не меняй смысл"), "expected no-meaning-change rule")
expect(profilePrompt.contains("маркированный список"), "expected bullet list rule")
expect(profilePrompt.contains("нумерованный список"), "expected numbered list rule")
expect(profilePrompt.contains("ChatGPT"), "expected AI terminology")
expect(profilePrompt.contains("DaVinci Resolve"), "expected creator terminology")
expect(profilePrompt.contains("EBITDA"), "expected finance terminology")
expect(profilePrompt.contains("HbA1c"), "expected medical terminology")
expect(profilePrompt.contains("чат джпт -> ChatGPT"), "expected direct ChatGPT speech mapping")
expect(profilePrompt.contains("ChagPT / Chag GPT / ChagJPT -> ChatGPT"), "expected direct ChagPT speech mapping")
expect(profilePrompt.contains("ChaiJPT -> ChatGPT"), "expected direct ChaiJPT speech mapping")
expect(profilePrompt.contains("Клод от Anthropic / Cloud от Anthropic / Cloud Anthropic -> Claude от Anthropic / Claude Anthropic"), "expected direct Claude speech mapping")
expect(profilePrompt.contains("Syntx AI"), "expected Syntx AI terminology")
expect(profilePrompt.contains("Syntax AI / SyntaxAI / Синтакс AI / синтакс ай -> Syntx AI"), "expected direct Syntx AI speech mapping")
expect(!profilePrompt.contains("Вход:"), "runtime prompt should avoid example input labels")
expect(!profilePrompt.contains("Выход:"), "runtime prompt should avoid example output labels")
expect(profilePrompt.contains("Не заменяй разговорные слова автора"), "expected conservative wording rule")
expect(profilePrompt.contains("давинчи резолв -> DaVinci Resolve"), "expected direct DaVinci speech mapping")
expect(profilePrompt.contains("во-первых"), "expected ordered-list speech cue")
expect(profilePrompt.contains("несколько раз повторяется «дальше»"), "expected repeated дальше list cue")
expect(profilePrompt.contains("не оставляй слова «во первых»"), "expected strict ordered-list replacement rule")
expect(profilePrompt.contains("не добавляй жирность"), "expected no decorative markdown rule")
expect(profilePrompt.count < 12_000, "profile prompt should stay compact")

let ordered = TextImprovementFormatter.formatObviousOrderedEnumeration(
    "сегодня надо проверить ChatGPT, Qwen, EBITDA и DaVinci Resolve во первых сделать монтаж во вторых проверить финансы в третьих подготовить контент план"
)
expect(ordered.contains("Сегодня надо проверить ChatGPT, Qwen, EBITDA и DaVinci Resolve."), "expected intro sentence")
expect(ordered.contains("1. Сделать монтаж."), "expected first numbered item")
expect(ordered.contains("2. Проверить финансы."), "expected second numbered item")
expect(ordered.contains("3. Подготовить контент-план."), "expected third numbered item")
expect(!ordered.contains("во первых"), "ordered output should remove speech marker")

let orderedWithConjunctionMarkers = TextImprovementFormatter.formatObviousOrderedEnumeration(
    "вот что я хочу сказать первое сегодня речь пойдет о ChatGPT и второе как дела у Gemini и третье Runway превосходит Kling AI"
)
expect(orderedWithConjunctionMarkers.contains("1. Сегодня речь пойдет о ChatGPT."), "expected first item without dangling conjunction")
expect(orderedWithConjunctionMarkers.contains("2. Как дела у Gemini."), "expected second item")
expect(orderedWithConjunctionMarkers.contains("3. Runway превосходит Kling AI."), "expected third item")
expect(!orderedWithConjunctionMarkers.contains(" И."), "expected no dangling conjunction before next marker")

let normalizedTerms = TextImprovementFormatter.normalize("ChagPT, чат джпт и давинчи резолв, контент план")
expect(normalizedTerms == "ChatGPT, ChatGPT и DaVinci Resolve, контент-план", "expected fallback terminology normalization")

let normalizedClaudeTerms = TextImprovementFormatter.normalize("Cloud от Anthropic и Клод от Anthropic")
expect(normalizedClaudeTerms == "Claude от Anthropic и Claude от Anthropic", "expected fallback Claude terminology normalization")

let normalizedSyntxTerms = TextImprovementFormatter.normalize("Syntax AI, SyntaxAI и синтакс ай")
expect(normalizedSyntxTerms == "Syntx AI, Syntx AI и Syntx AI", "expected fallback Syntx AI terminology normalization")

let realDebugSessionOutput = TextImprovementFormatter.normalize(
    "Мы недавно собирались с ChaiJPT и Gemini от Google. Вот что мы достигли. Во-первых, мы создали специальный сценарий. Во-вторых, мы создали специальную штуку, которая обрабатывает этот сценарий. Ну, а в-третьих, мы выделили несколько файлов-факторов, которые это все закрывают."
)
expect(realDebugSessionOutput.contains("ChatGPT и Gemini от Google."), "expected ChaiJPT to normalize to ChatGPT")
expect(realDebugSessionOutput.contains("Вот что мы достигли:"), "expected achievement cue to become list heading")
expect(realDebugSessionOutput.contains("1. Мы создали специальный сценарий."), "expected first real debug item")
expect(realDebugSessionOutput.contains("2. Мы создали специальную штуку, которая обрабатывает этот сценарий."), "expected second real debug item")
expect(realDebugSessionOutput.contains("3. Мы выделили несколько файлов-факторов, которые это все закрывают."), "expected third real debug item")
expect(!realDebugSessionOutput.contains("Во-первых"), "expected speech markers removed from real debug output")

let chagPTLogRegression = TextImprovementFormatter.normalize(
    "Когда-то давно у меня была такая игрушка под названием Gemini от Google, Клод от Anthropic и ChagPT от OpenAI. Знаете, что я сделал? Правильно. Первое. Я создал ChagPT с нуля. Сам. Самостоятельно. Дальше. Второе. Я преобразовал Gemini от Google в реально крутую игрушку."
)
expect(chagPTLogRegression.contains("Claude от Anthropic и ChatGPT от OpenAI."), "expected ChagPT in intro to normalize to ChatGPT")
expect(chagPTLogRegression.contains("1. Я создал ChatGPT с нуля. Сам. Самостоятельно. Дальше."), "expected ChagPT in list item to normalize to ChatGPT")
expect(chagPTLogRegression.contains("2. Я преобразовал Gemini от Google в реально крутую игрушку."), "expected second list item")
expect(!chagPTLogRegression.contains("ChagPT"), "expected no ChagPT after formatter")
expect(!chagPTLogRegression.contains("1. ."), "expected numbered marker punctuation cleanup")

let leakedPromptScaffold = """
1. Вход: исходный текст, который модель не должна копировать.
2. Выход:
- Правильный первый абзац.
- Правильный второй абзац.
"""
expect(
    TextImprovementRunner.cleanModelOutput(leakedPromptScaffold) == "Правильный первый абзац.\nПравильный второй абзац.",
    "expected leaked prompt scaffold cleanup"
)

let modelPreambleWithRules = """
Вот исправленный и отформатированный текст:

---

Тут смысл в чем? Смотрите.

1. Установить ChatGPT.
2. Проверить аккаунт.

---
"""
expect(
    TextImprovementRunner.cleanModelOutput(modelPreambleWithRules) == "Тут смысл в чем? Смотрите.\n\n1. Установить ChatGPT.\n2. Проверить аккаунт.",
    "expected model preamble and horizontal rules cleanup"
)

expect(
    TextImprovementRunner.stripDecorativeMarkdownIfSourceWasPlain(
        "Gemini, **Claude** и __ChatGPT__.",
        source: "Gemini, Claude и ChatGPT."
    ) == "Gemini, Claude и ChatGPT.",
    "expected decorative markdown stripped when source is plain"
)
expect(
    TextImprovementRunner.stripDecorativeMarkdownIfSourceWasPlain(
        "**ChatGPT** остается выделенным.",
        source: "**ChatGPT** уже был выделен."
    ) == "**ChatGPT** остается выделенным.",
    "expected markdown preserved when source already uses markdown"
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
    "$ROOT_DIR/src/TextImprovement/TextImprovementProfile.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementFormatter.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementRunner.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
