# Журнал Действий (Action Log) MacDictate

Этот журнал фиксирует инженерные шаги и checkpoints, а не маркетинговое описание релиза.

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
