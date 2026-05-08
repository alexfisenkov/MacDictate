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
- Добавлен optional second-AI layer: `TextImprovementRunner` запускает Qwen2.5-1.5B-Instruct Q4_K_M через `llama.cpp` runtime после Whisper, если включен toggle.
- `ModelLocator` разделяет Whisper `.bin` и text-improvement `.gguf`, чтобы вторая модель не могла сломать ASR model selection.
- В меню добавлены `Улучшить текст`, persisted toggle `Улучшать текст после диктовки` и downloader для Qwen model.
- Top-level `Улучшить текст` уточнен как toggle режима второй нейросети, а не ручная обработка буфера обмена.
- Download/reinstall Qwen model больше не включает automatic improvement сам по себе; автокоррекция включается только toggle-flow.
- Downloader валидирует минимальный размер модели перед сохранением, а повторный запуск downloader поднимает уже открытое окно вместо второго параллельного download task.
- Text improvement ограничен `6_000` символов input, чтобы длинная диктовка не могла быть тихо усечена generation cap; automatic pipeline fallback-ится к Whisper-тексту.
- Добавлен targeted harness `scripts/test_text_improvement_runner.sh` для timeout, stderr/stdout drain, missing runtime/model и non-zero exit.
- Добавлен `TextImprovementProfile.professionalCopyEditor`: редакторские правила, запрет на изменение смысла, правила списков/абзацев, терминологические пакеты и speech-normalization hints для Qwen prompt.
- Добавлен `TextImprovementFormatter` как post-Qwen guardrail для очевидных ordered-list markers и частых терминов; real Qwen smoke подтвердил `ChatGPT`, `Qwen`, `EBITDA`, `DaVinci Resolve` и numbered list output.
- `build.sh` дополнительно чистит xattrs на root `.app` bundle, проверяет подпись через `codesign --verify --deep`, готовит DMG staging-копию через `ditto --noextattr --noqtn` и запускает `hdiutil verify` для образа; отдельный release debt зафиксирован для strict verification смонтированной/установленной DMG-копии вместе с Developer ID/notarization.
- После повторной проверки `build.sh` усилен до strict codesign verification на clean temporary copy через `ditto --noextattr --noqtn`; это отделяет реальную подпись bundle от file-provider/FinderInfo xattrs, которые может возвращать локальная папка `Documents`.
- Проведен реальный local smoke на M1: `llama.cpp` установлен через Homebrew, Qwen GGUF скачан полностью (`1,117,320,736` bytes), `TextImprovementRunner` исправил короткий русский текст через локальную модель.
- Добавлен opt-in `DebugSessionLogger`: при включенном `MacDictateDebugSessionLoggingEnabled` каждая диктовка сохраняет локальную папку в `~/.macdictate/debug-sessions/` с аудио, raw/cleaned Whisper text, Qwen prompt/raw/cleaned/final output, финальным текстом вставки и `events.jsonl`.
- `TextImprovementRunner` получил trace API `improveWithTrace(_:)`, чтобы debug-сессия фиксировала не только итог Qwen, но и prompt, raw model output, cleaned output, formatter output и runtime/model arguments.
- Добавлен targeted harness `scripts/test_debug_session_logger.sh`; `scripts/test_text_improvement_runner.sh` расширен проверкой trace API.
- Зафиксирована AI corpus strategy: основной будущий training/eval corpus должен идти из утвержденных real dictation debug-сессий, а HuggingFace copywriting datasets остаются secondary style/eval material до license review и контрольных тестов на сохранение смысла.

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
