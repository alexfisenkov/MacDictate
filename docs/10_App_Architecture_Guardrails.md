# App Architecture Guardrails

Этот документ — обязательный канон для всех будущих правок desktop/macOS runtime. Его цель: проект должен расти как дерево с понятными ветками, а не как несколько бесконечных файлов.

Перед любой правкой в `src/` сначала читать этот документ и `docs/1_Architecture.md`.

## Главный Принцип

Новая ответственность получает свой слой и свой файл. Существующий файл расширяется только тогда, когда новая логика является прямым продолжением его текущей ответственности.

Если изменение добавляет новый сценарий, новый runtime, новый storage, новый validator, новый prompt/profile, новую network-интеграцию или новый user-facing flow, оно не должно просто дописываться в ближайший controller.

## Слои Runtime

`src/AppController.swift`
- Composition/start/status root.
- Держит сервисы, lifecycle binding, menu/status refresh и hotkey wiring.
- Не содержит network, subprocess, persistence, prompt logic, validation policy или длинные сценарии.

`src/App/`
- App-level сценарии и UI actions, которые связывают menu/hotkeys с сервисами.
- Extension-файлы допустимы как тонкий bridge.
- Если extension начинает содержать самостоятельную бизнес-логику или приближается к hard limit, сценарий выносится в отдельный service/coordinator.

`src/<Feature>/`
- Дом конкретной фичи или runtime-области.
- Для новой крупной фичи создавать отдельную папку, а не смешивать её с `AppController`.
- Рекомендуемый состав:
  - `<Feature>Service.swift` или `<Feature>Coordinator.swift` — use-case orchestration.
  - `<Feature>Settings.swift` — persisted toggles/config.
  - `<Feature>Store.swift` — local persistence.
  - `<Feature>Runtime.swift` / `<Feature>Client.swift` — внешний процесс, API или OS integration.
  - `<Feature>Formatter.swift` / `<Feature>Validator.swift` — deterministic policy.
  - `<Feature>Trace.swift` — debug/session DTO, если нужны artifacts.

`src/UI/`
- Menu skeleton, presentation strings, status summaries.
- UI слой не читает `SMAppService`, не ходит в сеть, не запускает процессы и не принимает бизнес-решения.

`src/System/`
- OS-level wrappers: relaunch, uninstall, launch at login, system settings, app lifecycle.

`src/Updates/`
- Update source/client/version compare.
- Alert UI остается в app layer, network/parsing — здесь.

`src/Transcription/`
- Audio recording, Whisper model lookup, Whisper runtime, last dictation recovery store.

`src/TextImprovement/`
- Вся вторая AI-модель: settings, prompt profile, formatter, cleaner, validator, llama runtime, trace и runner.
- Prompt/rules/validators не встраивать в `AppController`.

`src/License/`, `src/Diagnostics/`, `src/Paste/`, `src/Hotkeys/`
- Сохраняют текущие границы ответственности.

## Запрещённые Смешения

- Controller не запускает subprocess напрямую.
- Controller не парсит HTTP/JSON напрямую.
- `MenuBuilder` не принимает runtime-решения и не читает системные сервисы напрямую.
- AI prompt, cleaner, validator и model runtime не живут в одном файле без причины.
- Persistence не прячется в UI action, если данные используются повторно.
- Debug logging не меняет результат пользовательского сценария.
- Root проекта не принимает одноразовые scratch-файлы; исторические артефакты идут в `archive/` с README.

## Лимиты Размера

Эти лимиты нужны не ради формальности, а чтобы файл оставался читаемым:

- `src/AppController.swift`: hard limit 250 строк.
- `src/App/AppController+*.swift`: hard limit 320 строк.
- Любой другой Swift-файл: hard limit 350 строк.
- Метод больше 70 строк требует проверки на извлечение helper/service.
- Метод больше 120 строк считается архитектурным запахом и должен быть разбит, кроме редких data-declaration случаев.

Если лимит мешает, это не повод поднять лимит. Сначала выделить новый слой или файл. Исключение допускается только через явную запись в `docs/4_Decision_Log.md` с причиной и планом обратного уменьшения.

## Правило Новых Фич

Перед кодом ответить на 5 вопросов:

1. Какой слой владеет новой ответственностью?
2. Есть ли уже файл с этой точной ответственностью?
3. Не добавляет ли правка network/subprocess/persistence/AI-policy/UI-action в неправильный слой?
4. Какой targeted harness или smoke подтверждает сценарий?
5. Какой документ/лог надо обновить после изменения?

Если ответ на второй вопрос "почти подходит", лучше создать новый файл с точным именем. Это дешевле, чем через месяц распутывать смешанный hotspot.

## Типовые Решения

- Новая menu action: selector в `src/App/AppController+<Area>.swift`, логика в feature service/store/runtime.
- Новый AI guardrail: validator/formatter/profile в `src/TextImprovement/`, тест в `scripts/test_text_improvement_runner.sh`.
- Новый внешний CLI/runtime: отдельный `<Runtime>.swift`, runner/coordinator только вызывает его.
- Новый HTTP endpoint/client: отдельный service/client, controller только показывает результат.
- Новое локальное хранение: `<Feature>Store.swift` и targeted harness.
- Новая диагностика: типы/summary в `src/Diagnostics/`, UI только отображает.

## Transitional Rule

`src/App/AppController+DictationFlow.swift` допустим как текущий app-level bridge. Новую тяжёлую логику туда не добавлять. Если диктовочный сценарий расширяется, следующий шаг — `DictationPipeline` / `DictationCoordinator` с явными callbacks для status, debug logging, last-dictation save и paste.

## Автоматическая Проверка

Перед завершением app-side задачи запускать:

```bash
scripts/check_architecture_guardrails.sh
```

Скрипт проверяет:
- лимиты строк Swift-файлов;
- чистоту root layout;
- parity `CLAUDE.md` и `AGENTS.md`.

Для release/PR этот check должен идти рядом с release governance.
