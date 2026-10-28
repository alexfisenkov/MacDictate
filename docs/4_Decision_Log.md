# Decision Log

## D-019 — Website latest DMG must mirror public stable release

- **Дата:** 2026-05-11
- **Решение:** при каждом публичном desktop-релизе GitHub Release остается каноническим местом публикации, но сайт `macdictate.pro` обязан зеркалить тот же notarized DMG как `/downloads/MacDictate_Latest.dmg`. Версия, asset name и SHA фиксируются в `web-landing/downloads/latest-desktop.json` и сверяются с `releases/registry.json`.
- **Почему:** пользовательский путь начинается с сайта, а не с реконструкции GitHub release page. Если сайт отдает старый DMG, clean-install flow фактически проверяет не текущий продукт.
- **Ограничение:** сам бинарный DMG не хранится в git. Его нужно загружать в website hosting/storage при release-публикации; `scripts/verify_release_governance.sh --online` проверяет доступность alias, но не заменяет deployment step.

## D-020 — Fresh installs get bounded connectivity grace on license outage

- **Дата:** 2026-05-11
- **Решение:** если свежий Mac еще не имеет server-confirmed license snapshot, а `GET /api/license/status` временно недоступен, MacDictate включает 24-часовой локальный grace с warning diagnostic. Первый успешный server response очищает этот локальный grace.
- **Почему:** backend уже выдает новым устройствам 60-дневный trial, поэтому кратковременный TLS/API outage не должен блокировать первую диктовку на чистой установке.
- **Ограничение:** это не заменяет production availability. Live-аудит показал TLS-handshake timeouts до Express route, поэтому reverse proxy / host layer все равно нужно чинить отдельно.

## D-018 — v1.5.1 becomes signed public stable and next line is 1.5.2

- **Дата:** 2026-05-10
- **Решение:** зафиксировать desktop `v1.5.1` как публичный stable release на Developer ID/notarized distribution path, а дальнейшую работу вести в линии `release/1.5.2`.
- **Почему:** `1.5.1` закрывает брендовые иконки, last-dictation recovery, динамическую status bar индикацию и критичный regression микрофона после hardened runtime подписи.
- **Ограничение:** первый переход пользователей со старой ad-hoc сборки на Developer ID может потребовать однократного повторного permission approval; последующие Developer ID обновления должны сохранять trust identity при неизменных bundle id, Team ID и `/Applications/MacDictate.app`.

## D-017 — Public desktop DMGs require Developer ID signing and notarization

- **Дата:** 2026-05-10
- **Решение:** новые публичные desktop-релизы MacDictate нельзя публиковать с ad-hoc подписью или `Apple Development` identity. Release-сборка должна использовать `Developer ID Application`, hardened runtime (`codesign --options runtime`), timestamp, notarization и stapling DMG.
- **Почему:** ad-hoc identity привязана к cdhash конкретной сборки. При обновлении macOS может считать приложение новым binary identity, из-за чего Accessibility permission требует ручного удаления старой записи и повторного добавления. Developer ID identity должна стабилизировать designated requirement между версиями.
- **Ограничение:** первый переход с ad-hoc на Developer ID может потребовать однократного повторного Accessibility approval. Дальше обновления должны сохранять разрешение при неизменных bundle id, Team ID, signing identity и `/Applications/MacDictate.app`.

## D-016 — v1.5.0 becomes public stable and next line is 1.5.1

- **Дата:** 2026-05-09
- **Решение:** зафиксировать desktop `v1.5.0` как публичный stable release, а дальнейшую работу вести в линии `release/1.5.1`.
- **Почему:** линия `release/1.5.0` закрыла запланированные слои: bounded Whisper runtime, license hardening, diagnostics, release governance, модульную app-архитектуру и optional local text improvement через вторую нейросеть.

## D-001 — Working line goes to 1.5.0, not 1.4.3

- **Дата:** 2026-04-19
- **Решение:** Продолжать линию как `release/1.5.0`.
- **Почему:** изменения уже затрагивают не один bugfix, а product surface целиком: app licensing, backend checkout, docs/governance и архитектуру app-layer.

## D-002 — Backend / web / legal are part of the product surface

