# CLAUDE.md — MacDictate macOS Desktop Context

> Этот файл задаёт локальные правила для работы именно с desktop/macOS-версией MacDictate.
> `macos/AGENTS.md` должен быть побайтово идентичной копией `macos/CLAUDE.md`. После
> изменения выполнить `cp macos/CLAUDE.md macos/AGENTS.md && cmp -s macos/CLAUDE.md macos/AGENTS.md`.

## Scope

Эта папка — самостоятельный рабочий контур desktop-продукта MacDictate.

- Runtime app: `macos/src/`, `macos/assets/`, `macos/build.sh`.
- Licensing/payment backend: `macos/backend/`.
- Landing/checkout: `macos/web-landing/`.
- Engineering canon: `macos/docs/` — полная опись в `macos/docs/00-индекс.md`.
- Release ledger: `macos/releases/`.
- Local release checks: `macos/scripts/`.
- Historical/non-active scratch artifacts: `macos/archive/`.

Не смешивать desktop-release discipline с iOS и Transcribe ветками из родительского проекта.

## Куда идти дальше

Этот файл — только release governance и hard guardrails macOS-контура. Он не пересказывает
общий контекст — тот живёт в двух индексах:

| Нужно | Файл |
|---|---|
| Весь инженерный канон macOS (архитектура app, техдолг, QA, release governance, legal, backend runbook) | `macos/docs/00-индекс.md` |
| Продукт целиком, три поверхности, состояние версий | `docs/01-продукт.md` |
| Дерево репозитория и назначение папок | `docs/02-структура.md` |
| Технический стек по поверхностям | `docs/03-стек.md` |
| Потоки управления `AppController` | `docs/04-архитектура-macos.md` |
| Якоря `file:line` в исходниках | `docs/05-якоря.md` |
| Таймауты, пути, горячие клавиши, звуки | `docs/06-константы.md` |
| HTTP API лицензий и платежей, каталог тарифов | `docs/07-бэкенд.md` |
| iOS-клавиатура и оглавление мастер-спека | `docs/08-ios.md` |
| Команды сборки и типовые процессы | `docs/09-процессы.md` |
| Операционные правила и красные линии всего проекта | `docs/10-правила.md` |
| Skills и агенты, правила брифинга | `docs/11-навыки-и-агенты.md` |
| Полная опись документационного слоя | `docs/00-индекс.md` |
| Общий обзор и маршрутизация по задачам | корневой `CLAUDE.md` |

## Release Source Of Truth

Перед любой работой с версиями сначала читать:

1. `macos/docs/7_Release_Governance.md`;
2. `macos/releases/registry.json`;
3. `macos/releases/versions/<version>/RELEASE.md`;
4. `macos/CHANGELOG.md`;
5. `macos/docs/6_Release_Checklist.md`.

Если эти источники расходятся, не угадывать по DMG-файлам. Сначала восстановить канон в registry и в `macos/releases/versions/<version>/RELEASE.md`.

## Hard Guardrails

Эти правила нельзя обходить:

- Не создавать `macos/releases/versions/<version>/` вручную без одновременной записи в `macos/releases/registry.json`.
- Не менять статус версии, bundle version, Git tag, GitHub asset или artifact path вне `macos/releases/registry.json`.
- Не оставлять DMG/build logs в корне `macos/`.
- Не считать локальную сборку релизом без записи `macos/releases/versions/<version>/RELEASE.md`, registry entry, checksum и проверки.
- Public release проверяется по distribution channel из registry и D-022: GitHub asset/alias и manifest обязаны совпадать с `current.publicStable`; legacy website mirror обязателен только для прежнего серверного канала.
- Не начинать feature/release work, если `macos/scripts/verify_release_governance.sh` падает.
- Не добавлять новую версию по другой схеме: все следующие версии обязаны жить в `macos/releases/versions/<version>/` и иметь запись с тем же именем в registry.
- Если есть противоречие между docs, registry, GitHub и DMG, остановиться и сначала восстановить release ledger.
- Перед app-side правками читать `macos/docs/10_App_Architecture_Guardrails.md`; не наращивать `AppController`, `AppController+*.swift`, runner или validator выше лимитов, а выделять новый слой/файл.
- Перед завершением app-side правки запускать `macos/scripts/check_architecture_guardrails.sh`.

## Current Version State

Текущий публичный тег, bundle version и рабочая ветка — `docs/01-продукт.md` (сверено 2026-09-10).
Инженерная хронология рабочих линий и checkpoint-ов — `macos/docs/2_ActionLog.md`; пользовательски
значимые изменения по релизам — `macos/CHANGELOG.md`; условия, при которых версия официально
считается выпущенной, — `macos/docs/7_Release_Governance.md`; smoke-покрытие каждой фичи и её
проверочный скрипт — `macos/docs/5_QA_Smoke_Matrix.md`.

## Version Folder Contract

Каждая версия хранится так:

```text
macos/releases/versions/<version>/
├── RELEASE.md
└── artifacts/
    ├── ARTIFACTS.md
    ├── SHA256SUMS
    └── локальные DMG/build logs (git ignored)
```

Новый DMG нельзя оставлять в корне `macos/`. Обычный `macos/build.sh` пишет временный DMG в `macos/build/artifacts/`; release-candidate переносится в `macos/releases/versions/<version>/artifacts/`.

## Required Release Updates

Любое изменение release/status/version обязано обновить:

- `macos/releases/registry.json`;
- `macos/releases/versions/<version>/RELEASE.md`;
- `macos/CHANGELOG.md`;
- `macos/docs/2_ActionLog.md`;
- `macos/docs/6_Release_Checklist.md`;
- `macos/web-landing/downloads/latest-desktop.json`, если меняется публичный stable release;
- `macos/docs/4_Decision_Log.md`, если изменилось правило или архитектурное решение;
- `macos/docs/3_TechDebt_Tasks.md`, если остался новый долг.

После этого обязательно выполнить:

```bash
macos/scripts/verify_release_governance.sh
```

Для локального аудита ignored DMG/build logs:

```bash
macos/scripts/verify_release_governance.sh --strict-local-artifacts
```

Если работа касается GitHub Releases:

```bash
macos/scripts/verify_release_governance.sh --online
```

## Git Rules

- Публичный release tag должен быть annotated.
- Checkpoint tags имеют формат `checkpoint/<version>-<slug>`.
- Hotfix старой версии делать от release tag через `hotfix/<version>-<topic>`.
- Не коммитить секреты, `.env`, runtime DB, node_modules, build output и локальные DMG.

Версионирование (включая правило про `assets/Info.plist` и имя ветки), secrets policy и
архитектурные красные линии всего проекта — целиком в `docs/10-правила.md`.

## Historical Caveats

- `v1.2` и `v1.3` есть в GitHub Releases/remote tags, но локальные tags отсутствуют; remote tags указывают на тот же commit, что `v1.4`. Их история помечена как reconstructed.
- `v1.4.1-local` — локальная сборка build `8`, не публичный release.
- Публичным download source of truth для `v1.5.0` остается GitHub Release.

## Development Priority

Не начинать feature work, пока release ledger не остается зеленым. Если в ходе работы появляются новые артефакты, сначала положить их в правильную version/archive папку и обновить манифест.
