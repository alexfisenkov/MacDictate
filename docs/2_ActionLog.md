# Журнал Действий (Action Log) MacDictate

Этот журнал фиксирует инженерные шаги и checkpoints, а не маркетинговое описание релиза.

## 2026-10-19 — бесплатный macOS desktop без проверки лицензии

- Зафиксировано прямое решение владельца D-021: desktop бесплатен без срока действия. Из `AppController`, dictation gate, menu/status/diagnostics и новых debug metadata убраны license-зависимости, machine ID и переход к оплате. Проверки модели, runtime, микрофона и Accessibility сохраняются.
- Исторические четыре licensing Swift-файла и три `test_license_*` harness сохранены в `archive/legacy-licensing/`; `build.sh` рекурсивно компилирует только активный `src/`, архив в app не входит. Существующие UserDefaults и локальные debug-сессии не переписываются.
- Добавлен `scripts/test_free_desktop.sh`: source guard против licensing-зависимостей, компиляция всех активных app sources, реальные `NSMenu`/presentation assertions без лицензии, сохранение microphone/runtime diagnostics.
- Подтверждены локальные проверки: `scripts/test_free_desktop.sh`, `scripts/test_debug_session_logger.sh` (включая отсутствие machine ID), `scripts/test_update_checker_response.sh`, `scripts/check_architecture_guardrails.sh` и исходный release governance.
- Первая сборка выявила drift локального runtime cache после миграции Mac: cached Mach-O содержит старый absolute `LC_RPATH`, bundler fallback подтянул Homebrew dependencies с `minos=26`, guard корректно остановил artifact. Для следующей сборки выбран runtime из прежнего установленного bundle, прошедший обе runtime-проверки; воспроизводимая пересборка source-cache вынесена в backlog.
- Signed build12, mounted DMG install-flow и strict подпись установленного `/Applications/MacDictate.app` прошли; SHA исполняемого файла совпадает со сборкой, запущен именно desktop-процесс. Установленный Whisper распознал synthetic русскую фразу. Native UI дважды вернул timeout: live microphone/hotkey/paste не проверены.
- Владелец отдельно подтвердил бесплатный выпуск для всех. Подготовлены free landing/callback pages, RU/EN legal, backend free-access policy без записи devices/orders и HTTP410 для новых оплат. `scripts/test_free_access_backend.py` проходит на изолированной БД; исторические заказы и webhook не изменяются.
- Для публикации выделен clean release worktree: прежние незакоммиченные desktop/model/runtime изменения сохранены отдельным checkpoint, исходная рабочая копия не откатывалась. Кандидат `v1.5.2` build13 ведётся в release ledger.
- Production `macdictate.pro` на прежнем DNS IP предъявляет изменённые SSH-ключи и HTTPS TLS internal error; то же подтверждено из независимого доверенного сервера. Неизвестный ключ не принимался, production не изменялся. Notarization возможна через существующий ASC API key без восстановления отсутствующего Keychain profile.

- Владелец подтвердил: прежний сервер отключён. Выбран GitHub-only download/update канал (D-022), без принятия незнакомого SSH-ключа и без восстановления billing backend. Для публичной страницы используется статический GitHub Pages без изменения DNS. Backend free policy остаётся проверенным исходником, не выдается за deployed API.

- Публичный `v1.5.2` build13 выпущен на GitHub: оба DMG имеют SHA256 `8cd4c00cb2ddaa7fef2f747cee8b28f4d46b6e3b317a8e39206ac04c3752a261`, Apple notarization Accepted, staple/Gatekeeper/mounted install PASS; source main SHA `b8158a6a73f33e07cf548fa46658511f95c59811`. Статическая страница GitHub Pages и установка build13 подтверждены последующим read-back.

- Публичный download byte-read-back совпал с notarized SHA; установлен именно app из скачанного DMG build13, strict codesign/Gatekeeper/hash/process PASS. Реальный WhisperRunner установленного bundle с автоматическим выбором backend распознал synthetic speech. Полный mic/hotkey/paste остаётся NOT_RUN (native UI timeout).
- Факт-чек юридических текстов выявил отдельную лицензию Qwen2.5-3B-Instruct-GGUF для research/evaluation и необходимость отдельного разрешения производителя для коммерческого применения. RU/EN EULA явно отделяет это от бесплатного MacDictate/Whisper; модели и настройки пользователя не менялись. Рекламная абсолютность приватности и лишние банковские реквизиты убраны, гиперссылки указывают на новый статический сайт.

