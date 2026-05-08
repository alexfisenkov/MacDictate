# Архитектура проекта MacDictate (Native Swift)

Этот документ описывает текущую app-side архитектуру `1.5.0` после декомпозиции `AppController.swift`.

## Технологический стек

- **Ядро:** нативный Swift + AppKit, сборка через `swiftc`.
- **Speech-to-text:** `whisper-cli` (Whisper.cpp), запускается как внешний процесс.
- **Text improvement:** `llama.cpp` (`llama-completion`, fallback search включает `llama-cli`) + `Qwen2.5-1.5B-Instruct-GGUF` Q4_K_M, запускается как второй локальный CLI-процесс.
- **Сборка:** `build.sh`, который рекурсивно собирает все `.swift` в `src/`.
- **Упаковка:** DMG через `create-dmg`.

## Entry / Lifecycle

- `src/main.swift` — entry point.
- `src/AppDelegate.swift` — lifecycle bootstrap, проверка модели и показ `ModelDownloader`.
- `src/ModelDownloader.swift` — downloader для Whisper model и optional Qwen text-improvement model.

## App Composition Root

- `src/AppController.swift` — тонкий coordinator.
- Его ответственность: собрать сервисы, построить menu bar UI, связать hotkeys с use case и держать high-level orchestration.

## App Modules

- `src/License/*`
  - `LicenseState.swift` — state model (`checking`, `active`, `grace`, `expired`, `serverUnavailable`).
  - `LicenseSnapshot.swift` — кэшируемый snapshot и network response model.
  - `LicenseCache.swift` — bounded offline grace cache.
  - `LicenseService.swift` — machine ID с bounded `ioreg` timeout, `/api/license/status`, refresh loop, state transitions.

- `src/Diagnostics/*`
  - `DiagnosticStatus.swift` — типы diagnostic/event state.
  - `EnvironmentDiagnostics.swift` — проверки accessibility, microphone, model и `whisper-cli`.

- `src/Hotkeys/*`
  - `HotkeyMonitor.swift` — double `Option` start и single `Option` stop.

- `src/Transcription/*`
  - `ModelLocator.swift` — typed lookup: Whisper `.bin` отдельно, text-improvement `.gguf` отдельно.
  - `RecordingService.swift` — cleanup stale temp audio и запись WAV.
  - `WhisperRunner.swift` — запуск `whisper-cli`, timeout `30` минут, streaming drain `stderr`, controlled termination, cleanup temp files, различимые ошибки.

- `src/TextImprovement/*`
  - `TextImprovementSettings.swift` — persisted toggle `MacDictateTextImprovementEnabled`.
  - `TextImprovementRunner.swift` — запуск `llama.cpp` runtime для Qwen, timeout `5` минут, streaming drain `stdout`/`stderr`, controlled termination и fallback-friendly ошибки.

- `src/Paste/*`
  - `PasteService.swift` — pasteboard write / restore и simulated `Cmd+V`.

- `src/UI/*`
  - `StatusPresentation.swift` — user-facing строки и status summaries.
  - `MenuBuilder.swift` — сборка menu skeleton.

## Поведенческие правила app-layer

- Меню остается `menu bar utility`, без отдельного большого окна настроек.
- Горячая клавиша не меняется: double `Option` старт, `Option` во время записи стоп.
- Backend contract не меняется: app продолжает читать `GET /api/license/status`.
- Offline grace ограничен и больше не является бесконечным fail-open.
- Machine ID resolution не должен блокировать startup бесконечно: `/usr/sbin/ioreg` ограничен коротким timeout, fallback генерирует и кеширует `MD-*`.
- Transcription subprocess не должен блокировать app бесконечно: зависший `whisper-cli` завершается после timeout и возвращает runtime diagnostic.
- `stderr` subprocess читается во время выполнения, чтобы verbose/error-heavy `whisper-cli` не мог заблокироваться на заполненном pipe.
- Text improvement является optional enhancement, а не блокером базовой диктовки. Если Qwen/`llama.cpp` runtime отсутствует или падает при включенном toggle, app вставляет cleaned Whisper-текст и показывает warning diagnostic.
- Вторая модель хранится только как `qwen2.5-1.5b-instruct-q4_k_m.gguf`; `.gguf` не участвует в выборе Whisper model.
- Для защиты от silent truncation Qwen-улучшение ограничено короткими/средними фрагментами: input больше `6_000` символов fallback-ится к исходному cleaned Whisper text.
- Ручная команда `Улучшить текст` работает с текстом из буфера обмена и вставляет улучшенный результат через существующий `PasteService`.

## Build note

`build.sh` должен оставаться совместимым с модульной структурой: при добавлении новых `.swift` файлов они должны подхватываться автоматически, а не вручную дописываться в один список.

## Local Verification Notes

- `scripts/test_whisper_runner_timeout.sh` компилирует `WhisperRunner` с fake `whisper-cli` и проверяет timeout recovery, cleanup temp audio и large-stderr subprocess path.
- `scripts/test_license_machine_id_timeout.sh` проверяет parsing/cache machine ID и fallback при зависшем fake `ioreg`.
- `scripts/test_recording_temp_cleanup.sh` проверяет cleanup stale temp WAV/TXT.
- `scripts/test_text_improvement_runner.sh` компилирует `TextImprovementRunner` с fake llama.cpp executable и проверяет success cleanup, timeout recovery, missing runtime/model, safe input limit и non-zero stderr diagnostics.
