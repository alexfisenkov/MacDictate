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
- [ ] Обновлен `web-landing/downloads/latest-desktop.json` под текущий `public_stable`.
- [ ] Проверен `README.md` и актуальность source-of-truth описания.

## Build / distribution

- [ ] `scripts/check_distribution_signing.sh` проходит для release-machine.
- [ ] В Keychain доступен `Developer ID Application` certificate; `Apple Development` не используется для публичного DMG.
- [ ] Developer ID `.app` подписан с `assets/MacDictate.entitlements`, включая `com.apple.security.device.audio-input`.
- [ ] Проверена notary authentication: `MACDICTATE_NOTARY_PROFILE` либо API-key mode из signing runbook.
- [ ] `swiftc`/typecheck проходит по всем `.swift` файлам.
- [ ] `scripts/test_whisper_runner_timeout.sh` проходит.
- [ ] `scripts/test_free_desktop.sh` проходит: текущий app не содержит license gate, machine ID, paywall и license timer.
- [ ] `scripts/test_recording_temp_cleanup.sh` проходит.
- [ ] `scripts/test_text_improvement_runner.sh` проходит.
- [ ] `scripts/check_bundled_whisper_runtime.sh build/MacDictate.app` проходит.
- [ ] `scripts/check_bundled_llama_runtime.sh build/MacDictate.app` проходит.
- [ ] `node --check backend/*.js` проходит.
- [ ] `./build.sh` проходит на чистой рабочей копии.
- [ ] Ясно, какой DMG является release source of truth.
- [ ] Обычный build output лежит в `build/artifacts/`, а release DMG перенесен в `releases/versions/<version>/artifacts/`.
- [ ] GitHub Release asset и локальный artifact имеют зафиксированные SHA256.
- [ ] Те же байты DMG загружены на сайт как `/downloads/MacDictate_Latest.dmg`.
- [ ] Developer ID build нотарифицирован через profile-mode либо отдельный API-key submit/staple/verify того же DMG по signing runbook.
- [ ] Выполнены steps по Developer ID подписи / notarization / stapling.
- [ ] `spctl` принимает notarized DMG primary signature.
- [ ] `scripts/check_install_artifact_flow.sh <release-dmg>` проходит: mounted app и временная installed-copy валидны.
- [ ] Проверен install/open path на целевом macOS.

## Verification

- [ ] Пройден smoke matrix по критичным сценариям.
- [ ] `scripts/verify_release_governance.sh` проходит локально.
- [ ] `scripts/verify_release_governance.sh --strict-local-artifacts` проходит перед публикацией, если registry ссылается на локальные DMG/build logs.
- [ ] Проверен update check.
- [ ] Проверен бесплатный desktop: старт и диктовка не зависят от legacy license cache или доступности license API; проверки модели, runtime и разрешений сохранены.
- [ ] Для первого публичного бесплатного выпуска обновлены landing/download/checkout и RU/EN legal-тексты; backend совместим со старыми клиентами.
- [ ] Проверен paste path и transcription failure path.

## Release recording

- [ ] Создан release commit/tag.
- [ ] Release asset и release notes соответствуют changelog.
- [ ] `scripts/verify_release_governance.sh --online` проходит после публикации GitHub Release.
- [ ] После публикации сайт скачивает именно текущий stable DMG, а не старый alias.

## v1.5.0 Release Evidence

Исторические license harness ниже перенесены в `archive/legacy-licensing/scripts/`; они не являются требованиями для бесплатного desktop.

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

## v1.5.2 free release evidence — 2026-10-19

- [x] Free source/menu, diagnostic logger, model selection, temporary audio cleanup, last dictation, update checker, Whisper timeout, text improvement and runtime locator harnesses.
- [x] Free backend HTTP harness: no new devices/orders/provider requests, payments410. Source-only compatibility; retired server not restored.
- [x] Developer ID build13 from exact GitHub main SHA; notarization Accepted, stapled DMG, Gatekeeper and mounted-install checks PASS.
- [x] Annotated v1.5.2 source tag and public GitHub release with matching versioned/alias digests.
- [x] Static site RU/EN, prefix routing, legal documents, mobile/wide, CDN fallback QA PASS.
- [x] GitHub Pages live deployment/read-back: 14 files exact, final source6d02041, run39245114809 success.
- [x] Final installed build13 read-back from public downloaded DMG: SHA/strictsignature/Gatekeeper/process and synthetic WhisperRunner PASS.
- Live microphone/hotkey/paste: NOT_RUN; native UI automation times out. Installed-bundle WhisperRunner synthetic ASR: PASS.
- Hosted app CI not run under OWNER_LOCAL_RELEASE_20261015; Pages performed three automatic hosted deployments during branch preparation, all successful; final run39245114809. This deviated from the one-final-run policy; no additional Pages push is needed.
