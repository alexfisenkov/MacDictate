# MacDictate v1.5.0-working

## Status

- Status: `working_line`
- Branch: `release/1.5.0`
- Current HEAD at registry creation: `9c138a794135e564d49ac2f03d179bf75ae5e974`
- Bundle remains: `1.4.2` / build `9`
- Public Release: not released

## Summary

Активная линия разработки для следующего desktop-релиза. Она уже включает backend checkout hardening, license state machine, bounded offline grace, runtime diagnostics, app-layer modularization и release governance foundation.

## Current Working-Line Hardening

- Release ledger/govеrnance введен как обязательный pre-release контур, но `v1.5.0-working` не имеет release asset.
- `WhisperRunner` получил bounded 30-минутный timeout для зависшего `whisper-cli` и streaming drain `stderr`; сценарии покрыты локальным harness `scripts/test_whisper_runner_timeout.sh`.
- `LicenseService` получил bounded machine ID command timeout, а `RecordingService` чистит stale temp audio; сценарии покрыты локальными harness scripts.
- Добавлен optional second-AI text improvement layer: preferred Qwen2.5-3B-Instruct Q4_K_M через `llama.cpp` runtime с fallback на Qwen2.5-1.5B-Instruct Q4_K_M, меню `Улучшить текст`, persisted toggle и downloader `.gguf` модели.
- Qwen prompt теперь строится через `TextImprovementProfile.professionalCopyEditor`: правила сохранения смысла, оформление абзацев/списков, доменные терминологические пакеты и speech-normalization hints.
- После Qwen применяется `TextImprovementFormatter` как guardrail для очевидных ordered-list markers и частых терминов, когда локальная модель оставляет их неоформленными.
- `TextImprovementRunner` имеет bounded timeout, streaming drain `stdout`/`stderr`, safe input limit `6_000` символов и fallback semantics; покрыт `scripts/test_text_improvement_runner.sh`.
- Реальный local smoke Qwen на M1 выполнен: `qwen2.5-1.5b-instruct-q4_k_m.gguf` скачан полностью (`1,117,320,736` bytes), короткий русский текст исправлен через `TextImprovementRunner`.
- Preferred 3B-модель выбрана для текущей рабочей линии как промежуточный вариант между качеством и ресурсами M1/16 GB: 7B убрана из default-пути после runtime-risk сигнала, 1.5B остается fallback; runtime selection покрыт fallback-тестом, а отдельный real 3B smoke фиксируется после завершения загрузки модели.
- Добавлен opt-in local debug session logging: при включенном `MacDictateDebugSessionLoggingEnabled` диктовка сохраняет `audio.wav`, Whisper raw/cleaned text, Qwen prompt/raw/cleaned/final output, финальный inserted text и `events.jsonl` в `~/.macdictate/debug-sessions/`; покрыто `scripts/test_debug_session_logger.sh`.
- Добавлен `docs/8_AI_Corpus_Strategy.md`: будущий fine-tune/eval второй нейросети должен опираться на утвержденные real dictation correction pairs, а не на рекламные generation datasets как базовое поведение.
- По debug-сессии длинной диктовки усилен text-improvement pipeline: deterministic pre-formatting теперь исправляет `ChaiJPT`/`Чай и GPT` в `ChatGPT` и превращает heading cue + `во-первых/во-вторых/в-третьих` в numbered list до отправки текста в Qwen.
- Локальные DMG/build logs остаются ignored artifacts; clean checkout проверка governance допускает их отсутствие, строгая локальная проверка доступна через `scripts/verify_release_governance.sh --strict-local-artifacts`.

## Release Rule

`v1.5.0` нельзя считать выпущенной, пока не будут выполнены:

- version bump в `assets/Info.plist`;
- обновление `CHANGELOG.md`;
- обновление `releases/registry.json`;
- заполнение финального `releases/versions/v1.5.0/RELEASE.md`;
- прохождение `scripts/verify_release_governance.sh`;
- сборка `./build.sh`;
- smoke matrix;
- annotated tag `v1.5.0`;
- GitHub Release с DMG asset.