- **Дата:** 2026-04-19
- **Решение:** считать `backend/`, `web-landing/`, `docs/legal/` частью канона продукта, а не внешними случайными папками.
- **Почему:** desktop app зависит от live `/api/license/status`, checkout и legal copy; их нельзя больше рассматривать отдельно от продукта.

## D-003 — App layer is modularized around responsibilities

- **Дата:** 2026-04-19
- **Решение:** `AppController.swift` становится thin composition root, а license/diagnostics/hotkeys/transcription/paste/UI выделяются в отдельные файлы.
- **Почему:** giant hotspot уже начал смешивать несвязанные обязанности и мешал безопасным изменениям.

## D-004 — Rollback discipline is tag-based

- **Дата:** 2026-04-19
- **Решение:** перед рискованными этапами ставить annotated checkpoint tags.
- **Почему:** локальная рабочая линия может быть грязной и многослойной; tag дает быстрый rollback anchor без лишней веточной акробатики.

## D-005 — Secrets live only in env / secret storage

- **Дата:** 2026-04-19
- **Решение:** hardcoded secrets и proxy credentials запрещены.
- **Почему:** payment/licensing слой уже production-sensitive; секреты в коде ломают безопасность и дисциплину деплоя.

## D-006 — Offline grace is bounded, not infinite fail-open

- **Дата:** 2026-04-19
- **Решение:** app-side fallback работает через bounded cached grace.
- **Почему:** нужен компромисс между UX при кратковременном outage и защитой от бесконечного бесплатного доступа при сетевых ошибках.

## D-007 — Desktop releases are governed by a release ledger

- **Дата:** 2026-05-08
- **Решение:** все desktop-версии MacDictate ведутся через `docs/7_Release_Governance.md`, `releases/registry.json` и `releases/versions/<version>/RELEASE.md`.
- **Почему:** исторические DMG, tags и GitHub Releases уже расходились; будущим агентам нужен единый канон, а не реконструкция по случайным файлам.

## D-008 — Binary artifacts are local/archive assets, not code source of truth

- **Дата:** 2026-05-08
- **Решение:** локальные DMG/build logs хранятся в `releases/versions/*/artifacts/` или `releases/archive/*/artifacts/`, игнорируются git и описываются через манифест/checksum.
- **Почему:** Git source должен оставаться управляемым, а публичным каналом распространения DMG является GitHub Release asset.

## D-009 — Historical version uncertainty is explicit

- **Дата:** 2026-05-08
- **Решение:** `v1.2`, `v1.3`, `v1.4.1-local` и локальный `v1.4.2` DMG помечаются с уровнем доверия и оговорками в registry/RELEASE.md.
- **Почему:** лучше честно показать reconstructed/local-only историю, чем выдавать непроверенные артефакты за полноценный канон.

## D-010 — Release structure is locked by policy and verification

- **Дата:** 2026-05-08
- **Решение:** новые desktop-версии запрещено вести вне схемы `releases/versions/<version>/` + одноименная запись в `releases/registry.json`; нарушение считается блокирующим состоянием проекта.
- **Почему:** текстовых правил недостаточно для длинной истории релизов. Структура должна быть машинно проверяемой, чтобы будущие люди и агенты не создавали параллельные каталоги, локальные "релизы" и неучтенные артефакты.

## D-011 — Release governance check runs in GitHub Actions

- **Дата:** 2026-05-08
- **Решение:** `.github/workflows/release-governance.yml` запускает `scripts/verify_release_governance.sh` на push/PR в основные рабочие ветки.
- **Почему:** локальная дисциплина полезна, но запрет на нарушение структуры должен быть виден и на GitHub, чтобы pull request не проходил без актуального release ledger.

## D-012 — Text improvement uses optional Qwen GGUF via llama.cpp

- **Дата:** 2026-05-08
- **Решение:** вторую локальную нейросеть для коррекции текста строим как optional layer: `Qwen2.5-1.5B-Instruct-GGUF` quantization `Q4_K_M` запускается через `llama.cpp` runtime (`llama-completion` в актуальном Homebrew), а модель хранится отдельным `.gguf` файлом `qwen2.5-1.5b-instruct-q4_k_m.gguf`. Для первого внедрения Qwen получает только input до `6_000` символов; длинные тексты fallback-ятся к cleaned Whisper text без попытки генерации.
- **Почему:** Qwen2.5-1.5B достаточно легкий для M1/16 GB, официально мультиязычный, поддерживает instruct-following и structured output, а GGUF/llama.cpp повторяет уже принятый в MacDictate паттерн внешнего локального CLI-процесса. 7B/8B варианты дают лучшее качество, но увеличивают cold-start, RAM/disk footprint и риск UX-регрессии для фоновой диктовки.
- **Источники:** `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF`, `https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct`, `https://www.mintlify.com/ggml-org/llama.cpp/installation`.
- **Ограничение:** отсутствие Qwen/`llama.cpp` runtime не блокирует базовую диктовку. При failure automatic text improvement должен fallback-ить к cleaned Whisper text.

