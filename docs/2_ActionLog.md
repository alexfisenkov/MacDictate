# Журнал Действий (Action Log) MacDictate

Этот журнал фиксирует инженерные шаги и checkpoints, а не маркетинговое описание релиза.

## 2026-05-08 — Release governance foundation

- Создан desktop release ledger: `releases/registry.json`, `releases/README.md`, per-version `RELEASE.md`.
- Исторические DMG/build logs перенесены из корня `macos/` в `releases/versions/*/artifacts/` и `releases/archive/*/artifacts/`.
- Зафиксированы статусы `public_stable`, `public_release`, `local_only`, `working_line`, `checkpoint`, `scratch`.
- Добавлен `docs/7_Release_Governance.md` с правилами versioning, Git tags, GitHub Releases, local artifact storage и rollback.
- Добавлен `scripts/verify_release_governance.sh` для проверки registry, `Info.plist`, checksums, папок версий и обязательных tags.
- Добавлены desktop-local `CLAUDE.md` и `AGENTS.md`, чтобы будущие агенты начинали работу с release ledger.
- По результату newcomer-аудита исправлен `build.sh`: обычный DMG output уходит в `build/artifacts/`, `create-dmg` не провоцирует Homebrew auto-update при уже установленной утилите, metadata cleanup перед `codesign` стал устойчивее.
- По результату повторного newcomer-аудита добавлен `Structure Lock`: будущие версии обязаны сохранять схему `releases/versions/<version>/` + registry entry, а `verify_release_governance.sh` теперь падает на orphan-папках, orphan-registry entries, неверных именах и расхождении статусов.
- Проверка release governance адаптирована под clean checkout: локальные ignored DMG/build logs не обязательны для GitHub Actions, но могут проверяться через `--strict-local-artifacts`.
- Добавлен GitHub Actions gate `.github/workflows/release-governance.yml`, который запускает release governance verification на push/PR в основные рабочие ветки.
- Закрыт главный runtime blocker по зависшему `whisper-cli`: `WhisperRunner` получил timeout `30` минут, controlled termination и диагностическую ошибку `timedOut`.
- `WhisperRunner` теперь читает `stderr` во время работы subprocess, чтобы stderr-heavy `whisper-cli` не зависал на заполненном pipe.
- Добавлен локальный verification script `scripts/test_whisper_runner_timeout.sh`, который проверяет recovery при зависшем fake `whisper-cli`, cleanup temp audio и успешный проход процесса с большим `stderr`.
- `LicenseService.resolveMachineID` получил bounded timeout вокруг `/usr/sbin/ioreg`; при сбое или зависании генерируется и кешируется fallback `MD-*`.
- `RecordingService` теперь чистит stale `/tmp/mac_dictate_dist.wav` и `.txt` при инициализации и перед новой записью.
- Добавлены targeted harness scripts `scripts/test_license_machine_id_timeout.sh` и `scripts/test_recording_temp_cleanup.sh`.

## 2026-04-19 — Sprint 1: backend / checkout / product surface hardening

- Добавлен server-authoritative plan catalog и `GET /api/plans`.
- `POST /api/payment/create` переведен на `planId` как основной контракт с backward-compatible legacy mapping.
- Убраны hardcoded secrets и proxy config из backend-кода; введен `.env.example`.
- Укреплены CORS, input validation и базовое throttling.
- Landing и legal-слой синхронизированы с реальным checkout contract.
- Чекпойнт: `checkpoint/1.5.0-sprint1`.

## 2026-04-19 — Sprint 2: app-side licensing / diagnostics

- В app добавлена явная state machine лицензии.
- Бесконечный fail-open заменен на bounded offline grace.
- Убран startup race вокруг первой license check.
- Добавлены различимые runtime diagnostics для `whisper-cli`, модели, permissions, transcription и paste.
- Чекпойнт: `checkpoint/1.5.0-sprint2`.

## 2026-04-19 — Architecture adaptation for 1.5.0

- `AppController.swift` перестал быть единственным бог-объектом.
- License, diagnostics, hotkeys, transcription, paste и UI presentation вынесены в отдельные app-side модули.
- `build.sh` переведен на рекурсивный сбор `.swift` файлов.
- Добавлен project operating model, decision log, smoke matrix, release checklist и structured changelog.
- Pre-refactor checkpoint: `checkpoint/1.5.0-pre-architecture`.

## Legacy context — 2026-03-31

- Проект был переведен с Python/Rumps на native Swift/AppKit.
- Для стабильного runtime был принят внешний `whisper-cli` вместо хрупкого bundle с dylib.
- `ModelDownloader` и permission auto-restart стали частью первого рабочего app-layer.
