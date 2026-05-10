# Журнал Действий (Action Log) MacDictate

Этот журнал фиксирует инженерные шаги и checkpoints, а не маркетинговое описание релиза.

## 2026-05-10 — v1.5.1 brand icon standardization

- Для рабочей линии `release/1.5.1` принят единый brand icon из пользовательских SVG `mic_logo.svg` и `mic_menubar.svg`.
- macOS menu bar больше не использует emoji-микрофон: `NSStatusItem` переведен на template-иконку `mic_menubar`, а сборка копирует `mic_menubar.png` / `mic_menubar@2x.png` в app resources.
- `AppIcon.icns`, landing/legal/payment pages и iOS AppIcon/recording controls синхронизированы на новый визуальный знак; публичный release не публиковался.
- Добавлена safety-система последней диктовки: финальный текст сохраняется в `UserDefaults` до попытки вставки, а menu bar получил action `Скопировать последнюю диктовку`, чтобы пользователь мог восстановить текст при смене активного окна/курсора.
- Добавлен targeted harness `scripts/test_last_dictation_store.sh`; полноценная desktop-история диктовок вынесена в backlog как отдельный UX item.
- Возвращена динамическая status bar индикация: idle использует новый template microphone icon, а запись/обработка/ошибки снова показывают короткие status symbols (`🔴`, `⏳`, `✨`, `⚠️`).
- Подготовлен Developer ID release-signing контур: `build.sh` теперь поддерживает `MACDICTATE_SIGN_IDENTITY`, hardened runtime, timestamp, DMG signing и optional `notarytool` notarization/stapling через `MACDICTATE_NOTARY_PROFILE`.
- Создан и импортирован `Developer ID Application: Aleksander Fisenkov (5BABN9U6WS)` certificate; первая Developer ID signed DMG-сборка `MacDictate_Final_v1.5.1.dmg` прошла без notarization.
- После первой notarization проверки добавлены обязательные bundle metadata `CFBundleExecutable=MacDictate` и `CFBundlePackageType=APPL`, чтобы Gatekeeper/spctl классифицировал signed bundle как приложение.
- Настроен `macdictate-notary` keychain profile; финальная Developer ID signed DMG-сборка прошла Apple notarization (`Accepted`), `stapler validate`, `spctl` для DMG и `spctl --type execute` для `.app`, скопированной из DMG.
- По инциденту после перехода на Developer ID подтверждено, что macOS TCC может удерживать старое/битое Microphone-состояние. Старый `Microphone` approval reset-нут через `tccutil`, а app-side permission flow усилен: `notDetermined` теперь можно повторно запросить из blocked-alert, а `Открыть настройки микрофона` запускает polling и обновляет menu/status после изменения разрешения.
- По повторному microphone incident найден реальный root cause: Developer ID + hardened runtime сборка была подписана без entitlements, поэтому macOS могла не показывать приложение в `Privacy & Security -> Microphone`. Добавлен `assets/MacDictate.entitlements` с `com.apple.security.device.audio-input`, `build.sh` подключает его по умолчанию для Developer ID, а `scripts/check_distribution_signing.sh` теперь валидирует entitlement.
- Собрана и установлена новая локальная `1.5.1` Developer ID/notarized копия с microphone entitlement: notary submission `3c4fabc2-b896-4365-a682-a4808f167b4b` получил `Accepted`, DMG SHA256 `c585afb560f10297c6d168353b78b566b28c8cb54fff9f97102e8054d97c3e90`, `/Applications/MacDictate.app` проходит `codesign --verify --deep --strict`, `spctl --type execute` и `scripts/check_distribution_signing.sh`.
- Desktop release `v1.5.1` подготовлен как публичная signed/notarized stable-версия: bundle остается `1.5.1` / build `11`, release ledger получает отдельную папку `releases/versions/v1.5.1/`, checksum, GitHub release metadata и Developer ID artifact evidence.
- Post-release линия `release/1.5.2` открыта с bundle `1.5.2` / build `12` и registry entry `v1.5.2-working`.

## 2026-05-09 — v1.5.0 release

