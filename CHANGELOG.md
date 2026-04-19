# Changelog

Этот changelog фиксирует только пользовательски и релизно значимые изменения.

## [Unreleased] 1.5.0 Working Line

### Added
- server-authoritative checkout и catalog тарифов на backend-слое;
- app-side license state machine с bounded offline grace;
- runtime diagnostics для `whisper-cli`, модели, микрофона, accessibility и временной недоступности license server;
- модульная структура app-layer вместо монолитного `AppController.swift`;
- project operating model, decision log, smoke matrix и release checklist.

### Changed
- `AppController.swift` превращен в composition root / coordinator, а ключевая логика вынесена в отдельные сервисы;
- `README.md` и docs теперь описывают весь product surface: `app`, `backend`, `web-landing`, `legal`, `docs`;
- сборка `swiftc` теперь подхватывает все `.swift` файлы в `src/` рекурсивно.

## [v1.4.2] - 2026-04-05

### Added
- OTA-проверка обновлений через GitHub Releases API;
- звук вставки после успешного paste;
- улучшения меню и статусов menu bar utility.

### Notes
- `v1.4.2` остается последней публичной стабильной базой.
- Линия `release/1.5.0` пока рабочая и не считается выпущенным релизом.
