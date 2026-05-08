# Changelog

Этот changelog фиксирует только пользовательски и релизно значимые изменения.

## [Unreleased] 1.5.0 Working Line

### Added
- server-authoritative checkout и catalog тарифов на backend-слое;
- app-side license state machine с bounded offline grace;
- runtime diagnostics для `whisper-cli`, модели, микрофона, accessibility и временной недоступности license server;
- модульная структура app-layer вместо монолитного `AppController.swift`;
- project operating model, decision log, smoke matrix и release checklist;
- release governance layer: `docs/7_Release_Governance.md`, `releases/registry.json`, per-version `RELEASE.md`, локальное хранилище artifacts и `scripts/verify_release_governance.sh`;
- desktop-local `CLAUDE.md` / `AGENTS.md` с правилами работы будущих агентов;
- targeted runtime harnesses для зависшего/stderr-heavy `whisper-cli`, machine ID timeout и cleanup stale temp audio.

### Changed
- `AppController.swift` превращен в composition root / coordinator, а ключевая логика вынесена в отдельные сервисы;
- `README.md` и docs теперь описывают весь product surface: `app`, `backend`, `web-landing`, `legal`, `docs`;
- сборка `swiftc` теперь подхватывает все `.swift` файлы в `src/` рекурсивно;
- исторические DMG/build logs разложены из корня проекта в `releases/versions/*/artifacts/` и `releases/archive/*/artifacts/`;
- `build.sh` теперь кладет обычный DMG output в `build/artifacts/`, не запускает Homebrew install, если `create-dmg` уже доступен, и повторно очищает macOS metadata перед `codesign`.

### Fixed
- `WhisperRunner` больше не ждет `whisper-cli` бесконечно: transcription subprocess ограничен timeout `30` минут, после чего процесс завершается, temp-файлы чистятся, а пользователь получает различимую диагностическую ошибку.
- `WhisperRunner` теперь читает `stderr` во время работы subprocess, чтобы шумный `whisper-cli` не блокировался на заполненном pipe.
- `LicenseService` больше не может подвиснуть на первом `ioreg` при получении machine ID: command ограничен timeout и fallback-кешированием generated ID.
- `RecordingService` чистит stale `/tmp/mac_dictate_dist.wav` и `.txt` при старте сервиса и перед новой записью.

### Notes
- `v1.2` и `v1.3` помечены как reconstructed history: GitHub Releases существуют, но локальные tags отсутствуют, а remote tags указывают на commit `v1.4`.
- `v1.4.1-local` помечена как локальная сборка, не публичный release.
- Локальный `v1.4.2` DMG отличается по SHA256 от GitHub asset; публичный source of truth для скачивания — GitHub Release.

## [v1.4.2] - 2026-04-05

### Added
- OTA-проверка обновлений через GitHub Releases API;
- звук вставки после успешного paste;
- улучшения меню и статусов menu bar utility.

### Notes
- `v1.4.2` остается последней публичной стабильной базой.
- Линия `release/1.5.0` пока рабочая и не считается выпущенным релизом.

## [v1.4] - 2026-04-01

### Added / Changed
- Refined Native Settings Submenu.
- TCC ghost permission guidance.
- Dangerous Zone / uninstall returned.

## [v1.3] - 2026-04-01

### Added
- Submenu settings and TCC polling, по GitHub release notes.

### Notes
- История восстановлена по GitHub Release и локальному DMG; локальный tag отсутствует.

## [v1.2] - 2026-04-01

### Added
- First standalone release, по GitHub release notes.

### Notes
- История восстановлена по GitHub Release и локальному DMG; локальный tag отсутствует.

## [v1.1] - 2026-04-01

### Added / Changed
- Reliable relaunch.
- Visual Login Items через AppleScript fallback.
- Early OTA Auto-Updater implementation.

## [v1.0] - 2026-03-31

### Added
- Native Swift/AppKit desktop core.
- Local Whisper via Homebrew `whisper-cli`.
- Auto-permissions and uninstaller.

### Notes
- Локальная историческая база без публичного GitHub Release.