- GitHub Pages по адресу https://alexfisenkov.github.io/MacDictate/ опубликован из gh-pages6d02041. Системный HTTPS-клиент прочитал 14 страниц/документов/assets/manifest: все байты совпали с проверенным static snapshot, download ведёт на GitHub alias с тем же notarized SHA.
- Отклонение от правила одной финальной hosted-проверки: несмотря на первоначальный Pages API404, push ветки gh-pages автоматически включил Pages. Выполнились три автоматические выкладки:39244037539,39244118426,39245114809; все successful, финальная6d02041. Основной агент поздно проверил триггер. Дополнительных Pages push после финальной проверки нет; app CI не запускался по активному local-release режиму. Для следующих итераций staging должен оставаться вне connected gh-pages до полного QA.
- Основная рабочая копия приведена к main GitHub. Исходные незакоммиченные desktop/model/runtime изменения сохранены отдельным checkpoint03ef117 и pre-sync backups; пользовательские модели, настройки, история оплат, iOS и Transcribe не переписывались.

- Live default UpdateChecker получил публичный free1.5.2 при currentVersion1.5.1 напрямую из GitHub. Read-only TCC lookup показал microphone/accessibility allowed для app; Developer ID designated requirement совпадает с прежней desktop-подписью. Разрешения не изменялись, полный live mic/paste при этом не объявлен PASS. API-key notarization route задокументирован без секретных значений.

## 2026-05-12 — optional Whisper large-v3 test mode

- В рабочей линии `release/1.5.2` добавлен тестовый режим максимальной точности ASR без публикации релиза: settings menu получил toggle `Точная модель Whisper large-v3` и action `Скачать точную модель Whisper`.
- `ModelLocator` больше не выбирает Whisper-модель просто по максимальному размеру: balanced mode предпочитает `ggml-large-v3-turbo.bin`, maximumAccuracy mode предпочитает `ggml-large-v3.bin`, оба режима имеют fallback на другую валидную `.bin` модель.
- Добавлен persisted mode `MacDictateWhisperModelMode` и отдельный app-layer menu handler `AppController+WhisperModelMenu.swift`; если heavy-модель отсутствует, включение toggle открывает downloader и переключает режим только после успешной загрузки.
- Debug-session metadata/events теперь фиксируют `whisperModelMode`, а событие `whisper_started` пишет выбранный mode/path, чтобы сравнивать качество turbo и large-v3 по логам.
- Добавлен targeted harness `scripts/test_whisper_model_selection.sh` для проверки выбора turbo/large-v3/fallback и сохранения режима.
- После пользовательского smoke heavy-модели закрыт clean-Mac packaging blocker: `whisper.cpp` и `llama.cpp` runtimes пересобраны из upstream source tarballs под `macOS 11.0` deployment target, без Homebrew OpenSSL/OpenMP/BLAS dependencies.
- Bundled runtime layout разделен по слоям: llama dependencies живут в `Contents/Resources/lib/llama` и `libexec/ggml-llama`, Whisper dependencies — в `Contents/Resources/lib/whisper` и `libexec/ggml-whisper`. Это устраняет риск ABI-конфликта разных `libggml` версий в одном app bundle.
- `bundle_llama_runtime.py` / `bundle_whisper_runtime.py` больше не следуют install-name самой `.dylib` как runtime dependency, чтобы не подтягивать одноименные Homebrew dylibs через fallback search path.
- Добавлен `scripts/build_clean_runtimes.sh`: воспроизводимая сборка clean `llama-completion` и `whisper-cli` с проверкой `minos` и отсутствия `/opt/homebrew` / `/usr/local` ссылок перед release-style `./build.sh`.
- Локально собран `build/artifacts/MacDictate_Final_v1.5.2.dmg` с Developer ID подписью и без notarization для теста; `check_bundled_llama_runtime.sh`, `check_bundled_whisper_runtime.sh`, `check_distribution_signing.sh` и `check_install_artifact_flow.sh` подтверждают self-contained artifact path.