## D-013 — Qwen quality is guided by an editor profile before fine-tuning

- **Дата:** 2026-05-08
- **Решение:** улучшение качества второй нейросети сначала делается через `TextImprovementProfile.professionalCopyEditor`: prompt rules, terminology packs и speech-normalization hints. Настоящий LoRA/fine-tune откладывается до появления реального корпуса пар `raw Whisper text -> desired edited text`.
- **Почему:** GGUF-модель внутри app не дообучается напрямую. Prompt/profile слой быстрее, локальнее, проверяемее и безопаснее для смысла текста. Fine-tune без корпуса пользовательских диктовок будет дороже, медленнее и менее контролируем.
- **Ограничение:** терминологические пакеты не являются исчерпывающей энциклопедией. Они задают канонические написания и контекстные подсказки; новые термины должны добавляться по мере реальных ошибок.

## D-014 — Copywriting datasets are secondary quality material, not the main correction corpus

- **Дата:** 2026-05-08
- **Решение:** рекламные/copywriting датасеты HuggingFace (`jaykin01/advertisement-copy`, `smangrul/ad-copy-generation`, `PeterBrendan/Ads_Creative_Text_Programmatic`, `RafaM97/marketing_social_media`) не используются как прямой первый fine-tune для MacDictate text improvement. Основной корпус должен собираться из реальных debug-сессий диктовки и утвержденных пар `raw Whisper text -> desired corrected text`.
- **Почему:** задача MacDictate — исправлять диктовку, оформлять абзацы/списки и сохранять смысл. Датасеты рекламной генерации учат модель писать продающий copy и могут усилить нежелательное переписывание, добавление фактов, CTA и маркетингового тона.
- **Как использовать:** после license review и фильтрации эти датасеты можно применять как вторичный материал для style/eval наборов или отдельных экспериментов, но не смешивать с базовым корректором без контрольных тестов на смысловую сохранность.
- **Источники:** `https://huggingface.co/datasets/jaykin01/advertisement-copy`, `https://huggingface.co/datasets/smangrul/ad-copy-generation`, `https://huggingface.co/datasets/PeterBrendan/Ads_Creative_Text_Programmatic`, `https://huggingface.co/datasets/RafaM97/marketing_social_media`.

## D-015 — Preferred text-improvement model moves to Qwen2.5-3B with 1.5B fallback

- **Дата:** 2026-05-08
- **Решение:** для desktop `1.5.0` preferred-моделью второй нейросети становится `Qwen2.5-3B-Instruct-GGUF` quantization `Q4_K_M`, локальный filename `qwen2.5-3b-instruct-q4_k_m.gguf`. Уже внедренная `Qwen2.5-1.5B-Instruct Q4_K_M` остается legacy fallback, если 3B отсутствует или не прошла size validation.
- **Почему:** реальные debug-сессии показали, что 1.5B часто слишком консервативна для смыслового форматирования диктовки: может не выделить абзацы/списки и не исправить очевидные ASR-искажения терминов. 7B дает больше качества, но пользовательский runtime-сбой после попытки тяжелой модели показал высокий риск для M1/16 GB. 3B — промежуточный вариант: больше capacity, чем 1.5B, но заметно меньше диск/RAM footprint, чем 7B.
- **Runtime guardrails:** text improvement остается optional enhancement; отсутствие 3B не блокирует диктовку. Timeout увеличен до `10` минут, context до `8_192` tokens, input limit `6_000` символов сохранен.
- **Источники:** `https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF`, `https://huggingface.co/Qwen/Qwen2.5-7B-Instruct-GGUF`.

## D-016 — Local AI runtimes are bundled for user builds

