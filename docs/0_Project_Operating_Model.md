# Project Operating Model

`MacDictate` ведется как продукт с несколькими surface-слоями, а не как одиночный `.app`.

## Versioning Policy

- Публичная стабильная база сейчас: `v1.4.2`.
- Рабочая линия развития: `release/1.5.0`.
- Версия в `assets/Info.plist` меняется только в подготовленном release-цикле, а не из-за имени ветки.

## Branch / Checkpoint Policy

- Рискованные этапы проходят через отдельные checkpoint tags.
- Не смешивать несвязанные изменения в одном checkpoint commit.
- Перед крупным рефактором или migration-этапом ставится annotated tag для rollback.

## Source Of Truth Policy

- `src/`, `assets/`, `build.sh` — канон desktop runtime.
- `backend/` — канон licensing/payment API.
- `web-landing/` — канон checkout/landing surface.
- `docs/legal/` — канон legal-текстов.
- `backend/plans.js` — единственный источник истины по plan catalog.
- `GET /api/license/status` сохраняется совместимым с текущим macOS app, пока отдельным решением не согласован breaking change.

## Secret Handling Policy

- Секреты, proxy credentials и `.env` со значениями не коммитятся.
- Настоящие значения живут только в env/secret store.
- В репо допускаются только `.env.example` и документированные имена переменных.

## Release Discipline

- Нельзя выпускать release из dirty tree.
- Перед release обязательно обновляются `CHANGELOG.md`, `docs/2_ActionLog.md`, `docs/4_Decision_Log.md`, `docs/6_Release_Checklist.md`.
- У release должен быть один явный source of truth для DMG/asset path.

## App Architecture Rule

- Composition root должен оставаться тонким.
- Новые крупные обязанности не добавляются обратно в один controller.
- License logic, diagnostics, hotkeys, transcription, paste и UI presentation живут в отдельных файлах/слоях.

## Root Cleanliness / Artifact Policy

- В корне не должны бесконтрольно накапливаться stale build artifacts, DMG и временные логи.
- Legacy артефакты удаляются только осознанной cleanup-итерацией, а не молча во время feature work.
- `.gitignore` обязан прикрывать локальные env, runtime DB, build artifacts и temp-файлы, не скрывая исходники и канонические docs.
