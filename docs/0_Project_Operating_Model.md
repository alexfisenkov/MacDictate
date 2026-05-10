# Project Operating Model

`MacDictate` ведется как продукт с несколькими surface-слоями, а не как одиночный `.app`.

## Versioning Policy

- Публичная стабильная база сейчас: `v1.5.1`.
- Следующая рабочая линия развития: `release/1.5.2`.
- Версия в `assets/Info.plist` меняется только в подготовленном release-цикле, а не из-за имени ветки.
- Канон по версиям ведется в `docs/7_Release_Governance.md`, `releases/registry.json` и `releases/versions/<version>/RELEASE.md`.
- Локальный DMG/build log без записи в registry не считается релизом.

## Branch / Checkpoint Policy

- Рискованные этапы проходят через отдельные checkpoint tags.
- Не смешивать несвязанные изменения в одном checkpoint commit.
- Перед крупным рефактором или migration-этапом ставится annotated tag для rollback.

## Source Of Truth Policy

- `src/`, `assets/`, `build.sh` — канон desktop runtime.
- `backend/` — канон licensing/payment API.
- `web-landing/` — канон checkout/landing surface.
- `docs/legal/` — канон legal-текстов.
- `docs/7_Release_Governance.md` — канон release/version discipline.
- `releases/registry.json` — машинно-читаемый реестр всех desktop-версий и checkpoint-ов.
- `releases/versions/<version>/RELEASE.md` — человекочитаемый паспорт конкретной версии.
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
- Перед release и после перемещения артефактов обязательно проходит `scripts/verify_release_governance.sh`.
- Для публичного GitHub Release после публикации проходит `scripts/verify_release_governance.sh --online`.
- Новый DMG не остается в корне `macos/`; обычный build output живет в `build/artifacts/`, release artifact — в `releases/versions/<version>/artifacts/`.
- Папка `releases/versions/<version>/` без записи в `releases/registry.json` запрещена.
- Запись в `releases/registry.json` без `RELEASE.md`, `ARTIFACTS.md` и `SHA256SUMS` запрещена.

## App Architecture Rule

- Подробный канон: `docs/10_App_Architecture_Guardrails.md`.
- Composition root должен оставаться тонким: `src/AppController.swift` держит composition/start/status, а сценарии живут в `src/App/` или feature folders.
- Новые крупные обязанности не добавляются обратно в один controller или ближайший runner.
- Новая ответственность получает свой слой: application bridge, feature service/coordinator, runtime/client, store, formatter/validator, trace DTO или UI presentation.
- Перед завершением app-side задачи запускать `scripts/check_architecture_guardrails.sh`.

## Root Cleanliness / Artifact Policy

- В корне не должны бесконтрольно накапливаться stale build artifacts, DMG и временные логи.
- Legacy артефакты удаляются только осознанной cleanup-итерацией, а не молча во время feature work.
- `.gitignore` обязан прикрывать локальные env, runtime DB, build artifacts и temp-файлы, не скрывая исходники и канонические docs.
- Исторические DMG/build logs должны быть расфасованы по `releases/versions/*/artifacts/` или `releases/archive/*/artifacts/` с манифестом.
