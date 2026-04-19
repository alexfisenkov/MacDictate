# Release Checklist

## Before version bump

- [ ] Рабочее дерево чистое.
- [ ] Нет незакоммиченных несвязанных изменений.
- [ ] Последний рискованный этап имеет checkpoint tag.

## Product / docs

- [ ] Обновлен `CHANGELOG.md`.
- [ ] Обновлен `docs/2_ActionLog.md`.
- [ ] Обновлен `docs/4_Decision_Log.md` при архитектурных или policy-изменениях.
- [ ] Обновлен `docs/3_TechDebt_Tasks.md`, если остались новые долги.
- [ ] Проверен `README.md` и актуальность source-of-truth описания.

## Build / distribution

- [ ] `swiftc`/typecheck проходит по всем `.swift` файлам.
- [ ] `./build.sh` проходит на чистой рабочей копии.
- [ ] Ясно, какой DMG является release source of truth.
- [ ] Выполнены steps по подписи / notarization / stapling.
- [ ] Проверен install/open path на целевом macOS.

## Verification

- [ ] Пройден smoke matrix по критичным сценариям.
- [ ] Проверен update check.
- [ ] Проверен license flow: active / grace / expired / server unavailable.
- [ ] Проверен paste path и transcription failure path.

## Release recording

- [ ] Создан release commit/tag.
- [ ] Release asset и release notes соответствуют changelog.
- [ ] После публикации обновлены публичные references, если download URL менялся.
