# MacDictate v1.5.0

## Status

- Status: `public_stable`
- Bundle: `1.5.0` / build `10`
- Git tag: `v1.5.0`
- Git commit: recorded in `releases/registry.json` after tag creation
- GitHub Release: `https://github.com/alexfisenkov/MacDictate/releases/tag/v1.5.0`

## Summary

Публичный desktop-релиз `1.5.0`. Главная цель версии — сделать компьютерную MacDictate устойчивее как продукт: закрыть зависания Whisper, укрепить лицензирование и диагностику, ввести release governance и добавить optional локальное улучшение текста второй нейросетью.

## Highlights

- `WhisperRunner` больше не может ждать `whisper-cli` бесконечно: transcription subprocess ограничен 30 минутами, читает `stderr` streaming-режимом и корректно чистит временные файлы.
- Licensing layer получил bounded machine ID lookup, tolerant status decoder, 20-секундный request timeout и более спокойную обработку transient license-server failures при валидном cached grace.
- App-layer разложен по ответственностям: license, diagnostics, hotkeys, transcription, paste, UI и text improvement вынесены из прежнего монолитного controller-пути.
- Добавлена optional вторая локальная нейросеть для исправления и оформления текста после Whisper: preferred Qwen2.5-3B-Instruct Q4_K_M через `llama.cpp` с fallback на Qwen2.5-1.5B-Instruct Q4_K_M.
- Text improvement получил строгий correction profile, terminology normalization, deterministic formatter, fail-closed validator и controlled retry для исправимых ошибок Qwen output.
- Добавлен opt-in debug session logging для локального анализа качества диктовки: аудио, Whisper raw/cleaned, Qwen prompt/raw/cleaned/final, final inserted text и events.
- Введен release ledger: `releases/registry.json`, per-version `RELEASE.md`, artifact manifests и governance checks.

## Verification

- `scripts/verify_release_governance.sh`
- `scripts/test_whisper_runner_timeout.sh`
- `scripts/test_license_machine_id_timeout.sh`
- `scripts/test_license_status_response.sh`
- `scripts/test_license_grace_diagnostic.sh`
- `scripts/test_recording_temp_cleanup.sh`
- `scripts/test_text_improvement_runner.sh`
- `scripts/test_debug_session_logger.sh`
- `swiftc -typecheck $(find src -name '*.swift' | sort)`
- `node --check backend/server.js && node --check backend/db.js`
- `plutil -lint assets/Info.plist`
- `./build.sh`
- `codesign --verify --deep --strict /Applications/MacDictate.app`

## Known Limitations

- Distribution still uses ad-hoc signing. Developer ID signing, notarization and stapling remain P0 release debt.
- Whisper and llama.cpp runtimes are still expected from Homebrew paths.
- Text improvement is optional and bounded: input over `6_000` characters falls back instead of chunking.
- Debug session logs are local and sensitive; user-facing retention/cleanup controls remain future work.

