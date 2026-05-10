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
elif grep -q "У нас осталось тут совсем немножко времени" "$PROMPT_FILE"; then
  cat <<'OUT'
1. Что нужно сделать, это установить ChatGPT.
2. Это нормально справиться с этой задачей.
3. Это удалить все остальные нейросети. И после того, как пройдут все эти шаги, мы с вами уже на самом деле станем счастливыми людьми. Я также хочу сказать, что сегодня еще 9 мая. Это День Победы. День Победы празднуется в России и очень широко.
4. И хорошо. Поэтому очень многие нейросети по типу Runway, по типу Syntx AI будут сейчас заменены на российские аналоги. Просто имейте это в виду и работайте грамотно и аккуратно. [end of text]
OUT
elif grep -q "сегодняшнем уроке мы пройдем" "$PROMPT_FILE"; then
  if grep -q "Повторная попытка после ошибки валидатора: extra_ordered_list_item" "$PROMPT_FILE"; then
    cat <<'OUT'
Друзья, коллеги, команда, всем привет. И сегодня у нас с вами большая тема для разговора. Это инструкции для чата GPT. В сегодняшнем уроке мы пройдем:

1. Как создавать инструкции для чата GPT.
2. Как использовать Google и вообще нейросеть Gemini для того, чтобы она создавала действительно крутой текст.
3. Мы пройдем с вами Cloud Code от Anthropic.

И посмотрим, на что способны расти локально. И все это мы будем делать с вами действительно очень и очень круто. Впереди у нас с вами открывается большое путешествие, в которое мы с вами вступаем буквально с минуты на минуту. Ну что, поехали. [end of text]
OUT
  else
    cat <<'OUT'
Друзья, коллеги, команда, всем привет. И сегодня у нас с вами большая тема для разговора. Это инструкции для чата GPT. В сегодняшнем уроке мы пройдем:

1. Как создавать инструкции для чата GPT.
2. Как использовать Google и вообще нейросеть Gemini для того, чтобы она создавала действительно крутой текст.
3. Мы пройдем с вами Cloud Code от Anthropic.
4. И посмотрим, на что способны расти локально. И все это мы будем делать с вами действительно очень и очень круто. Впереди у нас с вами открывается большое путешествие, в которое мы с вами вступаем буквально с минуты на минуту. Ну что, поехали. [end of text]
OUT
  fi
elif grep -q "Возможно ли пользоваться реально iPad" "$PROMPT_FILE"; then
  cat <<'OUT'
Ваш запрос можно переписать следующим образом:

---

Мне нужно узнать, возможно ли использовать реально iPad как компьютер. Имеется ли такой вариант, чтобы иметь полноценный доступ к удаленной машине, чтобы она полностью переносила iPad, обеспечив работу всех приложений и функций на 100% безупречно? Есть ли такой вариант вообще?

---

Текст сохранен в исходном формате, язык и стиль автора сохранены. [end of text]
OUT
elif grep -q "Мне нужна помощь. Я могу разобраться в тексте" "$PROMPT_FILE"; then
  cat <<'OUT'
Конечно, я могу помочь с редактированием и коррекцией вашего текста. Пожалуйста, предоставьте фрагмент текста, который вам нужно обработать. [end of text]
OUT
elif grep -q "как ты относишься к корректировке текста через нейросеть" "$PROMPT_FILE"; then
  cat <<'OUT'
Я отношусь к корректировке текста через нейросеть с положительной точки зрения. Нейросети могут помочь в выявлении и исправлении ошибок, особенно тех, которые могут быть трудно заметить для человека. Однако важно помнить, что они не заменяют проверку рукой и могут допускать ошибки, особенно если текст содержит специфические или уникальные случаи. [end of text]
OUT
elif grep -q "проверить длинный вывод модели" "$PROMPT_FILE"; then
  i=0
  while [ "$i" -lt 120 ]; do
    printf "Это лишний расширенный ответ модели номер %03d, который не должен попадать во вставку. " "$i"
    i=$((i + 1))
  done
  printf "[end of text]\n"
elif grep -q "1. Это только установить Charger 5." "$PROMPT_FILE"; then
  cat <<'OUT'
Ваш текст уже практически готов, но есть несколько небольших исправлений и дополнений, чтобы он был более грамотным и аккуратным:

1. Это только установить Charger 5.
2. Это нормально справиться с этой задачей.

Исправления:
- Убрали лишние пробелы и запятые.
- Уточнили пунктуацию после "5".

Текст выглядит следующим образом:

1. Это только установить Charger 5.
2. Это нормально справиться с этой задачей. [end of text]
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