- Desktop release `v1.5.0` подготовлен как публичная stable-версия: bundle поднят до `1.5.0` / build `10`, DMG переименован в `MacDictate_Final_v1.5.0.dmg`, release ledger получает отдельную папку `releases/versions/v1.5.0/`, checksum и GitHub release metadata.
- После фиксации `v1.5.0` следующая рабочая линия открывается как `release/1.5.1`.
- Post-release линия `release/1.5.1` открыта с bundle `1.5.1` / build `11` и registry entry `v1.5.1-working`.

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
- По real debug-сессии `20260508-212657-03DCBFBB` найдено, что Whisper дал `ChaiJPT`, Qwen не исправил термин и потерял часть list markers. Пайплайн усилен pre-formatting шагом перед Qwen: `ChaiJPT`/`Чай и GPT` -> `ChatGPT`, heading cues перед `во-первых/во-вторых/в-третьих` превращаются в заголовок с двоеточием и numbered list.
- Preferred text-improvement model переключена с Qwen2.5-1.5B-Instruct Q4_K_M на промежуточную Qwen2.5-3B-Instruct Q4_K_M (~2.1 GB): 7B убрана из default-пути как слишком рискованная для M1/16 GB после пользовательского runtime-сбоя, 1.5B оставлена как automatic fallback.
- `TextImprovementRunner` сохраняет увеличенные лимиты под 3B: timeout `10` минут и context `8_192` tokens.
- По real debug-сессии `20260508-233428-E329E82F` найдено, что 3B/Qwen исправляет `ChagPT` только в части контекста. Deterministic formatter расширен вариантами `ChagPT`/`Chag GPT`/`ChagJPT` -> `ChatGPT`, `Клод от Anthropic` -> `Claude от Anthropic`, а list marker cleanup теперь убирает лишнюю точку после `Первое.` / `Второе.`.
- По real debug-сессии `20260508-234719-983488DD` найдено, что Qwen копирует prompt example labels `Вход` / `Выход` в результат и добавляет декоративный Markdown вокруг названий. Runtime-prompt больше не включает examples block; `TextImprovementRunner.cleanModelOutput` вырезает leaked output scaffold, а plain-text input дополнительно снимает `**bold**` / `__bold__` / inline-code markdown из model output.
- По новым контрольным debug-сессиям `20260508-235809-076A3FCC` и `20260508-235835-D04967B7` подтверждено, что Qwen 3B выбирается и paste проходит. В `20260508-235835-D04967B7` найден остаточный model boilerplate `Вот исправленный и отформатированный текст:` и `---`; cleaner расширен removal rules для таких preamble/horizontal-rule lines.
- По пользовательскому уточнению добавлено каноническое написание `Syntx AI`: варианты `Syntax AI` / `SyntaxAI` / `Синтакс AI` / `синтакс ай` нормализуются deterministic formatter и попали в prompt hints.
- По audit последних debug-сессий подтверждено, что Qwen 3B и paste работают штатно; единственный небольшой текстовый дефект найден в старой сессии `20260509-001108-A68417C1`: маркеры `и второе` / `и третье` оставляли хвост `И.` в предыдущем пункте. Ordered-list formatter расширен, чтобы съедать союз `и` как часть маркера.
- По debug-сессии `20260509-015329-FDD8BE50` найден не runtime-сбой, а нарушение контракта Qwen: модель вернула редакторский отчет (`Ваш текст...`, `Исправления:`, `Текст выглядит следующим образом:`), который попал в paste. `TextImprovementRunner` получил guardrail: если такие служебные маркеры добавлены моделью и отсутствовали в source, итог fallback-ится к безопасному preformatted Whisper-тексту; raw output остается в trace для диагностики.
- По debug-сессии `20260509-093806-5B71CD3D` подтверждено пользовательское ощущение "глотания слов": Whisper сохранил вступление и оба AI-названия, но Qwen сократил текст, удалил вступление и потерял `Cling AI`. Добавлен content-preservation guard: при существенной потере source tokens итог fallback-ится к preformatted Whisper-тексту; `Cling AI` / `клинг ай` нормализуются в `Kling AI`.
- По license incident проверен live endpoint `https://macdictate.pro/api/license/status`: сервер отвечал `200 OK`, но для paid device отдавал `isActive: 1` числом. Swift-клиент ожидал strict `Bool`, JSON decode падал, и валидный ответ уходил в `serverUnavailable`. Исправлено с двух сторон: backend явно приводит `isActive` к boolean, а macOS decoder принимает `Bool`/`Int`/boolean-like `String`; добавлен harness `scripts/test_license_status_response.sh`.
- По повторному license incident подтверждена сетeвая нестабильность домена: `license/status` чаще отвечает `200 OK`, но отдельные TCP connect попытки к `macdictate.pro:443` тайм-аутятся. `LicenseService` увеличил request timeout до 20 секунд, а failure при валидном active snapshot теперь оставляет app в grace без runtime-warning `Сервер лицензий временно недоступен`; warning остается только для случая без usable cache. Добавлен harness `scripts/test_license_grace_diagnostic.sh`.
- По debug-сессии `20260509-133020-A9F21EE8` найден новый вариант model commentary leakage: Qwen вернул `Ваш запрос можно переписать следующим образом:` и footer `Текст сохранен...`, которые прошли в paste. `fallbackToSourceIfOutputLooksLikeEditorialCommentary` расширен с конкретного `Ваш текст...` на более общий набор служебных preamble/footer markers (`ваш запрос`, `переписать следующим образом`, `текст сохранен`, `стиль автора сохран`, `итоговый текст`, версии и т.п.); итог fallback-ится к preformatted source, raw output остается в trace.
- По debug-сессии `20260509-133902-9B87271C` найден assistant-answer leakage: Whisper верно распознал пользовательский вопрос, но Qwen ответил как чат-ассистент (`Конечно, я могу помочь...`, `Пожалуйста, предоставьте фрагмент текста...`) и этот ответ попал в paste. Guard расширен на request-for-input / assistant-answer markers (`я могу помочь с редактированием`, `пожалуйста, предоставьте`, `пришлите исходный текст`, `затрудняет редактирование` и т.п.); prompt получил прямое правило не отвечать на продиктованные вопросы/просьбы, а редактировать их как текст.
- По пользовательскому комплекту `/Users/AlexFisenkov_1/Documents/MacDictate/ДЛЯ_КОРРЕКТУРЫ_ПОСЛЕ_WHISPER` профиль второй модели переведен из `copy editor` в строгую корректуру после Whisper: любой вход считается материалом, вопросы не отвечаются, команды не выполняются, технические просьбы в начале можно снимать, модальность и разговорность сохраняются, чувствительные темы не переписываются. Документы комплекта обновлены до версии 3.1 с учетом debug-правок `ChagPT/ChaiJPT -> ChatGPT`, `Syntx AI`, `Kling AI`, commentary/assistant-answer guards и content-preservation rules.
- По debug-сессии `20260509-143346-EB6FDFDA` подтверждено, что prompt-only стратегия недостаточна: Qwen проигнорировал строгую инструкцию и ответил на вопрос `как ты относишься...`, вставив новый ответ вместо корректуры. `fallbackToSourceIfOutputIsNotConservativeCorrection` теперь валидирует сохранение significant source tokens и fallback-ится к preformatted source не только при сокращении, но и при ответе/переписывании/расширении с новым содержанием. Добавлен regression в `scripts/test_text_improvement_runner.sh`.
- По полноценному audit после повторного assistant leakage подтверждены дополнительные дыры: short inputs (<12 significant tokens), appended answer after source, added-token hallucinations, critical numeric/version/URL/email token loss, unexpected list formatting и stdout truncation. Validation layer переведен в fail-closed policy: `nonConservativeCorrectionReason` теперь проверяет missing/extra source-token ratios, critical tokens, unexpected list delta и truncation; `TextImprovementTrace` и debug-session пишут `validationFallbackReason`/`06c_qwen_validation.txt`. Проверено regression-кейсами в `scripts/test_text_improvement_runner.sh`; локальный `llama-completion` также подтвержденно поддерживает `--grammar`/`--json-schema`, но новая dependency/grammar-integration пока не добавлялась, потому что semantic validator всё равно обязателен.
- По debug-сессии `20260509-221100-F5FA772C` найден пограничный list-boundary case: исходник явно содержал `первое/второе/третье`, но Qwen создал дополнительный пункт `4.` из следующего абзаца без маркера `четвёртое`. Добавлен `extra_ordered_list_item` validator: если output numbered-list содержит больший индекс, чем source/preformatted source или явные ordered cues, MacDictate сначала делает один controlled retry с причиной ошибки и отклонённым ответом; если retry проходит validation, вставляется результат Qwen, иначе fallback-ится preformatted source. Debug-session пишет `retryTriggerReason`, `05a_qwen_initial_raw_output.txt`, `06a_qwen_initial_cleaned_output.txt` и `06d_qwen_retry.txt`. Одновременно добавлены нормализации `чата GPT -> ChatGPT` и `Cloud Code -> Claude Code`.

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