## 2026-05-11 — clean install release/download and license hardening

- Production перенесен на московский host `193.233.247.71` для `macdictate.pro`: настроены ключевые SSH aliases `macdictate-prod` и `macdictate-moscow`, установлены nginx/Docker Compose v2/certbot/sqlite3, перенесены static site, legal docs, backend code, runtime `.env` без вывода секретов, Let's Encrypt certificate и SQLite database через `VACUUM INTO`.
- DNS cutover подтвержден обычным live DNS: `macdictate.pro` и `www.macdictate.pro` резолвятся в `193.233.247.71`; `/`, `www`, `/api/health`, `/api/license/status`, `/api/plans` и `/downloads/MacDictate_Latest.dmg` работают; DMG SHA256 подтвержден как `f6234a26d09988bd9620e111717b631c5c5ea46d1621beffa46e5bea3ea6569e`.
- Follow-up audit закрыл stale server references: прямые упоминания legacy IP удалены из текущего проекта, `macdictate-prod` и `macdictate-moscow` в локальном SSH config теперь ведут на московский production host, а активные production paths на сервере не содержат legacy IP.
- Во время миграции между legacy host и Moscow host наблюдался TLS/HTTP timeout, поэтому прозрачный proxy не использовался; перед DNS cutover выполнен финальный SQLite snapshot, а новые live записи уже идут в московскую базу.
- Публичный update/download metadata `assets/version.json` возвращен на stable `1.5.1` и сайт alias `/downloads/MacDictate_Latest.dmg`, чтобы внешний пользовательский контур не рекламировал рабочую `1.5.2` до отдельного release approval.
- Зафиксировано release-правило: после каждого публичного desktop-релиза сайт обязан отдавать тот же stable DMG через `/downloads/MacDictate_Latest.dmg`; добавлен tracked manifest `web-landing/downloads/latest-desktop.json`, а `scripts/verify_release_governance.sh` теперь сверяет его с `registry.current.publicStable`.
- `docs/6_Release_Checklist.md` и `docs/7_Release_Governance.md` обновлены: GitHub Release больше не считается финалом, пока сайт не обновлен на тот же DMG.
- По pre-migration live-проверке `macdictate.pro` был подтвержден HTTPS/TLS timeout до Express route; production migration на московский host закрыла пользовательский download/API path.
- Follow-up audit: прямой доступ из локальной сети к legacy host зависал до SSH/HTTPS banner, но через jump host production shell был доступен. Точный root cause локального route timeout не подтвержден; на legacy host `ufw`/fail2ban inactive и явного ban/tarpit для локального исходящего IP не найдено.
- Production сайт обновлен из локального `web-landing/`, legal docs синхронизированы из `docs/legal/`, а `/var/www/macdictate.pro/downloads/MacDictate_Latest.dmg` заменен на `v1.5.1` bytes из `releases/versions/v1.5.1/artifacts/MacDictate_Final_v1.5.1.dmg`; SHA256 подтвержден как `f6234a26d09988bd9620e111717b631c5c5ea46d1621beffa46e5bea3ea6569e`.
- Production backend в `/opt/macdictate-backend` обновлен до текущего кода с `/api/health`, `/api/plans` и hardened license/payment routes; перед заменой созданы backups в `/root/macdictate-backups/`. Runtime secrets перенесены из server-side `docker-compose.yml` в локальный `.env` с правами `0600`, а контейнер теперь слушает только `127.0.0.1:3000` за nginx.
- Backend получил `/api/health` и `/healthz`, slow-request логирование без device ID, явные Node server timeout settings и SQLite WAL/busy-timeout для снижения риска локов на license/payment database.
- `LicenseService` получил bounded first-run connectivity grace: если на чистом Mac сервер лицензий недоступен до первого успешного ответа, приложение включает 24-часовой локальный grace с warning diagnostic, чтобы пользователь мог начать диктовку и не упирался в разовый outage.
- `WhisperRunner` и `LlamaCompletionRuntime` больше не передают `GGML_BACKEND_PATH` как директорию; добавлен `GGMLBackendLocator`, выбирающий конкретный bundled ggml backend file под Apple Silicon.
- Bundled runtime checks усилены: `check_bundled_whisper_runtime.sh` и `check_bundled_llama_runtime.sh` теперь запускают runtime с конкретным backend file, ловят `failed to load` / `no backends are loaded` и проверяют Mach-O deployment target относительно `LSMinimumSystemVersion`.
- First-run model downloader больше не может оставить LSUIElement-приложение в невидимом подвешенном состоянии: закрытие окна отменяет загрузку и завершает app вместо silent background state.
- Добавлены `docs/11_Backend_Ops_Runbook.md` и `scripts/check_public_services.sh` с health checks, timeout triage и production commands для диагностики `macdictate.pro`.

