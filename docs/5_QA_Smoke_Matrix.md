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
| Hung / stderr-heavy `whisper-cli` subprocess | зависший процесс завершается timeout diagnostic, temp audio чистится; большой `stderr` не блокирует успешный subprocess | Verified by `scripts/test_whisper_runner_timeout.sh` |
| Text improvement model missing | toggle/manual action открывает downloader; automatic dictation не ломается без `.gguf` | Compile-level only |
| Text improvement runtime missing | app показывает `llama.cpp` diagnostic для второй нейросети, базовая диктовка остается доступной | Compile-level only |
| Hung / stderr-heavy llama.cpp subprocess | зависший процесс завершается timeout diagnostic; большой `stdout`/`stderr` не блокирует runner | Verified by `scripts/test_text_improvement_runner.sh` |
| Long text improvement input | input > 6 000 символов не отправляется в Qwen и fallback-ится без silent truncation | Verified by `scripts/test_text_improvement_runner.sh` |
| Real Qwen short correction | локальная Qwen GGUF исправляет короткий русский текст через `TextImprovementRunner` | Verified locally with Homebrew `llama.cpp` + downloaded GGUF |
| Transcription fail | user видит различимую диагностическую ошибку | Compile-level only |
| Paste fail | отображается локально различимая ошибка вставки | Compile-level only |
| Payment initiated via site/app path | `uid` / pricing path совпадают с current product contract | Backend/web smoke verified in Sprint 1 |

## Notes

- Этот документ описывает минимум smoke coverage, а не полный regression plan.
- `Verified locally` обязан обновляться после реального runtime smoke, а не только после typecheck/build.
