# Changelog

Этот changelog фиксирует только пользовательски и релизно значимые изменения.

## [Unreleased] 1.5.0 Working Line

### Added
- server-authoritative checkout и catalog тарифов на backend-слое;
- app-side license state machine с bounded offline grace;
- runtime diagnostics для `whisper-cli`, модели, микрофона, accessibility и временной недоступности license server;
- модульная структура app-layer вместо монолитного `AppController.swift`;
- project operating model, decision log, smoke matrix и release checklist;
- release governance layer: `docs/7_Release_Governance.md`, `releases/registry.json`, per-version `RELEASE.md`, локальное хранилище artifacts и `scripts/verify_release_governance.sh`;
- desktop-local `CLAUDE.md` / `AGENTS.md` с правилами работы будущих агентов;
- optional локальное улучшение текста второй нейросетью: preferred Qwen2.5-3B-Instruct Q4_K_M через `llama.cpp` (`llama-completion`) с fallback на Qwen2.5-1.5B-Instruct Q4_K_M, top-level toggle `Улучшить текст` и такой же toggle в настройках;
- editor profile для второй нейросети: строгие правила сохранения смысла, оформление абзацев/списков, доменные терминологические пакеты и подсказки нормализации речи;
- deterministic formatter guardrail для очевидных речевых перечислений (`во-первых`, `во-вторых`, `в-третьих`) и частых терминов, если Qwen оставляет их неоформленными;
- opt-in local debug session logging для сравнения `audio.wav`, raw/cleaned Whisper output, Qwen prompt/raw/cleaned/final output и финального текста вставки в `~/.macdictate/debug-sessions/`;
- targeted runtime harnesses для зависшего/stderr-heavy `whisper-cli`, machine ID timeout, cleanup stale temp audio, `TextImprovementRunner` и `DebugSessionLogger`.

### Changed
- `AppController.swift` превращен в composition root / coordinator, а ключевая логика вынесена в отдельные сервисы;
- `README.md` и docs теперь описывают весь product surface: `app`, `backend`, `web-landing`, `legal`, `docs`;
- сборка `swiftc` теперь подхватывает все `.swift` файлы в `src/` рекурсивно;
- исторические DMG/build logs разложены из корня проекта в `releases/versions/*/artifacts/` и `releases/archive/*/artifacts/`;
- `build.sh` теперь кладет обычный DMG output в `build/artifacts/`, не запускает Homebrew install, если `create-dmg` уже доступен, очищает macOS metadata, проверяет подпись `.app` и готовит DMG staging-копию через `ditto` без xattrs;
- `build.sh` теперь делает strict codesign verification на clean temporary copy через `ditto --noextattr --noqtn`, чтобы проверять подпись без file-provider/FinderInfo xattrs из рабочей папки;
- model lookup разделен по типам: Whisper остается `.bin`, а текстовая модель хранится как `.gguf`, чтобы вторая нейросеть не могла случайно подменить ASR-модель.
- Qwen input теперь предварительно проходит deterministic pre-formatting: частые ASR-ошибки терминов и очевидные `во-первых/во-вторых/в-третьих` перечисления нормализуются до отправки во вторую модель.
- Вторая нейросеть переключена на промежуточную 3B preferred-модель: downloader качает Qwen2.5-3B-Instruct Q4_K_M (~2.1 GB), а runtime автоматически использует уже установленную 1.5B-модель только как fallback.
- Для 3B-модели сохранены увеличенные лимиты text-improvement runtime: timeout `10` минут и context window `8_192` tokens.

### Fixed
- `WhisperRunner` больше не ждет `whisper-cli` бесконечно: transcription subprocess ограничен timeout `30` минут, после чего процесс завершается, temp-файлы чистятся, а пользователь получает различимую диагностическую ошибку.
- `WhisperRunner` теперь читает `stderr` во время работы subprocess, чтобы шумный `whisper-cli` не блокировался на заполненном pipe.
- `LicenseService` больше не может подвиснуть на первом `ioreg` при получении machine ID: command ограничен timeout и fallback-кешированием generated ID.
- `RecordingService` чистит stale `/tmp/mac_dictate_dist.wav` и `.txt` при старте сервиса и перед новой записью.
- Ошибка/отсутствие второй нейросети больше не ломает диктовку: при включенном улучшении MacDictate вставляет исходный Whisper-текст и показывает warning diagnostic.
- Длинные тексты больше не отправляются в Qwen вслепую: input > 6 000 символов fallback-ится без риска silent truncation.
- `ChaiJPT` / `ChagPT` / `Chai GPT` / `Чай и GPT` / `чай джипити` нормализуются в `ChatGPT`; `Клод от Anthropic` нормализуется в `Claude от Anthropic`; heading cues вроде `И вот к чему пришли` / `Вот что мы достигли` перед перечислением превращаются в отдельный заголовок с двоеточием и numbered list.
- Runtime-prompt второй нейросети больше не содержит примерные метки `Вход` / `Выход`, чтобы Qwen не копировала их в итог; если такие метки всё же появятся, post-processing вырезает leaked scaffold и снимает декоративный Markdown, когда исходный текст был plain text.

### Notes
- `v1.2` и `v1.3` помечены как reconstructed history: GitHub Releases существуют, но локальные tags отсутствуют, а remote tags указывают на commit `v1.4`.
- `v1.4.1-local` помечена как локальная сборка, не публичный release.
- Локальный `v1.4.2` DMG отличается по SHA256 от GitHub asset; публичный source of truth для скачивания — GitHub Release.

## [v1.4.2] - 2026-04-05

### Added
- OTA-проверка обновлений через GitHub Releases API;
- звук вставки после успешного paste;
- улучшения меню и статусов menu bar utility.

### Notes
- `v1.4.2` остается последней публичной стабильной базой.
- Линия `release/1.5.0` пока рабочая и не считается выпущенным релизом.

## [v1.4] - 2026-04-01

### Added / Changed
- Refined Native Settings Submenu.
- TCC ghost permission guidance.
- Dangerous Zone / uninstall returned.

## [v1.3] - 2026-04-01

### Added
- Submenu settings and TCC polling, по GitHub release notes.

### Notes
- История восстановлена по GitHub Release и локальному DMG; локальный tag отсутствует.

## [v1.2] - 2026-04-01

### Added
- First standalone release, по GitHub release notes.

### Notes
- История восстановлена по GitHub Release и локальному DMG; локальный tag отсутствует.

## [v1.1] - 2026-04-01

### Added / Changed
- Reliable relaunch.
- Visual Login Items через AppleScript fallback.
- Early OTA Auto-Updater implementation.

## [v1.0] - 2026-03-31

### Added
- Native Swift/AppKit desktop core.
- Local Whisper via Homebrew `whisper-cli`.
- Auto-permissions and uninstaller.

### Notes
- Локальная историческая база без публичного GitHub Release.