## 2026-05-10 — v1.5.2 architecture hygiene

- Рабочая линия `release/1.5.2` приведена к более явной layered-структуре без изменения публичного поведения и без публикации релиза.
- `AppController.swift` больше не содержит весь runtime flow в одном файле: core composition/status оставлен в основном файле, а dictation flow, permissions, text-improvement menu, last-dictation recovery, system actions и update UI вынесены в отдельные `src/App/AppController+*.swift`.
- `TextImprovementRunner.swift` разгружен: trace DTO, cleaner, validator, runtime locator и `llama.cpp` subprocess runtime вынесены в `TextImprovementTrace.swift`, `TextImprovementOutputCleaner.swift`, `TextImprovementOutputValidator.swift`, `LlamaRuntimeLocator.swift` и `LlamaCompletionRuntime.swift`; runner теперь отвечает за prompt/profile, retry/fallback orchestration и сбор trace.
- Закрыт clean-install blocker второй нейросети: `build.sh` теперь по умолчанию упаковывает `llama-completion` и transitive `.dylib` dependencies в `Contents/Resources/bin` / `Contents/Resources/lib`, переписывает install names на bundle-relative `@rpath`, подписывает nested Mach-O до подписи `.app` и проверяет, что runtime запускается без Homebrew.
- `LlamaRuntimeLocator` выбирает bundled `llama-completion`/`llama-cli` раньше `/opt/homebrew` / `/usr/local`; Homebrew paths остаются только developer fallback, а пользовательский onboarding больше не должен просить установить `llama.cpp`.
- Закрыт clean-install blocker первой нейросети: `build.sh` теперь упаковывает `whisper-cli`, `libwhisper`, ggml dylibs, `libomp` и ggml backend plugins в `.app`; `WhisperRunner` задает `GGML_BACKEND_PATH` на bundled `Contents/Resources/libexec/ggml`, а `scripts/check_bundled_whisper_runtime.sh` проверяет отсутствие Homebrew/local ссылок и запуск без `dyld` errors.
- `Улучшить текст` сначала проверяет наличие bundled runtime и только потом запускает downloader Qwen-модели, чтобы пользователь не скачивал большую `.gguf` модель в сборке, которая всё равно не сможет её запустить.
- Добавлены проверки `scripts/test_llama_runtime_locator.sh` и `scripts/check_bundled_llama_runtime.sh`; `scripts/check_distribution_signing.sh` теперь включает self-contained проверку bundled `llama.cpp`.
- По полному DMG install path найден и закрыт packaging regression: mounted app из финального DMG получал `com.apple.FinderInfo`, из-за чего `codesign --verify --deep --strict` падал уже после mount/copy. `build.sh` теперь подписывает app и собирает DMG source через `/tmp` staging, копирует app через `cp -R -X` и запускает `create-dmg --skip-jenkins`, чтобы Finder AppleScript не ставил metadata на `.app`; новый `scripts/check_install_artifact_flow.sh` монтирует финальный DMG с EULA acceptance, проверяет `.app` внутри образа, копирует его во временную Applications-папку и повторно валидирует подпись, microphone entitlement и bundled `whisper`/`llama` runtimes.
- Сборка `MacDictate_Final_v1.5.2.dmg` локально подтверждена с `Developer ID Application: Aleksander Fisenkov (5BABN9U6WS)`, hardened runtime и microphone entitlement; notarization специально не выполнялась для этой рабочей тестовой сборки.
- GitHub update-check logic вынесена из `AppController` в `src/Updates/UpdateChecker.swift`; UI-alerts остались на app/controller уровне.
- Relaunch/uninstall и launch-at-login runtime wrappers вынесены в `src/System/AppLifecycleActions.swift` и `src/System/LaunchAtLoginService.swift`; `MenuBuilder` больше не читает `SMAppService` напрямую.
- Старые root icon experiments и helper/test scratch-файлы перенесены из корня проекта в `archive/legacy-root-scratch/` с README; активный root layout снова отделяет `src`, `assets`, `backend`, `web-landing`, `docs`, `scripts`, `releases` и `archive`.
- Targeted harness `scripts/test_text_improvement_runner.sh` обновлен под новую модульную структуру и проходит; дополнительно подтверждены `scripts/test_last_dictation_store.sh`, `scripts/test_debug_session_logger.sh`, `scripts/verify_release_governance.sh --online` и локальный `./build.sh` с DMG verify.
- Архитектурные правила роста закреплены в `docs/10_App_Architecture_Guardrails.md`: описаны слои, запреты на смешение, лимиты файлов и типовые решения для новых фич.
- Добавлен `scripts/check_architecture_guardrails.sh`; он проверяет лимиты Swift-файлов, чистоту root layout и parity `CLAUDE.md` / `AGENTS.md`. GitHub Actions release-governance workflow теперь запускает этот check.

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

