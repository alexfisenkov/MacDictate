# Scripts

## `verify_release_governance.sh`

Проверяет, что desktop release registry, per-version folders, локальные артефакты, checksums, `Info.plist` и обязательные git tags не расходятся.

Скрипт также запрещает:

- папки `releases/versions/<version>/` без записи в `releases/registry.json`;
- записи в registry без одноименной version-папки;
- имена версий вне разрешенного формата;
- `working_line` без суффикса `-working`;
- публичные релизы с `-local` или `-working`;
- `RELEASE.md` без совпадающего `Status`;
- новый DMG/build log в корне `macos/`.

Локальная проверка:

```bash
scripts/verify_release_governance.sh
```

Проверка с GitHub Releases API:

```bash
scripts/verify_release_governance.sh --online
```

Строгая локальная проверка ignored DMG/build logs:

```bash
scripts/verify_release_governance.sh --strict-local-artifacts
```

GitHub Actions gate:

```text
.github/workflows/release-governance.yml
```

## `test_whisper_runner_timeout.sh`

Компилирует `WhisperRunner` с fake `whisper-cli` и проверяет, что transcription timeout возвращает диагностическую ошибку, останавливает subprocess, чистит temp audio и не блокируется на большом `stderr`.

```bash
scripts/test_whisper_runner_timeout.sh
```

## `test_whisper_model_selection.sh`

Компилирует `ModelLocator` и проверяет выбор ASR-модели: balanced mode предпочитает `large-v3-turbo`, maximumAccuracy mode предпочитает `large-v3`, а fallback между валидными `.bin` моделями сохраняется.

```bash
scripts/test_whisper_model_selection.sh
```

## `test_free_desktop.sh`

Проверяет отсутствие licensing-зависимостей в активном source, компилирует все app sources и создает реальное `NSMenu`: в нем нет license/trial/payment, при нормальной среде статус `Ready`, а microphone denial и runtime errors остаются видимыми. Live запись и системные permission prompts проверяются отдельно.

```bash
scripts/test_free_desktop.sh
```

Исторические `test_license_machine_id_timeout.sh`, `test_license_status_response.sh` и `test_license_grace_diagnostic.sh` сохранены в `archive/legacy-licensing/scripts/` вместе с прежним licensing-кодом. Они не входят в проверки текущего desktop.

## `test_recording_temp_cleanup.sh`

Компилирует `RecordingService` и проверяет cleanup stale temp WAV/TXT.

```bash
scripts/test_recording_temp_cleanup.sh
```

## `test_text_improvement_runner.sh`

Компилирует `TextImprovementRunner` с fake llama.cpp executable и проверяет editor profile prompt content, formatter guardrails, success output cleanup, missing model/runtime, safe input limit, non-zero diagnostics, timeout recovery и drain большого `stderr`.

```bash
scripts/test_text_improvement_runner.sh
```

## `test_llama_runtime_locator.sh`

Компилирует `LlamaRuntimeLocator` и проверяет порядок поиска runtime второй нейросети: bundled `llama-completion`, bundled `llama-cli`, затем developer fallback paths.

```bash
scripts/test_llama_runtime_locator.sh
```

## `bundle_llama_runtime.py`

Сборочный helper для `build.sh`: копирует локальный `llama-completion`/`llama-cli` в `MacDictate.app/Contents/Resources/bin`, собирает transitive `.dylib` dependencies в `Contents/Resources/lib/llama`, копирует ggml backend plugins в `Contents/Resources/libexec/ggml-llama` и переписывает install names на bundle-relative `@rpath`.

Обычно запускается только через `./build.sh`.

## `bundle_whisper_runtime.py`

Сборочный helper для `build.sh`: копирует локальный `whisper-cli` в `MacDictate.app/Contents/Resources/bin`, собирает transitive `.dylib` dependencies в `Contents/Resources/lib/whisper`, копирует ggml backend plugins в `Contents/Resources/libexec/ggml-whisper` и переписывает install names на bundle-relative `@rpath`.

Обычно запускается только через `./build.sh`.

## `build_clean_runtimes.sh`

Собирает clean `llama-completion` и `whisper-cli` из upstream source tarballs под `MACDICTATE_RUNTIME_DEPLOYMENT_TARGET` (по умолчанию `11.0`) без Homebrew-linked runtime dependencies. Скрипт нужен перед release-style сборкой, если локальный Homebrew уже собран под слишком новый macOS SDK/minos.

```bash
scripts/build_clean_runtimes.sh
```

После успешной сборки скрипт печатает `MACDICTATE_LLAMA_RUNTIME_PATH`, `MACDICTATE_LLAMA_GGML_BACKEND_PATH`, `MACDICTATE_WHISPER_RUNTIME_PATH` и `MACDICTATE_WHISPER_GGML_BACKEND_PATH` для `./build.sh`.

## `check_bundled_llama_runtime.sh`

Проверяет собранный `.app`: bundled llama runtime должен быть arm64, подписан, запускаться без `dyld` ошибок и не ссылаться на Homebrew/local install paths.

```bash
scripts/check_bundled_llama_runtime.sh build/MacDictate.app
```

## `check_bundled_whisper_runtime.sh`

Проверяет собранный `.app`: bundled whisper runtime, dylibs и ggml backend plugins должны быть arm64/Mach-O, подписаны, запускаться без `dyld` ошибок и не ссылаться на Homebrew/local install paths.

```bash
scripts/check_bundled_whisper_runtime.sh build/MacDictate.app
```

## `check_install_artifact_flow.sh`

Проверяет финальный пользовательский DMG как установочный артефакт: принимает EULA для `hdiutil`, монтирует образ, проверяет `MacDictate.app` внутри DMG, копирует его во временную `Applications`-папку и повторно валидирует strict codesign, microphone entitlement и bundled whisper/llama runtimes.

```bash
scripts/check_install_artifact_flow.sh build/artifacts/MacDictate_Final_v1.5.2.dmg
```

## `test_debug_session_logger.sh`

Компилирует `DebugSessionLogger` и проверяет opt-in debug session folder, `metadata.json` без machine ID, `events.jsonl`, `audio.wav`, staged text artifacts и disabled-mode no-op.

```bash
scripts/test_debug_session_logger.sh
```

## `test_last_dictation_store.sh`

Компилирует `LastDictationStore` и проверяет, что последняя диктовка сохраняется локально, пустой текст не затирает сохранённое значение, текст переживает пересоздание store и может быть очищен.

```bash
scripts/test_last_dictation_store.sh
```

## `test_free_access_backend.py`

Проверяет реальные free HTTP routes на временной SQLite БД: активный бессрочный legacy доступ, пустые тарифы, HTTP410 для новых оплат и отсутствие device/order writes.
