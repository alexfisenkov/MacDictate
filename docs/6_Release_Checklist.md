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

## v1.6.0 release evidence — 2026-10-19

- [x] Final manual CI39259656403 all3jobs PASS; exact sourcee80a4a094affb65457c4f3f77e090b84d6aef210.
- [x] Windows37checks, native focus/Unicode/menu, actual bundled ASR, installer/uninstaller; full self-contained payload and notices.
- [x] macOS bundle1.6.0/build14 DeveloperID+AppleAccepted/stapled/Gatekeeper/mounted-install PASS.
- [x] Versioned/alias DMG, WindowsEXE/ZIP, manifests/checksums uploaded in draft; all9public digest/size readbacks PASS.
- [x] Annotated tagv1.6.0 at checked build source, published latest complete release.
- [x] GitHub Pages b48db9f/run39263614091 success,16HTTPfiles exactbytePASS; all3public platformalias download hashes PASS; installedMac1.6.0build14 signature/Gatekeeper/process/binary/DR PASS.
- Physical Windows10/11 mic/Alt/editor and macOS mic/Option/editor remain NOT_RUN.


## Windows 1.6.1 release — 2026-10-29

- [x] Local app/delivery/package checks and independent source review completed before final hosted packaging; G4 evidence is in `.aispa-work/2026-10-29-windows-first-run--wip/blind-acceptance.md`.
- [x] Final `desktop-release.yml` run40747430459 all3jobs PASS on exact source56b45301bc0e98c12f4823e5039152a3c3dd5229. Two earlier failed attempts and separately authorized repairs remain recorded; no new CI for release preparation.
- [x] Actual JSON/PNG read-back: RU/EN/error/no-device/process/result and real bundled Whisper on synthetic PCM/key seams; native hook/paste/clipboard safety PASS.
- [x] Ordinary installed production launch in empty runner profile, close-to-tray/reopen/no implicit download, populated UIA/Copy/clipboard, 492-file payload and synthetic sentinel preservation through reinstall/uninstall PASS.
- [x] Final EXE/ZIP/manifests/checksums retained in canonical `v1.6.1/artifacts/` and rehashed; local-only aliases/evidence retained; no raw WAV/model/user content copied or published.
- [x] Candidate was prepared as `local_only` before publication; after actual API read-back the matching registry/card use `public_release`. Mac1.6.0/build14/latest-desktop remain unchanged.
- [x] Missing populated installed PNG warning retained; actual UIA/clipboard and separate real-ASR result PNG are distinguished. Synthetic125/150% layout stress at actual DPI96 is explicit.
- [x] Root published annotated v1.6.1 on checked source with `make_latest=false`; actual API release ID427078400/timestamp2026-10-28T19:07:43Z and4asset size/digest read-back PASS; global latest remains Mac1.6.0.
- [x] Promoted Windows registry → public manifest → all3exact pinned HTML fallback URLs after actual publication evidence.
- [ ] Root final staged Pages push + browser/HTTPS/file/download hash read-back.
- [ ] Physical Windows10/11 microphone/Alt/editor, native125/150%, GUI model HTTP-success and interactive installer/SmartScreen acceptance. Until then retain NOT_RUN and unsigned/manual-model-recovery limitations.

GitHub publication and API asset metadata checks do not establish Pages delivery, complete public download hashes or physical client-OS acceptance.