## 2026-10-19 — Windows desktop 1.6.0 preparation

- Owner requested Windows support, GitHub checks and a new release; chose double Alt.
- Baseline release governance PASS, clean main72cd20d; implementation branch release/1.6.0.
- Added Windows scope and plan, isolated portable policy/native/UI services, pinned runtime/model distribution and final manual CI design. Public stable remains v1.5.2 until verified release publication.
- CI/build/runtime/publication evidence will be appended after execution; no production completion is claimed here.

- Final CI attempt39255124492 found a preexisting portability bug in architecture guard: quoted Cyrillic paths under default core.quotePath=true were mistaken for root clutter. Replaced line-based Git output with NUL-delimited ls-files -z. Local quotePath=true reproduction passes; publication remains blocked until a repaired final run succeeds.
- The same first run passed Windows portable tests and both destructive-operation guard assertions, but GitHub pwsh inherited LASTEXITCODE=1 from the intentionally rejected child build. Reset the expected-failure test exit state after successful assertions. macOS job118068379031 passed all compile/regression steps. These two evidenced CI failures justify the repair run.
- Second run39255523418 at5c2449b: governance/macOS PASS; Windows compile, pinned C++ runtime, manifest/import checks, ZIP/EXE and native Unicode/focus/menu smoke PASS. Synthetic ASR failed before its report was printed; add controlled synthetic-only native diagnostics and preserve run artifacts on failure. No release published. Fix Windows build-input pathspec (component-relative src) discovered in runner warning.
- Third run39256863541 at4c7e4e6 isolated native exit3: model exists/has pinned digest but Whisper fails to open its supplementary-character path. Pinned upstream uses codecvt_utf8<wchar_t> (UCS-2 on Windows); applied deterministic codecvt_utf8_utf16 replacement at both Whisper model loaders, with original/patched source hashes in runtime-lock. Keep the same Cyrillic/emoji model/WAV/TEMP ASR gate; no ASCII fallback or weakened assertion.
- Fourth run39257917547 at539ea32: all three jobs PASS, Windows37checks, Unicode/focus native smoke, exact synthetic ASR and installer/uninstaller PASS. Local Mac DeveloperID build succeeded but notary submit stopped before upload because legacy build.sh hardcoded v1.5.2 DMG filename/volume despite correct1.6.0 bundle. Make DMG/default install-check paths derive from Info.plist; this real release-packaging defect requires one final source-aligned repair run. No signing failure or Apple rejection occurred.

