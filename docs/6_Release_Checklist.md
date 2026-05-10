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

- [ ] `scripts/check_distribution_signing.sh` проходит для release-machine.
- [ ] В Keychain доступен `Developer ID Application` certificate; `Apple Development` не используется для публичного DMG.
- [ ] Developer ID `.app` подписан с `assets/MacDictate.entitlements`, включая `com.apple.security.device.audio-input`.
- [ ] Настроен и проверен `MACDICTATE_NOTARY_PROFILE`, если это публичный release.
- [ ] `swiftc`/typecheck проходит по всем `.swift` файлам.
- [ ] `scripts/test_whisper_runner_timeout.sh` проходит.
- [ ] `scripts/test_license_machine_id_timeout.sh` проходит.
- [ ] `scripts/test_recording_temp_cleanup.sh` проходит.
- [ ] `scripts/test_text_improvement_runner.sh` проходит.
- [ ] `scripts/check_bundled_whisper_runtime.sh build/MacDictate.app` проходит.
- [ ] `scripts/check_bundled_llama_runtime.sh build/MacDictate.app` проходит.
- [ ] `node --check backend/*.js` проходит.
- [ ] `./build.sh` проходит на чистой рабочей копии.
- [ ] Ясно, какой DMG является release source of truth.
- [ ] Обычный build output лежит в `build/artifacts/`, а release DMG перенесен в `releases/versions/<version>/artifacts/`.
- [ ] GitHub Release asset и локальный artifact имеют зафиксированные SHA256.
- [ ] `./build.sh` выполнен с `MACDICTATE_SIGN_IDENTITY`, `MACDICTATE_NOTARY_PROFILE` и `MACDICTATE_NOTARIZE=true` для публичного release.
- [ ] Выполнены steps по Developer ID подписи / notarization / stapling.
- [ ] `spctl` принимает notarized DMG primary signature.
- [ ] `scripts/check_install_artifact_flow.sh <release-dmg>` проходит: mounted app и временная installed-copy валидны.
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

## v1.5.0 Release Evidence

- [x] Bundle поднят до `1.5.0` / build `10`.
- [x] Release DMG собран как `MacDictate_Final_v1.5.0.dmg`.
- [x] Local artifact SHA256: `75c595ae0a1dbcbcae88ee440375cb613186de2bc3d053b69d7354f34076e9d4`.
- [x] `scripts/test_whisper_runner_timeout.sh`.
- [x] `scripts/test_license_machine_id_timeout.sh`.
- [x] `scripts/test_license_status_response.sh`.
- [x] `scripts/test_license_grace_diagnostic.sh`.
- [x] `scripts/test_recording_temp_cleanup.sh`.
- [x] `scripts/test_text_improvement_runner.sh`.
- [x] `scripts/test_debug_session_logger.sh`.
- [x] `swiftc -typecheck $(find src -name '*.swift' | sort)`.
- [x] `node --check backend/server.js && node --check backend/db.js`.
- [x] `plutil -lint assets/Info.plist`.
- [x] `./build.sh`.