let editorialReportRegressionInput = "Как будто бы сейчас тесты проходят нормально. И, наверное, больше ничего делать не надо. Как минимум. Ну, первое, это только установить Charger 5. И второе, это нормально справиться с этой задачей."
switch successRunner.improveWithTrace(editorialReportRegressionInput) {
case .success(let output):
    expect(!output.text.contains("Ваш текст уже"), "expected editorial report preamble to be blocked")
    expect(!output.text.contains("Исправления:"), "expected editorial report section to be blocked")
    expect(output.text.contains("Как будто бы сейчас тесты проходят нормально."), "expected fallback to preserve original intro")
    expect(output.text.contains("1. Это только установить Charger 5."), "expected fallback to preserve first formatted item")
    expect(output.text.contains("2. Это нормально справиться с этой задачей."), "expected fallback to preserve second formatted item")
    expect(output.trace.rawOutput.contains("Ваш текст уже"), "expected raw trace to retain model report for debugging")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected cleaned trace to use safe prepared input after commentary fallback")
case .failure(let error):
    fputs("Expected editorial report regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let latestContentDropRegressionInput = "Раз, два, три, три, два, один. У нас осталось тут совсем немножко времени. Первое, что нужно сделать, это установить чат GPT. Второе, это нормально справиться с этой задачей. Третье, это удалить все остальные нейросети. И после того, как пройдут все эти шаги, мы с вами уже на самом деле станем счастливыми людьми. Я также хочу сказать, что сегодня еще 9 мая. Это День Победы. День Победы празднуется в России и очень широко. И хорошо. Поэтому очень многие нейросети по типу Runway, по типу Cling AI будут сейчас заменены на российские аналоги по типу Syntax AI. Просто имейте это в виду и работайте грамотно и аккуратно."
switch successRunner.improveWithTrace(latestContentDropRegressionInput) {
case .success(let output):
    expect(output.trace.rawOutput.contains("1. Что нужно сделать"), "expected raw trace to retain lossy Qwen output")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected cleaned trace to fallback to prepared input after content loss")
    expect(output.text.contains("Раз, два, три, три, два, один."), "expected fallback to preserve opening phrase")
    expect(output.text.contains("У нас осталось тут совсем немножко времени."), "expected fallback to preserve intro sentence")
    expect(output.text.contains("Kling AI"), "expected Cling AI to normalize to Kling AI")
    expect(output.text.contains("Syntx AI"), "expected Syntax AI to normalize to Syntx AI")
case .failure(let error):
    fputs("Expected latest content-drop regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let latestExtraListItemRegressionInput = "Друзья, коллеги, команда, всем привет. И сегодня у нас с вами большая тема для разговора. Это инструкции для чата GPT. И в сегодняшнем уроке мы пройдем. Первое. Как создавать инструкции для чата GPT? Второе. Как использовать Google и вообще нейросеть Gemini для того, чтобы она создавала действительно крутой текст? Третье. Мы пройдем с вами Cloud Code от Anthropic. И посмотрим, на что способны расти локально. И все это мы будем делать с вами действительно очень и очень круто. Впереди у нас с вами открывается большое путешествие, в которое мы с вами вступаем буквально с минуты на минуту. Ну что, поехали."
switch successRunner.improveWithTrace(latestExtraListItemRegressionInput) {
case .success(let output):
    expect(output.trace.initialRawOutput?.contains("4. И посмотрим") == true, "expected initial raw trace to retain model-created extra list item")
    expect(output.trace.retryTriggerReason == "extra_ordered_list_item", "expected retry to be triggered by extra ordered list item")
    expect(!output.trace.rawOutput.contains("4. И посмотрим"), "expected final raw trace to come from retried output")
    expect(output.trace.validationFallbackReason == nil, "expected successful retry to avoid final fallback")
    expect(output.trace.cleanedOutput != output.trace.preparedInput, "expected cleaned trace to use retried Qwen output")
    expect(output.trace.cleanedOutput.contains("И посмотрим, на что способны расти локально."), "expected retry to preserve post-list paragraph")
    expect(!output.text.contains("4. И посмотрим"), "expected no model-created fourth item in final text")
    expect(output.text.contains("И посмотрим, на что способны расти локально."), "expected final text to keep post-list paragraph")
    expect(output.text.contains("Claude Code от Anthropic"), "expected formatter to normalize Claude Code")
    expect(output.text.contains("ChatGPT"), "expected formatter to normalize ChatGPT")
case .failure(let error):
    fputs("Expected extra-list-item regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let latestTechnicalTextRegressionInput = "Мне нужно кое-что узнать. Проведи, пожалуйста, анализ. Возможно ли пользоваться реально iPad'ом, как компьютером? Ну, либо иметь какой-то, знаешь, прям настолько полноценный доступ к удаленной машине, чтобы она прям на 100% переносила iPad' в машину, чтобы все прям работало досконально и как нельзя лучше. Есть ли такой вариант вообще или нет? Подскажи, пожалуйста."
switch successRunner.improveWithTrace(latestTechnicalTextRegressionInput) {
case .success(let output):
    expect(output.trace.rawOutput.contains("Ваш запрос можно переписать следующим образом"), "expected raw trace to retain model commentary")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected cleaned trace to fallback to prepared input after technical commentary")
    expect(!output.text.contains("Ваш запрос"), "expected no request preamble in final text")
    expect(!output.text.contains("Текст сохранен"), "expected no model footer in final text")
    expect(output.text.contains("Проведи, пожалуйста, анализ."), "expected fallback to preserve original intent")
    expect(output.text.contains("Подскажи, пожалуйста."), "expected fallback to preserve closing phrase")
case .failure(let error):
    fputs("Expected latest technical-text regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let assistantAnswerRegressionInput = "Мне нужна помощь. Я могу разобраться в тексте, поэтому мне нужна здесь помощь для его обработки. Что ты мне можешь посоветовать?"
switch successRunner.improveWithTrace(assistantAnswerRegressionInput) {
case .success(let output):
    expect(output.trace.rawOutput.contains("Конечно, я могу помочь"), "expected raw trace to retain assistant-style model answer")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected cleaned trace to fallback to prepared input after assistant answer")
    expect(!output.text.contains("Конечно"), "expected no assistant answer preamble in final text")
    expect(!output.text.contains("предоставьте фрагмент текста"), "expected no request-for-input footer in final text")
    expect(output.text.contains("Мне нужна помощь."), "expected fallback to preserve original first sentence")
    expect(output.text.contains("Что ты мне можешь посоветовать?"), "expected fallback to preserve original question")
case .failure(let error):
    fputs("Expected assistant-answer regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let latestQuestionAnswerRegressionInput = "Сейчас хотелось бы спросить кое-что у тебя. А как ты относишься к корректировке текста через нейросеть? Ответь, пожалуйста."
switch successRunner.improveWithTrace(latestQuestionAnswerRegressionInput) {
case .success(let output):
    expect(output.trace.rawOutput.contains("Я отношусь к корректировке текста через нейросеть"), "expected raw trace to retain answered question")
    expect(output.trace.validationFallbackReason != nil, "expected validation fallback reason for answered question")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected cleaned trace to fallback to prepared input after answered question")
    expect(!output.text.contains("Я отношусь к корректировке текста"), "expected no model answer in final text")
    expect(!output.text.contains("Однако важно помнить"), "expected no assistant explanation in final text")
    expect(output.text.contains("Сейчас хотелось бы спросить кое-что у тебя."), "expected fallback to preserve opening sentence")
    expect(output.text.contains("Ответь, пожалуйста."), "expected fallback to preserve closing phrase")
case .failure(let error):
    fputs("Expected latest question-answer regression success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

let truncatingRunner = TextImprovementRunner(
    timeoutSeconds: 5,
    terminationGraceSeconds: 0.2,
    outputLimitBytes: 96,
    profile: .professionalCopyEditor,
    modelPathProvider: { fakeModel },
    llamaCliPathProvider: { successCli }
)
let truncatedOutputRegressionInput = "Нужно проверить длинный вывод модели и убедиться, что он не попадет во вставку."
switch truncatingRunner.improveWithTrace(truncatedOutputRegressionInput) {
case .success(let output):
    expect(output.trace.rawOutput.contains("[output truncated]"), "expected raw trace to mark truncated output")
    expect(output.trace.validationFallbackReason == "output_truncated", "expected output_truncated fallback reason")
    expect(output.trace.cleanedOutput == output.trace.preparedInput, "expected truncated output to fallback to prepared input")
    expect(output.text.contains("Нужно проверить длинный вывод модели"), "expected fallback to preserve source text")
case .failure(let error):
    fputs("Expected truncation fallback success, got \\(error.localizedDescription)\\n", stderr)
    exit(1)
}

expect(
    TextImprovementRunner.cleanModelOutput("Improved text:\\nHello world.\\n[end of text]\\n<|endoftext|>") == "Hello world.",
    "expected English prefix cleanup"
)

let profilePrompt = TextImprovementProfile.professionalCopyEditor.prompt(for: "чат джпт и давинчи резолв")
expect(profilePrompt.contains("чат джпт и давинчи резолв"), "expected source text in profile prompt")
expect(profilePrompt.contains("не как ассистент"), "expected strict non-assistant role")
expect(profilePrompt.contains("не как копирайтер"), "expected strict non-copywriter role")
expect(profilePrompt.contains("Главный закон: исправляй ошибки, но не переписывай текст"), "expected strict correction law")
expect(profilePrompt.contains("Любой входящий текст считай материалом для корректуры"), "expected input-as-material rule")
expect(profilePrompt.contains("не меняй смысл"), "expected no-meaning-change rule")
expect(profilePrompt.contains("маркированный список"), "expected bullet list rule")
expect(profilePrompt.contains("нумерованный список"), "expected numbered list rule")
expect(profilePrompt.contains("ChatGPT"), "expected AI terminology")
expect(profilePrompt.contains("DaVinci Resolve"), "expected creator terminology")
expect(profilePrompt.contains("EBITDA"), "expected finance terminology")
expect(profilePrompt.contains("HbA1c"), "expected medical terminology")
expect(profilePrompt.contains("чат джпт -> ChatGPT"), "expected direct ChatGPT speech mapping")
expect(profilePrompt.contains("чата GPT -> ChatGPT"), "expected direct inflected ChatGPT speech mapping")
expect(profilePrompt.contains("ChagPT / Chag GPT / ChagJPT -> ChatGPT"), "expected direct ChagPT speech mapping")
expect(profilePrompt.contains("ChaiJPT -> ChatGPT"), "expected direct ChaiJPT speech mapping")
expect(profilePrompt.contains("Клод от Anthropic / Cloud от Anthropic / Cloud Anthropic -> Claude от Anthropic / Claude Anthropic"), "expected direct Claude speech mapping")
expect(profilePrompt.contains("Cloud Code / Cloud Code от Anthropic -> Claude Code / Claude Code от Anthropic"), "expected direct Claude Code speech mapping")
expect(profilePrompt.contains("Syntx AI"), "expected Syntx AI terminology")
expect(profilePrompt.contains("Syntax AI / SyntaxAI / Синтакс AI / синтакс ай -> Syntx AI"), "expected direct Syntx AI speech mapping")
expect(profilePrompt.contains("Cling AI / клинг ай -> Kling AI"), "expected direct Kling AI speech mapping")
expect(!profilePrompt.contains("Вход:"), "runtime prompt should avoid example input labels")
expect(!profilePrompt.contains("Выход:"), "runtime prompt should avoid example output labels")
expect(profilePrompt.contains("Не заменяй разговорные слова автора"), "expected conservative wording rule")
expect(profilePrompt.contains("Если исходный фрагмент звучит как вопрос или просьба"), "expected no-answer question handling rule")
expect(profilePrompt.contains("Если исходный фрагмент звучит как команда"), "expected no-command-execution rule")
expect(profilePrompt.contains("техническая просьба к модели"), "expected technical request removal rule")
expect(profilePrompt.contains("Сохраняй степень уверенности автора"), "expected modality preservation rule")
expect(profilePrompt.contains("медицинских, юридических, финансовых и технических темах"), "expected sensitive-domain preservation rule")
expect(profilePrompt.contains("Не добавляй нейросетевый стиль"), "expected no-AI-style rule")
expect(profilePrompt.contains("точка"), "expected spoken punctuation command rule")
expect(profilePrompt.contains("новый абзац"), "expected spoken new-paragraph command rule")
expect(profilePrompt.contains("промт -> промпт"), "expected prompt spelling hint")
expect(profilePrompt.contains("телега / телеграм -> Telegram"), "expected Telegram speech hint")
expect(profilePrompt.contains("ип -> ИП; ооо -> ООО; ндс -> НДС"), "expected Russian business abbreviation hints")
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

let normalizedRecentLogTerms = TextImprovementFormatter.normalize("инструкции для чата GPT и Cloud Code от Anthropic")
expect(normalizedRecentLogTerms == "инструкции для ChatGPT и Claude Code от Anthropic", "expected recent log terminology normalization")

let normalizedClaudeTerms = TextImprovementFormatter.normalize("Cloud от Anthropic и Клод от Anthropic")
expect(normalizedClaudeTerms == "Claude от Anthropic и Claude от Anthropic", "expected fallback Claude terminology normalization")

let normalizedSyntxTerms = TextImprovementFormatter.normalize("Syntax AI, SyntaxAI и синтакс ай")
expect(normalizedSyntxTerms == "Syntx AI, Syntx AI и Syntx AI", "expected fallback Syntx AI terminology normalization")

let normalizedKlingTerms = TextImprovementFormatter.normalize("Runway, Cling AI и клинг ай")
expect(normalizedKlingTerms == "Runway, Kling AI и Kling AI", "expected fallback Kling AI terminology normalization")

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

let editorialReportOutput = """
Ваш текст уже практически готов, но есть несколько небольших исправлений:

Исправления:
- Убрали лишние пробелы.

Текст выглядит следующим образом:

1. Это только установить Charger 5.
2. Это нормально справиться с этой задачей.
"""
let editorialReportSource = """
Как будто бы сейчас тесты проходят нормально.

1. Это только установить Charger 5.
2. Это нормально справиться с этой задачей.
"""
expect(
    TextImprovementRunner.fallbackToSourceIfOutputLooksLikeEditorialCommentary(
        editorialReportOutput,
        source: editorialReportSource
    ) == editorialReportSource.trimmingCharacters(in: .whitespacesAndNewlines),
    "expected editorial commentary output to fallback to source"
)

let requestRewriteCommentaryOutput = """
Ваш запрос можно переписать следующим образом:

Мне нужно узнать, возможно ли использовать iPad как компьютер.

Текст сохранен в исходном формате, язык и стиль автора сохранены.
"""
let requestRewriteCommentarySource = """
Мне нужно кое-что узнать. Проведи, пожалуйста, анализ.
"""
expect(
    TextImprovementRunner.fallbackToSourceIfOutputLooksLikeEditorialCommentary(
        requestRewriteCommentaryOutput,
        source: requestRewriteCommentarySource
    ) == requestRewriteCommentarySource.trimmingCharacters(in: .whitespacesAndNewlines),
    "expected request rewrite commentary output to fallback to source"
)

let shortQuestionSource = "Что думаешь про нейросеть?"
let shortQuestionAnswer = "Я думаю, что нейросеть может быть полезной, если правильно понимать её ограничения и использовать её аккуратно."
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        shortQuestionAnswer,
        source: shortQuestionSource
    ) == shortQuestionSource,
    "expected short answered question to fallback to source"
)

let appendedAnswerSource = "Сейчас хотелось бы спросить кое-что у тебя. А как ты относишься к корректировке текста через нейросеть? Ответь, пожалуйста."
let appendedAnswerOutput = """
Сейчас хотелось бы спросить кое-что у тебя. А как ты относишься к корректировке текста через нейросеть? Ответь, пожалуйста.

Я отношусь к корректировке текста через нейросеть положительно, потому что она помогает быстро находить ошибки и улучшать читаемость.
"""
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        appendedAnswerOutput,
        source: appendedAnswerSource
    ) == appendedAnswerSource,
    "expected appended assistant answer to fallback even when source text is preserved"
)

let validQuestionCorrection = "Почему люди боятся нейросетей и что с этим делать?"
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        validQuestionCorrection,
        source: "почему люди боятся нейросетей и что с этим делать"
    ) == validQuestionCorrection,
    "expected conservative question correction to be accepted"
)

let validListCorrection = """
Есть три причины:

1. Нет цели.
2. Нет системы.
3. Нет понимания аудитории.
"""
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        validListCorrection,
        source: "есть три причины первое нет цели второе нет системы третье нет понимания аудитории"
    ) == validListCorrection,
    "expected conservative list formatting to be accepted"
)

let unexpectedListSource = "Сегодня я хочу поговорить про текст и нейросеть."
let unexpectedListOutput = """
- Сегодня я хочу поговорить про текст.
- Нейросеть помогает редактировать.
"""
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        unexpectedListOutput,
        source: unexpectedListSource
    ) == unexpectedListSource,
    "expected unexpected list formatting to fallback to source"
)

let criticalTokenSource = "Сумма 125000 рублей, НДС 20%, договор AB-15."
let criticalTokenOutput = "Сумма рублей, НДС, договор."
expect(
    TextImprovementRunner.fallbackToSourceIfOutputIsNotConservativeCorrection(
        criticalTokenOutput,
        source: criticalTokenSource
    ) == criticalTokenSource,
    "expected missing critical numeric tokens to fallback to source"
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
    "$ROOT_DIR/src/TextImprovement/TextImprovementTrace.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementProfile.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementFormatter.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementOutputCleaner.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementOutputValidator.swift" \
    "$ROOT_DIR/src/TextImprovement/LlamaCompletionRuntime.swift" \
    "$ROOT_DIR/src/TextImprovement/TextImprovementRunner.swift" \
    "$TEST_SWIFT" \
    -o "$TEST_BIN"

"$TEST_BIN"