## 2026-10-19 — Desktop1.6.0 public release

- Final source `e80a4a094affb65457c4f3f77e090b84d6aef210`; fifth/final coordinated CI39259656403 PASS across all3jobs. Earlier attempts and concrete fixes are recorded above; no intermediate push/PR CI was enabled.
- Windows:37checks, native Unicode/focus/menu/clipboard, full syntheticASR on Unicode paths, installer/uninstaller PASS. Downloaded final archive verified SHA05647a09…412729; both package hashes match build manifest.
- macOS: dynamic1.6.0filename/volume corrected, DeveloperID build14, AppleAccepted/stapled/Gatekeeper/mountedinstall PASS. No Apple rejection occurred; prior submit stopped locally on obsolete filename.
- Published complete9asset draft as latestv1.6.0 at2026-10-19T13:39:24Z; public API digest/size readback9/9PASS. No partial latest release exposed.
- Public Pages/readback and local install evidence appended after completion.
- Final post-publication evidence: all3platformaliases fully downloaded WITHOUTauthentication and matched expectedSHA/size. Pagesonepushb48db9f, automaticrun39263614091success;16HTTPSfiles exactbytePASS including both manifests. InstalledpublicMac1.6.0/build14 after idlecheck; strictsignature/Gatekeeper, unchangedDR, exactmountedbinary/currentPID PASS; priorfree13 preserved privately. No models/preferences/iOSwrapper change. Physicalmic/hotkey/editor remainsNOT_RUN.


## 2026-10-29 — Windows1.6.1 first-run delivery preparation

- T01 app source was handed off with46portable checks and cross-build0warnings (root-confirmed); independent app repairs/review are tracked in the AISpa run. Delivery does not claim native/runtime success from this local evidence.
- Prepared a Windows-only1.6.1 working ledger, centralized packaging version/names, independent Windows stable pointer and pinned published1.6.0 links. macOS bundle1.6.0/build14 and latest-desktop.json untouched; no tag/release/Pages operation performed.
- Prepared EXE-primary/ZIP-secondary RU/EN instructions, automatic model saving, explicit desktop microphone access and record/stop/copy fallback, tray reopening and safe diagnostics. Site content is staged for1.6.1; keep it unpublished until actual Windows promotion.
- Added root-invoked Windows manifest/source/hash guard (initial RED: missing current.windows), isolated UI + one real ASR synthetic-fixture test, layout125/150% synthetic geometry/font/bounds/PNG checks, normal installed fresh-profile UI/reopen and all-file payload plus reinstall/uninstall preservation checks.
- Final CI/installer/Win32/UIASR/PNG and physical Windows10/11/native monitor DPI evidence are pending. Raw WAV/model/user content are excluded from CI upload. Final local results and hosted evidence must be appended after execution by the orchestrator.

- T02 local read-back:54portable checks PASS and Windows cross-build0warnings/errors after concurrent T01 repair; PowerShell parser/canonical-name/no-overwrite tests PASS; Windows channel + existing release governance PASS; landing JS syntax and36RU/EN keys PASS. Negative fixtures rejected Windows global-latest URL, wrong sourceSHA and same-size package tampering. Win32/installed/DPI/realASR are still NOT_RUN on this Mac.


## 2026-10-29 — Windows 1.6.1 checked local release candidate

