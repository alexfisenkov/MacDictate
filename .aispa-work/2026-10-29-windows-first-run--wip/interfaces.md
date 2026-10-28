# Границы и правила

## Канон проекта
Физический Gitroot macos/. Текущий baseline78f3813. Windowscontext windows/CLAUDE.md; notes.md содержит точные существующие имена. Пользовательские CLAUDE/AGENTS не перезаписывать. macOS/iOS/Transcribe runtime не менять. Документы релиза и .aispa-work являются историей; исходники/синтетические данные разрешены в существующем GitHubrepo, секреты и пользовательские медиа нет. Перед hosted CI целевые локальные проверки; только один финальный согласованный запуск, repair лишь по конкретной ошибке. Нет авто push/PR CI. Не трогать прошлые публичные файлы и модели. Глобальный latestMac не смещать Windows-only hotfix.

## Границы, решённые в спецификации
- AppSettings/LocalStore сохраняют прежние поля Language/Hotkey/ModelPath; новые параметры микрофона/setup/UI имеют defaults, старый JSON читается без миграции исходных данных.
- Core владеет readiness/state/PCM signal policy и персистентными данными. Не зависит от WinForms/Win32.
- Native services владеют enumeration/capture/meter и выделенным keyboard message loop. Внешняя поверхность: список микрофонов с ID/Name; cancellable mic test с progressLevel и outcome(success/signal/error); WaveRecorder поддерживает выбранный deviceID, существующий Stop/Dispose cleanup сохраняется. Точные локальные имена может выбрать единый app executor, он записывает их здесь после реализации; ни одна последующая задача не пишет эти native-модули.
- Main/setup UI orchestration владеет состояниями и человекочитаемыми текстами; слушает только metadata hotkey events, не блокирует keyboard callback. Большие download/ASR вне UI thread. Main record origin не делает auto-paste в собственное приложение; global origin сохраняет существующий guard.
- Program/Tray управляют single instance и открытием/повторным показом окна. Ошибки readiness не теряются в скрытых balloon.
- Проверочные CLI contracts: сохранить --smoke-test --report PATH и --transcribe WAV --model BIN --report PATH. Добавить --onboarding-smoke --report PATH с изолированным temporary profile; отчёт явно distinguishes synthetic microphone vs real capture, real/hooked keyboard vs injected seam, captured transcript test-only. Не менять production readiness через общие env flags. App executor документирует flags/тестовые швы.
- Один общий local check: windows/scripts/check-local.sh создаётся app executor: core console harness + Windows cross-build, SDK из .local/dotnet/dotnet либо PATH. Без hosted CI. Windows-native suite запускается отдельным PS script в final workflow.
- Доставка: installer EXE primary, ZIP secondary. Windows-only1.6.1 release with make_latest=false; fixed tag download pin, not global/releases/latest for Windows. CurrentMac1.6.0 untouched. Registry, Windows manifest, docs/checksum/read-back updated delivery executor. Site source stays on main until one final reviewed gh-pages push.

## Исполнители
01 owns windows/src, windows/tests, windows/scripts/check-local.sh, implementation seams; may update interfaces only to record actual contracts. 02 owns web-landing, WindowsREADME/installer/build/acceptance scripts, workflow, release/governance docs and registry, windows csproj version bump after01; no competing writers.
