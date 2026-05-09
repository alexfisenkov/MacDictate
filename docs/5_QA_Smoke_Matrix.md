# QA Smoke Matrix

| Scenario | Expected result | Verified locally |
| --- | --- | --- |
| First launch with model present | `AppDelegate` пропускает downloader и запускает app | Partially |
| First launch without model | показывается `ModelDownloader` | Not in this iteration |
| No model at runtime | menu/diagnostics показывают `Model Not Found`, запись не стартует | Compile-level only |
| No `whisper-cli` | diagnostics показывают `whisper-cli Not Found`, transcription не запускается | Compile-level only |
| No microphone permission | статус/alerts ведут в privacy settings, запись не стартует | Not runtime-verified |
| No accessibility permission | hotkey blocked, показан accessibility guidance | Not runtime-verified |
| Stale temp audio/text at startup | `RecordingService` удаляет старые `/tmp/mac_dictate_dist.wav` и `.txt` | Verified by `scripts/test_recording_temp_cleanup.sh` |
| License `checking` | double Option не стартует запись, false paywall не показывается | Compile-level only |
| Machine ID command hangs | startup machine ID resolution быстро уходит в generated cached `MD-*` fallback | Verified by `scripts/test_license_machine_id_timeout.sh` |
| License `active` | запись разрешена при нормальной среде | Not runtime-verified |
| License `grace` | запись разрешена до bounded deadline | Compile-level only |
| License `expired` | запись блокируется, доступна ссылка на оплату | Compile-level only |
| License server unavailable | при валидном snapshot включается grace, без snapshot запись блокируется | Compile-level only |
| License status boolean compatibility | live/legacy backend values `true/false`, `1/0` и boolean-like strings декодируются без false `serverUnavailable` | Verified by `scripts/test_license_status_response.sh` and live endpoint curl |
| License transient failure with cached active snapshot | при сетевом сбое и валидном snapshot app остается в grace без runtime-warning `Сервер лицензий временно недоступен`; без cache warning сохраняется | Verified by `scripts/test_license_grace_diagnostic.sh` |
| Hung / stderr-heavy `whisper-cli` subprocess | зависший процесс завершается timeout diagnostic, temp audio чистится; большой `stderr` не блокирует успешный subprocess | Verified by `scripts/test_whisper_runner_timeout.sh` |
| Text improvement model missing | toggle/manual action открывает downloader; automatic dictation не ломается без `.gguf` | Compile-level only |
| Text improvement model selection | preferred 3B `.gguf` выбирается раньше legacy 1.5B; undersized 3B игнорируется; 1.5B остается fallback | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement runtime missing | app показывает `llama.cpp` diagnostic для второй нейросети, базовая диктовка остается доступной | Compile-level only |
| Hung / stderr-heavy llama.cpp subprocess | зависший процесс завершается timeout diagnostic; большой `stdout`/`stderr` не блокирует runner | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement editor profile | prompt содержит запрет менять смысл, правила абзацев/списков и доменные термины для Qwen | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement strict correction profile | runtime prompt описывает вторую модель как строгого корректора после Whisper: не ассистент, не копирайтер, не отвечает на вопросы, не выполняет команды, сохраняет модальность и не добавляет нейросетевый стиль | Verified by `scripts/test_text_improvement_runner.sh` and user instruction set `ДЛЯ_КОРРЕКТУРЫ_ПОСЛЕ_WHISPER` v3.2 |
| Text improvement formatter guardrail | явные `во-первых/во-вторых` перечисления превращаются в numbered list; частые термины нормализуются | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement real debug regression | `ChaiJPT`/`ChagPT` нормализуются в `ChatGPT`, `Клод от Anthropic` нормализуется в `Claude от Anthropic`, heading cues становятся heading с двоеточием, ordered markers превращаются в numbered list без лишней точки | Verified by `scripts/test_text_improvement_runner.sh` and real Qwen local smoke |
| Text improvement conjunction list markers | речевые маркеры `и второе` / `и третье` считаются частью ordered-list marker и не оставляют хвост `И.` в предыдущем пункте | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement prompt-scaffold leakage | runtime prompt не содержит `Вход` / `Выход` example labels; leaked `Выход:` scaffold вырезается; decorative Markdown снимается, если source был plain text | Verified by `scripts/test_text_improvement_runner.sh` and real Qwen 3B regression on `20260508-234719-983488DD` input |
| Text improvement model boilerplate cleanup | model preamble `Вот исправленный и отформатированный текст:` и standalone `---` lines не попадают в final inserted text | Verified by `scripts/test_text_improvement_runner.sh` and cleaner replay on `20260508-235835-D04967B7` raw output |
| Text improvement editorial report fallback | если Qwen добавляет служебный отчет `Ваш текст...` / `Исправления:` / `Текст выглядит следующим образом:`, final output fallback-ится к preformatted Whisper-тексту, а raw report остается в trace | Verified by `scripts/test_text_improvement_runner.sh` and regression from `20260509-015329-FDD8BE50` |
| Text improvement technical commentary fallback | если Qwen добавляет служебные preamble/footer markers вроде `Ваш запрос можно переписать следующим образом` или `Текст сохранен...`, final output fallback-ится к preformatted Whisper-тексту | Verified by `scripts/test_text_improvement_runner.sh` and regression from `20260509-133020-A9F21EE8` |
| Text improvement assistant-answer fallback | если Qwen отвечает на диктовку как чат-ассистент (`Конечно, я могу помочь...`, `Пожалуйста, предоставьте...`), final output fallback-ится к preformatted Whisper-тексту; prompt явно запрещает отвечать на вопросы | Verified by `scripts/test_text_improvement_runner.sh` and regression from `20260509-133902-9B87271C` |
| Text improvement answered-question validator | если Qwen отвечает на вопрос пользователя новым содержанием и теряет значимые source tokens, final output fallback-ится к preformatted Whisper-тексту даже без явных preamble markers | Verified by `scripts/test_text_improvement_runner.sh` and regression from `20260509-143346-EB6FDFDA` |
| Text improvement content-loss fallback | если Qwen существенно сокращает текст и теряет source tokens, final output fallback-ится к preformatted Whisper-тексту вместо вставки сжатого результата | Verified by `scripts/test_text_improvement_runner.sh` and regression from `20260509-093806-5B71CD3D` |
| Text improvement terminology: Syntx AI | `Syntax AI` / `SyntaxAI` / `Синтакс AI` / `синтакс ай` нормализуются в `Syntx AI` без замены обычного `syntax` вне AI-названия | Verified by `scripts/test_text_improvement_runner.sh` |
| Text improvement terminology: Kling AI | `Cling AI` / `Клинг AI` / `клинг ай` нормализуются в `Kling AI` | Verified by `scripts/test_text_improvement_runner.sh` |
| Long text improvement input | input > 6 000 символов не отправляется в Qwen и fallback-ится без silent truncation | Verified by `scripts/test_text_improvement_runner.sh` |
| Real Qwen short correction | локальная Qwen GGUF исправляет короткий русский текст через `TextImprovementRunner` | Verified locally with Homebrew `llama.cpp` + downloaded GGUF |
| Real Qwen editor profile smoke | Qwen + profile + formatter нормализуют `ChatGPT`, `Qwen`, `EBITDA`, `DaVinci Resolve` и оформляют `во-первых/во-вторых/в-третьих` как numbered list | Verified locally |
| Real Qwen 3B correction smoke | локальная Qwen2.5-3B Q4_K_M выбирается runtime и улучшает короткий русский текст через `TextImprovementRunner` | Verified locally after 3B download |
| Debug session logger opt-in | при включенном `MacDictateDebugSessionLoggingEnabled` создается локальная session folder с metadata, events, audio и staged text artifacts; при выключенном режиме logger no-op | Verified by `scripts/test_debug_session_logger.sh` |
| Transcription fail | user видит различимую диагностическую ошибку | Compile-level only |
| Paste fail | отображается локально различимая ошибка вставки | Compile-level only |
| Payment initiated via site/app path | `uid` / pricing path совпадают с current product contract | Backend/web smoke verified in Sprint 1 |

## Notes

- Этот документ описывает минимум smoke coverage, а не полный regression plan.
- `Verified locally` обязан обновляться после реального runtime smoke, а не только после typecheck/build.