- Prepared `releases/versions/v1.6.1/` and its `local_only` registry row together after G4 acceptance. Exact source `56b45301bc0e98c12f4823e5039152a3c3dd5229`; final CI `40747430459`, all three jobs PASS. Earlier attempts `40744090057` and `40745192074` failed and required separately authorized repairs; their history remains in `.aispa-work/2026-10-29-windows-first-run--wip/blind-acceptance.md`. No additional hosted run was started for release preparation.
- Independently read actual final build/runtime JSON and rehashed the EXE (54351051 bytes, `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9`) and ZIP (77339968 bytes, `55eedeed0bda8e91dc807cab00fefc9041e5c3d1151984508107e1e287c6365d`). Copied exact packages/manifests/checksums, local-only aliases and all 7 JSON/49 PNG into ignored canonical artifacts. Release body and pending publication metadata are prepared there.
- Hosted bounds: 62 portable checks, native hook/paste/clipboard, one real bundled Whisper on synthetic PCM/key seams, normal installed fresh production launch/reopen and populated UIA/Copy/clipboard PASS. All 492 payload files verified; synthetic settings/model/last-text sentinels survived reinstall/uninstall. Existing owner/friend data was untouched.
- Retained WARN: populated installed PNG referenced by JSON was absent from final artifact. UIA/clipboard checks passed; separate real-ASR result PNG was inspected in G4. Synthetic 125/150% layout stress at actual DPI 96 is not native monitor acceptance. Physical Windows 10/11 microphone/Alt/editor, native DPI, GUI model HTTP-success and interactive installer/SmartScreen remain NOT_RUN; unsigned distribution and manual corrupted-model recovery remain explicit.
- Windows stable, both public manifests, HTML fallback URLs and all Mac version/build/latest metadata remain at 1.6.0. No tag, commit, push, publication, server/DNS action or user-data mutation was performed by this preparation. Root must publish the checked Windows-only release with `make_latest=false`, read back actual publication identity/digests, then promote Windows registry/manifest/URLs and complete staged Pages delivery.


## 2026-10-29 — Windows 1.6.1 publication read-back and channel promotion

- Root published Windows-only [v1.6.1](https://github.com/alexfisenkov/MacDictate/releases/tag/v1.6.1) with `make_latest=false`. Actual API publication timestamp `2026-10-28T19:07:43Z`, release ID427078400; annotated tag resolves to checked build source56b45301bc0e98c12f4823e5039152a3c3dd5229. Later metadata-only commits are not the build source. Root independently confirmed global `/releases/latest` remains v1.6.0.
- Read `.aispa-work/2026-10-29-windows-first-run--wip/public-release-readback.json`: all4assets are public/uploaded and exact sizes/digests match retained bytes. Assets are the two versioned packages, windows-build-manifest.json and WINDOWS-SHA256SUMS. Generic local SHA256SUMS/aliases/evidence were not uploaded; release notes are the body, not a fifth asset.
- Promoted only current.windows.publicStable to v1.6.1, its release row to public_release, actual tag/release/publication metadata, latest-windows manifest and all3Windows EXE/ZIP HTML fallback links. Mac current pointers, 1.6.0/build14 plist and latest-desktop bytes remain unchanged.
- Source is ready for root's final static Pages publication. No commit/push/CI/deploy was performed by this finalization. Pages/browser/HTTPS/full public download hash read-back remains pending. Physical Windows10/11 mic/Alt/editor, native DPI, GUI HTTP-success and interactive installer/SmartScreen remain NOT_RUN; unsigned/manual-model-recovery and missing installed populated PNG limitations remain recorded.


## 2026-10-29 — Windows 1.6.1 live delivery receipts

- Root merged/pushed source main `e46b25fb8e1c2203609c2ee750176028a61fdca7` and published Pages commit `1d4873e628956a8bde3d76bcd07de9cfd66de62a`, run40752369737. Actual `website-public-receipt.json` confirms16/16 HTTPS files exact PASS, including both platform manifests and DEPLOYMENT.json. Workflow was still in progress at handoff; final run success is not claimed.
- Actual `public-installer-receipt.json` confirms complete unauthenticated EXE download:54351051 bytes and SHA-256 `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9`. This supplements prior4/4 API asset size/digest read-back; a complete public ZIP download and live browser acceptance are not established by these receipts.
- Root confirmed global latest remainsv1.6.0. This append changed only new Windows release verification metadata/card/checklist/action/index; no runtime, scripts, manifests, HTML, Git/publish/CI action or Mac1.6.0/build14 metadata changed. Physical Windows10/11/native-DPI and retained unsigned/model-recovery/PNG limitations remain unchanged.

- Subsequent root API read-back confirmed Pages run40752369737 completed SUCCESS with exact head1d4873e628956a8bde3d76bcd07de9cfd66de62a; global latest remainedv1.6.0. The earlier in-progress observation above is historical, not the final conclusion.