- **Дата:** 2026-05-10
- **Решение:** начиная с рабочей линии `release/1.5.2`, пользовательский macOS artifact должен содержать оба локальных runtime внутри `.app`: `whisper-cli` и `llama-completion`/`llama-cli` в `Contents/Resources/bin`, transitive `.dylib` dependencies в `Contents/Resources/lib`, ggml backend plugins в `Contents/Resources/libexec/ggml`, install names переписаны на bundle-relative `@rpath`, nested Mach-O подписаны до подписи основного app bundle. Homebrew paths остаются только developer fallback, а не пользовательским требованием.
- **Почему:** clean-install flow не должен требовать от обычного пользователя устанавливать Homebrew, `whisper.cpp`, `llama.cpp`, OpenSSL/libomp или понимать dynamic library paths. Whisper model скачивается на первом запуске, Qwen model может скачиваться лениво после включения `Улучшить текст`, но runtime, который запускает обе модели, обязан быть частью приложения.
- **Проверка:** `build.sh` по умолчанию требует bundled runtimes; `scripts/check_bundled_whisper_runtime.sh` и `scripts/check_bundled_llama_runtime.sh` проверяют arm64/Mach-O, signatures, запуск без `dyld` errors и отсутствие `/opt/homebrew` / `/usr/local` ссылок; `scripts/check_distribution_signing.sh` и `scripts/check_install_artifact_flow.sh` включают эти проверки для distribution readiness.
- **Ограничение:** notarization для рабочих тестовых 1.5.2-сборок может быть отключена, но публичный release path должен проходить обычный Developer ID + notarization контур.

## D-021 — Бесплатный macOS desktop без лицензирования

- **Дата:** 2026-10-19
- **Решение:** по прямому указанию владельца macOS MacDictate становится бесплатным без срока действия. Из desktop runtime удаляются license state/cache/client, license-запросы и refresh timer, machine ID, trial/grace, paywall и переход к оплате. Доступ к записи зависит только от локальной модели/runtime и системных разрешений.
- **Почему:** диктовка на устройстве должна запускаться без лицензии и доступности license server. Постоянный бесплатный режим задается составом приложения, а не поддельной оплаченной лицензией или увеличенным сроком grace.
- **История и данные:** прежние четыре Swift-файла сохранены в `archive/legacy-licensing/src/License/`, три `test_license_*` harness — в `archive/legacy-licensing/scripts/`; архив не компилируется в app. Новые debug metadata не содержат machine ID. Старые debug-сессии и legacy UserDefaults остаются нетронутыми.
- **Публичный переход:** владелец подтвердил выпуск для всех в той же задаче. Старый `GET /api/license/status` сохраняет типы полей и возвращает free active access без изменения данных оплаты; `/api/plans` возвращает пустой массив, `/api/payment/create` — HTTP410. Исторический каталог и webhook сохранены для сверки прежних заказов. Публичный release/read-back выполнен через GitHub Releases и Pages по D-022. Backend free policy остаётся проверенным исходником совместимости, а не утверждением о deployed API.

## D-022 — Free distribution without the retired server

- **Дата:** 2026-10-19
- **Контекст владельца:** «сервак отключен».
- **Решение:** public release assets и stable download alias размещаются на GitHub Releases; app проверяет updates непосредственно через GitHub API. Отключённый website/API не является зависимостью бесплатного app. D-019 website mirror применяется только к прежнему серверному каналу; для GitHub-канала проверяется publicUrl из version manifest и asset digest.
- **Страница продукта:** статический сайт без checkout опубликован на https://alexfisenkov.github.io/MacDictate/; HTTPS read-back 14 файлов подтвердил snapshot. DNS и прежний backend не менялись. Старые приложения получают бесплатный runtime только после установки новой версии; их прежний badge/offline cache серверным ответом удалить нельзя.
- **Данные:** прежний сервер не включается и неизвестный новый SSH-ключ не принимается. Старые платежные записи/секреты не переносятся; backend free policy хранится в исходниках для возможного последующего восстановления совместимости.

## D-023 — Windows desktop in the existing desktop repository

