# Release Checklist

## Before version bump

- [ ] Рабочее дерево чистое.
- [ ] Нет незакоммиченных несвязанных изменений.
- [ ] Последний рискованный этап имеет checkpoint tag.

## Product / docs

- [ ] `scripts/verify_release_governance.sh` проходит до начала release-изменений.
- [ ] Обновлен `CHANGELOG.md`.
- [ ] Обновлен `releases/registry.json`.
- [ ] Обновлен `releases/versions/<version>/RELEASE.md`.
- [ ] Обновлены `releases/versions/<version>/artifacts/ARTIFACTS.md` и `SHA256SUMS`.
- [ ] Обновлен `docs/2_ActionLog.md`.
- [ ] Обновлен `docs/4_Decision_Log.md` при архитектурных или policy-изменениях.
- [ ] Обновлен `docs/3_TechDebt_Tasks.md`, если остались новые долги.
- [ ] Проверен `docs/7_Release_Governance.md`, если менялась release discipline.
- [ ] Проверен `README.md` и актуальность source-of-truth описания.

## Build / distribution

- [ ] `swiftc`/typecheck проходит по всем `.swift` файлам.
- [ ] `scripts/test_whisper_runner_timeout.sh` проходит.
- [ ] `node --check backend/*.js` проходит.
- [ ] `./build.sh` проходит на чистой рабочей копии.
- [ ] Ясно, какой DMG является release source of truth.
- [ ] Обычный build output лежит в `build/artifacts/`, а release DMG перенесен в `releases/versions/<version>/artifacts/`.
- [ ] GitHub Release asset и локальный artifact имеют зафиксированные SHA256.
- [ ] Выполнены steps по подписи / notarization / stapling.
- [ ] Проверен install/open path на целевом macOS.

## Verification

- [ ] Пройден smoke matrix по критичным сценариям.
- [ ] `scripts/verify_release_governance.sh` проходит локально.
- [ ] `scripts/verify_release_governance.sh --strict-local-artifacts` проходит перед публикацией, если registry ссылается на локальные DMG/build logs.
- [ ] Проверен update check.
- [ ] Проверен license flow: active / grace / expired / server unavailable.
- [ ] Проверен paste path и transcription failure path.

## Release recording

- [ ] Создан release commit/tag.
- [ ] Release asset и release notes соответствуют changelog.
- [ ] `scripts/verify_release_governance.sh --online` проходит после публикации GitHub Release.
- [ ] После публикации обновлены публичные references, если download URL менялся.
