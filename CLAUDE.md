# CLAUDE.md — MacDictate macOS Desktop Context

> Этот файл задает локальные правила для работы именно с desktop/macOS-версией MacDictate.
> `AGENTS.md` в этой же папке должен быть идентичной копией. Источник истины — `CLAUDE.md`; после изменения выполнить `cp CLAUDE.md AGENTS.md && cmp -s CLAUDE.md AGENTS.md`.

## Scope

Эта папка — самостоятельный рабочий контур desktop-продукта MacDictate.

- Runtime app: `src/`, `assets/`, `build.sh`.
- Licensing/payment backend: `backend/`.
- Landing/checkout: `web-landing/`.
- Engineering canon: `docs/`.
- Release ledger: `releases/`.
- Local release checks: `scripts/`.

Не смешивать desktop-release discipline с iOS и Transcribe ветками из родительского проекта.

## Release Source Of Truth

Перед любой работой с версиями сначала читать:

1. `docs/7_Release_Governance.md`;
2. `releases/registry.json`;
3. `releases/versions/<version>/RELEASE.md`;
4. `CHANGELOG.md`;
5. `docs/6_Release_Checklist.md`.

Если эти источники расходятся, не угадывать по DMG-файлам. Сначала восстановить канон в registry и `RELEASE.md`.

## Hard Guardrails

Эти правила нельзя обходить:

- Не создавать `releases/versions/<version>/` вручную без одновременной записи в `releases/registry.json`.
- Не менять статус версии, bundle version, Git tag, GitHub asset или artifact path вне `releases/registry.json`.
- Не оставлять DMG/build logs в корне `macos/`.
- Не считать локальную сборку релизом без `RELEASE.md`, registry entry, checksum и проверки.
- Не начинать feature/release work, если `scripts/verify_release_governance.sh` падает.
- Не добавлять новую версию по другой схеме: все следующие версии обязаны жить в `releases/versions/<version>/` и иметь запись с тем же именем в registry.
- Если есть противоречие между docs, registry, GitHub и DMG, остановиться и сначала восстановить release ledger.

## Current Version State

- Текущая публичная stable: `v1.4.2`.
- Bundle в `assets/Info.plist`: `1.4.2` / build `9`.
- Рабочая линия: `release/1.5.0`.
- `v1.5.0` не считается релизом до tag, GitHub Release, registry update, DMG asset и smoke evidence.
- В рабочей линии `1.5.0` `WhisperRunner` ограничивает зависший `whisper-cli` timeout `30` минут и читает `stderr` во время работы процесса; `LicenseService` ограничивает первый `ioreg`; `RecordingService` чистит stale temp audio.
- В `1.5.0` добавлен optional second-AI layer: Qwen2.5-1.5B-Instruct Q4_K_M (`.gguf`) через `llama.cpp` (`llama-completion`), persisted toggle `MacDictateTextImprovementEnabled`, top-level toggle `Улучшить текст`, downloader модели, safe input limit `6_000` символов, `TextImprovementProfile.professionalCopyEditor` с editorial rules / terminology packs и `TextImprovementFormatter` для очевидных list/term guardrails.
- Локальные runtime harnesses: `scripts/test_whisper_runner_timeout.sh`, `scripts/test_license_machine_id_timeout.sh`, `scripts/test_recording_temp_cleanup.sh`, `scripts/test_text_improvement_runner.sh`.

## Version Folder Contract

Каждая версия хранится так:

```text
releases/versions/<version>/
├── RELEASE.md
└── artifacts/
    ├── ARTIFACTS.md
    ├── SHA256SUMS
    └── локальные DMG/build logs (git ignored)
```

Новый DMG нельзя оставлять в корне `macos/`. Обычный `./build.sh` пишет временный DMG в `build/artifacts/`; release-candidate переносится в `releases/versions/<version>/artifacts/`.

## Required Release Updates

Любое изменение release/status/version обязано обновить:

- `releases/registry.json`;
- `releases/versions/<version>/RELEASE.md`;
- `CHANGELOG.md`;
- `docs/2_ActionLog.md`;
- `docs/6_Release_Checklist.md`;
- `docs/4_Decision_Log.md`, если изменилось правило или архитектурное решение;
- `docs/3_TechDebt_Tasks.md`, если остался новый долг.

После этого обязательно выполнить:

```bash
scripts/verify_release_governance.sh
```

Для локального аудита ignored DMG/build logs:

```bash
scripts/verify_release_governance.sh --strict-local-artifacts
```

Если работа касается GitHub Releases:

```bash
scripts/verify_release_governance.sh --online
```

## Git Rules

- Публичный release tag должен быть annotated.
- Checkpoint tags имеют формат `checkpoint/<version>-<slug>`.
- Hotfix старой версии делать от release tag через `hotfix/<version>-<topic>`.
- Не менять `assets/Info.plist` из-за имени ветки; version bump только в release-cycle.
- Не коммитить секреты, `.env`, runtime DB, node_modules, build output и локальные DMG.

## Historical Caveats

- `v1.2` и `v1.3` есть в GitHub Releases/remote tags, но локальные tags отсутствуют; remote tags указывают на тот же commit, что `v1.4`. Их история помечена как reconstructed.
- `v1.4.1-local` — локальная сборка build `8`, не публичный release.
- Локальный `v1.4.2` DMG отличается по SHA256 от GitHub asset; публичным download source of truth остается GitHub Release.

## Development Priority

Не начинать feature work, пока release ledger не остается зеленым. Если в ходе работы появляются новые артефакты, сначала положить их в правильную version/archive папку и обновить манифест.
