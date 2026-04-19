# Архитектура проекта MacDictate (Native Swift)

Этот документ описывает текущую app-side архитектуру `1.5.0` после декомпозиции `AppController.swift`.

## Технологический стек

- **Ядро:** нативный Swift + AppKit, сборка через `swiftc`.
- **Speech-to-text:** `whisper-cli` (Whisper.cpp), запускается как внешний процесс.
- **Сборка:** `build.sh`, который рекурсивно собирает все `.swift` в `src/`.
- **Упаковка:** DMG через `create-dmg`.

## Entry / Lifecycle

- `src/main.swift` — entry point.
- `src/AppDelegate.swift` — lifecycle bootstrap, проверка модели и показ `ModelDownloader`.
- `src/ModelDownloader.swift` — isolated first-run downloader для Whisper model.

## App Composition Root

- `src/AppController.swift` — тонкий coordinator.
- Его ответственность: собрать сервисы, построить menu bar UI, связать hotkeys с use case и держать high-level orchestration.

## App Modules

- `src/License/*`
  - `LicenseState.swift` — state model (`checking`, `active`, `grace`, `expired`, `serverUnavailable`).
  - `LicenseSnapshot.swift` — кэшируемый snapshot и network response model.
  - `LicenseCache.swift` — bounded offline grace cache.
  - `LicenseService.swift` — machine ID, `/api/license/status`, refresh loop, state transitions.

- `src/Diagnostics/*`
  - `DiagnosticStatus.swift` — типы diagnostic/event state.
  - `EnvironmentDiagnostics.swift` — проверки accessibility, microphone, model и `whisper-cli`.

- `src/Hotkeys/*`
  - `HotkeyMonitor.swift` — double `Option` start и single `Option` stop.

- `src/Transcription/*`
  - `ModelLocator.swift` — поиск и выбор модели.
  - `RecordingService.swift` — запись WAV.
  - `WhisperRunner.swift` — запуск `whisper-cli`, cleanup temp files, различимые ошибки.

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

## Build note

`build.sh` должен оставаться совместимым с модульной структурой: при добавлении новых `.swift` файлов они должны подхватываться автоматически, а не вручную дописываться в один список.
