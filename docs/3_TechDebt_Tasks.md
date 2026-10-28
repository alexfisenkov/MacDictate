# Технический Долг и Backlog

Этот файл теперь ведется как живой backlog с приоритетом и ожидаемым impact.

| Area | Status | Priority | Impact | Effort | Owner | Item |
| --- | --- | --- | --- | --- | --- | --- |
| Release | Done | P0 | Distribution | M | Project | Перевести release path на Developer ID + notarization + stapling: build pipeline, runbook, `Developer ID Application` certificate, `macdictate-notary` profile и первая notarized/stapled DMG-сборка подтверждены. |
| Release | Done | P0 | Distribution | S | Project | Настроить `MACDICTATE_NOTARY_PROFILE` для notarytool и выполнить первую notarized/stapled DMG-сборку. |
| Release | Done | P0 | Integrity | M | Project | Определить один source of truth для release asset: GitHub release vs site download. Решение: GitHub Release остается каноном публикации, а сайт обязан зеркалить текущий `public_stable` через `/downloads/MacDictate_Latest.dmg`; manifest `web-landing/downloads/latest-desktop.json` и `verify_release_governance.sh --online` фиксируют правило. |
| Release | Open | P0 | History | S | Project | Нормализовать исторические remote/local tags `v1.2` и `v1.3`: решить, пересоздавать/документировать aliases или оставить как legacy. |
| Release | Done | P1 | Packaging | M | Project | Strict verification установленной/смонтированной DMG-копии: `scripts/check_install_artifact_flow.sh` монтирует финальный DMG, проверяет app внутри образа, копирует во временную Applications-папку и валидирует codesign, microphone entitlement и bundled `whisper`/`llama` runtimes. |
| Release | Open | P1 | Integrity | S | Project | Скачать опубликованные GitHub assets для `v1.1`-`v1.4` и заполнить `githubAssetSha256` в `releases/registry.json`. |
| Release | Open | P1 | Hygiene | S | Project | Проверить, нужно ли удалять ранее tracked binary DMG из git history через отдельную history-rewrite policy; текущая cleanup-итерация только убирает их из рабочего дерева вперед. |
| Backend/App | Retired | P0 | UX | M | Project | App-side support snapshot и manual license recheck больше не нужны: по решению D-021 от 2026-10-19 desktop бесплатен и licensing удален из runtime. Совместимость backend для старых версий сохраняется. |
| Release/Web/Legal | Done | P1 | Distribution / UX | M | Project | Бесплатный v1.5.2/build13 опубликован на GitHub, notarized/stapled DMG и alias совпадают по SHA, публичный download проверен, app из публичного DMG установлен, strict signature/Gatekeeper/WhisperRunner synthetic PASS. GitHub Pages live: 14 файлов совпали с проверенным snapshot. Старый сервер отключён по данным владельца и не является зависимостью; backend free policy проверена локально и не заявляется как deployed API. |
| Backend | Done | P0 | Ops / Availability | M | Project | Починить production TLS/reverse-proxy timeout на `macdictate.pro`: production перенесен на московский host `193.233.247.71`, DNS cutover подтвержден live-проверками, `/api/*` и `/downloads/MacDictate_Latest.dmg` отвечают с нового хоста. |
| Backend | Done | P1 | Ops | M | Project | Подтвердить parity локального `backend/` с production deploy и задокументировать production ownership: добавлен `docs/11_Backend_Ops_Runbook.md`, `/api/health`, slow-request telemetry, server timeout env и SQLite WAL/busy timeout. |
| App | Done | P0 | Runtime / Compatibility | M | Project | Bundled `whisper-cli` и `llama-completion` пересобраны из upstream source tarballs под `LSMinimumSystemVersion=11.0`; `scripts/build_clean_runtimes.sh` фиксирует воспроизводимый path, runtime layout разделен на `lib/whisper` / `lib/llama` и `libexec/ggml-whisper` / `libexec/ggml-llama`, а checks подтверждают `minos=11.0` и отсутствие Homebrew/local ссылок. |
| Build | Open | P1 | Reproducibility / Compatibility | M | Project | Пересобрать локальный source-runtime cache после миграции Mac: у cached Mach-O обнаружен старый absolute `LC_RPATH` с прежним home, из-за чего bundler подтянул Homebrew dependencies с `minos=26` и остановил сборку. Для текущей локальной установки используется уже проверенный runtime из прежнего установленного bundle; восстановить воспроизводимую source-сборку под macOS 11 и повторно пройти bundled-runtime checks. Это drift сборочного кэша, не ошибка диктовки. |
| App | Open | P1 | Supportability | M | Project | Добавить repair flow для `no model / no whisper / permission denied`. |
| App | Open | P1 | UX | M | Project | Вынести `launch at login` из AppleScript fallback в более чистый и проверяемый path. |
| App | Open | P1 | Flexibility | M | Project | Сделать настраиваемую горячую клавишу без ломки menu bar utility UX. |
| Repo | Done | P1 | Hygiene | S | Project | Root artifact clutter убран из активного root layout: icon scratch files и helper scripts перенесены в `archive/legacy-root-scratch/` с README. DMG/build logs уже расфасованы в release ledger. |
| App | Done | P2 | Onboarding | L | Project | Уйти от зависимости на Homebrew `whisper-cli`: `build.sh` bundles `whisper-cli`, `libwhisper`, ggml dylibs/backend plugins и `libomp`; `WhisperRunner` использует bundled backend path, artifact проверяется `scripts/check_bundled_whisper_runtime.sh`. |
| App | Done | P2 | Onboarding | M | Project | Уйти от зависимости на Homebrew `llama.cpp` runtime для второй нейросети: `build.sh` bundles `llama-completion` + `.dylib` dependencies, `LlamaRuntimeLocator` предпочитает bundled runtime, artifact проверяется `scripts/check_bundled_llama_runtime.sh`. |
| App | Open | P2 | UX | M | Project | После runtime smoke решить, нужен ли progress/cancel flow для долгого улучшения текста. |
| App | Open | P2 | UX | M | Project | Решить, нужен ли chunking для улучшения длинных диктовок; текущая защита fallback-ит input > 6 000 символов к Whisper-тексту. |
| App | Open | P2 | UX / Recovery | M | Project | Спроектировать полноценную desktop-историю диктовок по аналогии с iOS History: список последних текстов, copy/delete, локальное хранение, privacy/retention и UX для открытия истории из menu bar. |
| App/AI | Open | P2 | Quality | M | Project | Накопить реальный корпус пар `raw Whisper text -> desired edited text` и на его базе решить, достаточно ли prompt/profile или нужен LoRA/fine-tune. |
| App/AI | Open | P2 | Quality / Legal | S | Project | Провести license review HuggingFace copywriting datasets перед любым training/eval использованием; `jaykin01/advertisement-copy` сейчас имеет unknown license на HF card. |
| App | Open | P2 | Runtime | S | Project | Собрать runtime evidence по экстремально длинным диктовкам и решить, нужен ли user-facing progress/cancel flow. |
| App/AI | Open | P2 | Quality / Performance | S | Project | После тестов Whisper `large-v3` собрать сравнение качества/latency/RAM против `large-v3-turbo` на M1/16 GB и решить, оставлять ли heavy ASR mode как пользовательскую опцию. |
| App/AI | Open | P2 | Runtime / UX | S | Project | После тестов Qwen2.5-3B собрать latency/RAM evidence на M1/16 GB и решить, нужен ли user-facing selector между 3B quality mode и 1.5B fast mode. |
| App/Diagnostics | Open | P2 | Privacy / Supportability | S | Project | Для debug-сессий добавить user-facing управление: открыть папку логов, отключить logging, удалить старые session folders и/или задать retention policy. |
| App | Open | P2 | Maintainability | M | Project | Если dictation flow продолжит расти, вынести `src/App/AppController+DictationFlow.swift` в отдельный `DictationPipeline` service с явными callbacks для status/debug/paste. Рост этого файла теперь ограничен `docs/10_App_Architecture_Guardrails.md` и `scripts/check_architecture_guardrails.sh`. |