- **Дата:** 2026-10-19.
- **Решение:** Add `windows/` to the existing desktop Git repo. The physical repository root remains `macos/`; Swift stays in `src/`, Windows policy/runtime in `windows/src/`. Avoid renaming mature sources or creating another public repo. .NET10 WinForms + Win32 wrappers; self-contained x64 distribution with pinned CPU whisper.cpp and explicitly downloaded multilingual Whisper small. No licensing and no default Qwen correction on Windows.
- **Почему:** The user requested Windows support and selected double Alt. Native UI and separated policy/native services preserve architecture and can be checked on a Windows runner.
- **Ограничение:** Windows10/11 are compatibility targets; hosted `windows-2025` is Server2025, not client-OS physical acceptance. Windows10 Home/Pro is outside .NET10's official OS lifecycle support. No Authenticode certificate is available, so current Windows packages are unsigned. Microphone/hotkey/real editor acceptance remains explicit.

## D-024 — Final coordinated GitHub desktop verification

- **Дата:** 2026-10-19.
- **Решение:** The owner explicitly requested GitHub checks for desktop1.6.0. Use one manual `.github/workflows/desktop-release.yml` run after local source/tests/review, on exact main SHA. No push/PR triggers; final Windows release artifacts come from that run. macOS signed/notarized distribution is built locally from the same checked SHA; keep private signing material off hosted runners.
- **Почему:** Adds native Windows build/integration evidence while preserving the owner’s one-final-CI policy and Apple signing boundary.
- **Ограничение:** A failed check blocks publication. A targeted rerun requires a recorded concrete failure/fix. Pages branch push is a separate automatic deployment and occurs only after complete staging QA.

- D-023 implementation refinement: the native CLI embeds UTF-8 process-codepage manifest, verified by mt.exe read-back. Minimum installer Windows10 build19041 (2004+) to support Unicode profile/model/WAV/temp paths; ASR CI explicitly exercises Cyrillic, spaces and emoji for all inputs and temporary output.


## D-025 — Independent Windows hotfix and first-run evidence

- **Дата:** 2026-10-29.
- **Решение:** Windows1.6.1 is an independent hotfix. `current.windows.publicStable`/`workingLine` are additive platform pointers. Legacy `current.publicStable`, `latest-desktop.json`, macOS bundle1.6.0/build14 and global GitHub latest remain unchanged. The Windows release must set `make_latest=false`; its public download URLs use `/releases/download/<tag>/<versioned-asset>`, never global `/latest/`.
- **Версия/имена:** candidate version lives once in the Windows csproj. `release-info.ps1` derives version/tag/EXE/ZIP names for build/installer/tests; CI upload uses version-neutral globs only in its fresh dist. `latest-windows.json` is the published Windows download identity; landing reads it and retains pinned HTML fallback links.
- **Приёмка:** one final manual desktop workflow after local checks/review. One actual bundled Whisper invocation is driven by the visible UI using runner-generated synthetic speech; capture/key seams are explicit and isolated. Two additional synthetic layout125/150% runs scale geometry/fonts, verify bounds and retain PNG; actual desktop DPI is reported separately. Normal installed launch runs without test CLI in an empty real runner profile. Every installed file and generated package hash/sourceSHA is checked.
- **Ограничение:** this evidence is Windows Server2025 + synthetic inputs, not physical Windows10/11 microphone/Alt/editor or native monitor125/150%. Raw audio/model are not uploaded. Safe diagnostics contain only version/status metadata. No Authenticode signature is claimed.
- **Публикация:** candidate registry entry and site source may be prepared locally, but published manifest remains1.6.0 until actual release digest/source read-back. New UI instructions are staged for1.6.1 and must not be pushed to Pages before that promotion.

- **Реализация / 2026-10-29:** final source56b45301/run40747430459 passed hosted G4. Canonical v1.6.1 is `local_only`; Windows stable and public URLs stay1.6.0 until actual publication read-back. A Windows-only tag must point to checked build source, not a later metadata-only commit. Local Latest-named package copies are verification artifacts, not public aliases. Missing populated installed PNG is retained as evidence debt; no physical client-OS/native-DPI acceptance is inferred.

- **Публикация / 2026-10-29:** actual GitHub release ID427078400/publishedAt2026-10-28T19:07:43Z and4asset size/digest read-back satisfied D-025 promotion gate. Only Windows stable/manifest/HTML pins promoted to1.6.1; global Mac latest stays1.6.0. Pages/browser/HTTPS/full download hash evidence remains a separate unfinished gate.