| Backend | Open | P1 | Historical reconciliation | M | Project | Historical webhook ACK-before-write and split order/device updates predate free rollout; preserve current credentials for pending callbacks and design idempotent/atomic reconciliation separately. Do not rewrite prior paid history for free access. |

| App/AI | Open | P1 | Commercial model licensing | M | Project | Qwen2.5-3B-Instruct-GGUF uses qwen-research, with commercial use requiring a separate provider license. Public RU/EN EULA explicitly separates optional model rights from free MacDictate/Whisper dictation. Evaluate an appropriately licensed default correction model in a separate change; do not remove or modify model files silently. |

| App/QA | Open | P1 | Runtime acceptance | S | Project | Выполнить ручной mic → double/single Option → paste smoke после build13: native UI tools возвращают timeout. Installed-bundle synthetic WhisperRunner и code/menu harness PASS; полный живой путь остаётся NOT_RUN. |

| App/Models | Open | P1 | Recovery | S | Project | Existing ModelDownloader removes a prior model before moving its replacement. Preserve/stage the new file before atomic replacement to avoid a re-download if move fails. This predates free rollout; no user models were replaced in this task. |

| Windows/QA | Open | P1 | Acceptance | M | Project | Physical Windows10/11 mic → double/double left Alt → active-editor paste and denied-mic test. Hosted Windows Server2025 native/synthetic checks cannot substitute for client OS acceptance. |
| Windows/Distribution | Open | P1 | Trust | M | Project | Obtain Authenticode publisher certificate and establish signed Windows release path. Current unsigned EXE/ZIP must disclose SmartScreen/Smart App Control limitations; never instruct blanket protection disablement. |
| Windows/Compatibility | Open | P2 | OS lifecycle | M | Project | Measure Windows10 target compatibility on a maintained LTSC/Enterprise installation. Ordinary Home/Pro is outside the current .NET10 support matrix. ARM-native Windows and optional LLM correction are not part of first x64 dictation release. |

| Windows/Recovery | Open | P2 | UX | M | Project | Isolate UI Automation provider for restartable recovery; a hung provider currently requires app restart and safely falls back to manual copy. Add explicit corrupted-model backup/repair UI; current different-hash file is preserved and manual move/reselect is explained. |

| Windows/Performance | Open | P2 | Measurement | M | Project | Measure CPU inference latency separately from model download; final hosted ASR step includes both. Benchmark optional CPU runtime variants before changing the portable baseline; no real-time speed guarantee is claimed. |
| Release/Windows | Done | P2 | Governance | M | Project | Root-invoked windows/scripts/check-delivery.py validates independent Windows stable/working pointers, latest-windows schema/tag/source/hashes and optional actual build package bytes/sourceSHA/runtime pins in the existing final manual workflow. Native execution remains a separate gate. |

## Notes

- Исторические TODO уровня `1.1` не удалены по смыслу: часть из них реализована, часть перенесена в таблицу выше.
- Бесконечное ожидание `whisper-cli` закрыто в `release/1.5.0` через bounded 30-минутный timeout. Оставшийся долг — runtime evidence и UX для экстремально длинных диктовок.
- Cleanup stale `/tmp/mac_dictate_dist.wav` и `.txt` закрыт в `release/1.5.0` через `RecordingService`.
- Text improvement добавлен как optional enhancement: отсутствие Qwen model или runtime failure не блокирует диктовку, длинный input > 6 000 символов fallback-ится к Whisper-тексту, preferred-моделью стала Qwen2.5-3B с fallback на 1.5B, а редакторское поведение управляется `TextImprovementProfile`. Runtime distribution для `llama.cpp` закрыт clean bundled path в `release/1.5.2`; long-text chunking, latency/RAM evidence и corpus-based quality tuning остаются отдельными debt items.
- Debug session logging добавлен как локальный opt-in инструмент диагностики качества. Он сохраняет чувствительные аудио/текстовые artifacts только на устройстве; user-facing управление retention/cleanup остается отдельным debt item.
- Каждый крупный спринт должен оставлять след здесь, если появились новые незавершенные риски или остаточные компромиссы.

| Windows/QA | Done | P1 | Hosted first-run 1.6.1 | M | Project | Final CI40747430459/source56b45301 passed; actual JSON/PNG and exact package bytes read back. Real bundled ASR uses synthetic PCM/key seams; normal installed UIA/Copy/reopen and 492-file payload/reinstall/uninstall checks passed. Physical/client-OS and native-DPI acceptance remains in the separate open Windows/QA item. |

| Windows/UX | Done | P1 | First-result viewport | S | Project | F1 repair verified in final CI40747430459: resultVisibleBeforeTestScroll=true, resultScreenshotsUseTestScroll=false for real-ASR onboarding and synthetic125/150% layout. Actual normal installed populated UIA/ValuePattern/Copy/clipboard PASS. Native client-monitor DPI remains NOT_RUN. |

| Windows/QA | Open | P2 | Evidence retention | S | Project | Final installed-normal JSON names an absent populated PNG (`installed-first-launch-smoke.-populated.png`). Correct screenshot retention in the next code iteration; do not repeat CI solely for this warning without authorization. Actual UIA/ValuePattern/clipboard passed; separate real-ASR result PNG retained. |
| Release/Windows | Open | P1 | Pages delivery 1.6.1 | S | Project | GitHub v1.6.1 is public with make_latest=false; actual tag/source/timestamp and four asset sizes/digests read back. Windows registry/manifest/HTML pins promoted from that evidence. Remaining: final authorized Pages push, browser/HTTPS/file/download hash checks. Preserve global Mac latest. |
| Windows/QA | Open | P2 | Model download and installer interaction | S | Project | Actual GUI HTTP-success model download, interactive installer wizard/auto-launch option and SmartScreen were not exercised. GUI recovery/persistence used explicit seams; real pinned model download for ASR used the script. Check these interactive paths separately. |
