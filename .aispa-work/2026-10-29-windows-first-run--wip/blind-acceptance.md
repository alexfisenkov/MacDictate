# Независимая приёмка Windows first-run

Дата: 2026-10-29 (Asia/Makassar). Проверяющий видел только исходный `2026-10-29-brief.md` из каталога прогона. Спецификации, manifest, tickets и чужие reviews не открывались. Исходники проекта не изменялись.

**Актуальный итог: G4 PASS в автоматическом Windows Server 2025 контуре на SHA `56b45301bc0e98c12f4823e5039152a3c3dd5229`, с WARN о сохранении одного PNG.** Прочитаны actual JSON и просмотрены actual PNG финального run. Публичная доставка и физическая диктовка/Alt на Windows10/11 или компьютере друга этой приёмкой не подтверждены. Два предыдущих FAILED сохранены ниже и не переименованы в PASS.

## Первый attempt — FAILED, сохраняется как исторический результат

- Чистая копия: `/tmp/macdictate-blind-acceptance.jqyq3I/repo`.
- Ветка: `codex/windows-first-run`.
- Проверенный HEAD: `33b3687225da906b077be63a9430bcaae990b970`.
- Единственный dispatch этого attempt: [40744090057](https://github.com/alexfisenkov/MacDictate/actions/runs/40744090057).
- GitHub read-back подтвердил тот же headSha. Итог: **failure**; `windows` — failure, `macos` и `governance` — success.
- Runtime Windows-приложения в этом attempt **НЕ ПРОВЕРЕН**. Проверка остановилась раньше запуска приложения. Чтение README и scripts не используется как доказательство работы UI.

### Что произошло на Windows runner

Windows Server 2025, runner image `20261021.278.1`.

1. `dotnet run --project tests/MacDictate.Core.Tests -c Release` из `windows/` — **PASS**: `PASS 62 portable policy/storage/download/process checks`.
2. `windows/scripts/test-packaging-guards.ps1` — **PASS**: `Packaging guards PASS: prior app and versioned artifact preserved without native build.`
3. `windows/scripts/build.ps1` — **PASS**: self-contained EXE/ZIP собраны.
4. `python windows/scripts/check-delivery.py --build-manifest windows/dist/windows-build-manifest.json --source-sha "33b3687225da906b077be63a9430bcaae990b970"` — **FAIL**, exit 1.

Дословная ошибка шага `Verify exact source SHA and package hashes` (2026-10-28 18:23:06 UTC):

```text
Windows delivery FAIL: 'charmap' codec can't decode byte 0x8f in position 7147: character maps to <undefined>
Process completed with exit code 1.
```

Следующие шаги получили **SKIPPED**, поэтому от них нет положительного доказательства:

- `windows/scripts/smoke.ps1` — native tray, hook, Unicode paste.
- Создание TTS fixture.
- `windows/scripts/test-onboarding.ps1 -WavePath "$env:RUNNER_TEMP/macdictate-synthetic.wav"` — реальные окна и bundled Whisper через synthetic capture/hotkey seam; layout stress.
- `windows/scripts/test-install.ps1` — установка, обычный первый запуск, reopen, reinstall, uninstall.

### Проверка требований исходного пользователя — первый attempt

Статусы относятся к подтверждённому результату приёмки, а не к предположению о наличии кода.

| Требование пользователя | Статус | Одно проверенное доказательство / граница |
|---|---|---|
| Очевидное скачивание Windows-пакета | **partial** | Локальный `check-delivery.py` PASS подтверждает согласованность ролей installer/portable и pinned public manifest; внешний сайт и наглядность кнопок в браузере не проверялись. README прямо указывает, что candidate 1.6.1 ещё не опубликован, stable — 1.6.0. |
| Понятные разрешения после установки | **partial** | `windows/README.md` объясняет отсутствие отдельного обычного permission prompt у desktop-программы, тест микрофона и путь к Windows microphone privacy; реальная установка и её UI были SKIPPED. |
| Работа при нажатии Alt | **partial** | Portable policy harness PASS (62 проверки); native hook/paste и onboarding hotkey были SKIPPED. Физический Alt на Windows10/11 и компьютере друга — NOT_RUN. |
| Инструкция «что куда нажать» | **partial** | В README есть последовательные шаги model → microphone → record → recognize → copy → hotkey. Реальные окна/доступность этих инструкций пользователю не наблюдались. |
| Понятные действия и состояние первого запуска | **partial** | Пакет собран; ordinary installed first launch и автоматическое открытие/повторное открытие окна не исполнялись из-за более раннего FAIL. |
| Получить работающую диктовку до результата | **no** | Не было запуска приложения, аудиозахвата, вызова bundled Whisper через UI либо итогового текста в этом attempt; все соответствующие шаги SKIPPED. |
| Довести весь путь первого запуска | **no** | Приёмка заблокирована Windows delivery FAIL; пользовательский end-to-end результат не подтверждён. |

### Локальные команды — точные команды и результаты для engineering memory

Host — Darwin. Локальное отсутствие SDK отделено от Windows-native результата.

```sh
task_clone_dir=$(mktemp -d /tmp/macdictate-blind-acceptance.XXXXXX)
git clone --branch codex/windows-first-run --single-branch https://github.com/alexfisenkov/MacDictate.git "$task_clone_dir/repo"
printf '%s\n' "$task_clone_dir/repo"
```

Exit 0; resolved path `/tmp/macdictate-blind-acceptance.jqyq3I/repo`.

Все следующие команды выполнялись из этой чистой копии:

```sh
git rev-parse HEAD
git status --porcelain=v1
windows/scripts/check-local.sh
python3 windows/scripts/check-delivery.py
command -v dotnet
uname -s
gh workflow run desktop-release.yml --ref codex/windows-first-run
gh run view 40744090057 --json url,headSha,headBranch,status,conclusion,jobs
gh run watch 40744090057 --exit-status --interval 30
gh run view 40744090057 --log-failed
gh run view 40744090057 --job 123013152354 --log > /tmp/macdictate-blind-acceptance.jqyq3I/windows-job.log
gh api repos/alexfisenkov/MacDictate/actions/runs/40744090057/artifacts --jq '.artifacts[]|{id,name,size_in_bytes,expired,workflow_run}'
gh run download 40744090057 --name windows-x64-33b3687225da906b077be63a9430bcaae990b970 --dir /tmp/macdictate-blind-acceptance.jqyq3I/artifacts
gh run view 40744090057 --json headSha,status,conclusion,createdAt,startedAt,updatedAt,url > /tmp/macdictate-blind-acceptance.jqyq3I/run-40744090057.json
```

Результаты:

- `git rev-parse HEAD` — ожидаемый полный SHA выше; `git status --porcelain=v1` до dispatch и после проверок — пустой.
- `check-local.sh` — exit 1 без вывода; `command -v dotnet` не нашёл команду. Это **SDK prerequisite unavailable**, не Windows runtime failure.
- `python3 windows/scripts/check-delivery.py` — exit 0, `Windows delivery PASS: independent channels, pinned public manifest, canonical candidate`.
- `uname -s` — `Darwin`; Windows WinForms на этом host не исполнялся.
- `gh workflow run` — exit 0, вернул URL run 40744090057; повторных dispatch в первом attempt не было.
- `gh run watch` — exit 1; итог Windows failure, остальные jobs success.
- `gh run view --log-failed` — exit 0, failure log приведён выше.
- Artifact API — `id=12841800041`, name=`windows-x64-33b3687225da906b077be63a9430bcaae990b970`, size=`130907371`, expired=false; head_sha совпадает.
- Artifact download завершился exit 0. В архиве только `MacDictate_Windows_v1.6.1_x64.exe`, `MacDictate_Windows_v1.6.1_x64.zip`, `windows-build-manifest.json`, `WINDOWS-SHA256SUMS`; native/UI JSON и PNG отсутствуют, как и ожидается после SKIPPED.
- GitHub artifact digest: `sha256:3ed24e36ac532acea50fbf38bf350f81b1a77b53e757e13d5f170707a6ecad89` (metadata API; это digest CI archive, не checksum EXE).
- После скачивания, уже на исправленном checkout, выполнен `python3 windows/scripts/check-delivery.py --build-manifest /tmp/macdictate-blind-acceptance.jqyq3I/artifacts/windows-build-manifest.json --source-sha 33b3687225da906b077be63a9430bcaae990b970` — PASS по exact artifact bytes/sourceSHA. Это post-hoc локальная проверка старого пакета; исходный Windows FAIL и отсутствие runtime evidence сохраняются.

### Ограничения и незавершённое

- Нельзя принять задачу по факту успешной сборки: обычный installed UI, microphone, hotkey, ASR, copy/paste, reopen и сохранность данных при reinstall/uninstall пока не исполнялись.
- Даже будущий PASS hosted Windows Server 2025 с synthetic WAV/hotkey seam не докажет физический микрофон/Alt/editor на Windows10/11. Доступ к компьютеру друга не предоставлен.
- Внешний сайт, пользовательское скачивание/SmartScreen, физический монитор 125/150%, публикация релиза — не проверены. Публикации/сообщений пользователям не было.
- Код не исправлялся, workflow не перезапускался. Для продолжения нужны исправленный SHA и отдельная явная авторизация root на repair-native-run; первый failed attempt должен остаться в истории.

## Repair-native attempt — FAILED, отдельная авторизация

После фиксации первого FAIL root явно разрешил ровно один дополнительный ручной dispatch для исправленного SHA. Проверяющий код не менял.

- Новый чистый detached checkout: `a8fe813f4a3b7f47d87f1535b0e0ffe13fcef7a8`.
- Отдельный run: [40745192074](https://github.com/alexfisenkov/MacDictate/actions/runs/40745192074).
- `gh run view` подтвердил branch `codex/windows-first-run` и точный headSha выше.
- Итог: **failure**, Windows failure на `Verify installer extraction and uninstaller`; macOS и governance success.
- Policy checks (62), packaging guards, self-contained EXE/ZIP build и exact source SHA/package bytes — PASS.
- Native smoke — PASS. Фактический JSON из Windows job log: `success=true`, hook installed/injected events ignored, alternate hotkeys registered, Unicode/surrogate read-back, newline normalized без Return, native Alt-menu dismissed, clipboard unchanged, blocked changed window/input с read-back. `physicalMicrophone=NOT_TESTED`, `physicalAlt=NOT_TESTED`.
- `windows/scripts/test-onboarding.ps1 -WavePath "$env:RUNNER_TEMP/macdictate-synthetic.wav"` — PASS (18:31:21 UTC): `Onboarding UI + one real bundled Whisper invocation PASS; synthetic fixture/capture/key activation; physical Windows10/11 NOT_TESTED.`
- `windows/scripts/test-install.ps1` — FAIL, exit 1. В 18:31:34 UTC обычный installed first launch завершился ошибкой `Installed onboarding control missing: LastDictationText` (`test-first-launch.ps1:38`), затем `Installed normal-profile UI acceptance failed` (`test-install.ps1:32`). Причина отсутствия UIAutomation-элемента в этой приёмке не предполагается.
- Artifact скачан exit 0 в `/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts`; JSON прочитаны и 11 actual PNG независимо просмотрены (подробнее ниже).
- Artifact API: id `12842305065`, size `132253844`, expired=false, headSha совпадает, digest `sha256:32895d64ec07fcb5ffc3fc4d9e9727bea81e33d9ac4a304e50fa9e752764703b`.

Точные дополнительные команды:

```sh
git status --porcelain=v1
git fetch origin codex/windows-first-run
git switch --detach a8fe813f4a3b7f47d87f1535b0e0ffe13fcef7a8
git rev-parse HEAD
git status --porcelain=v1
gh workflow run desktop-release.yml --ref codex/windows-first-run
gh run view 40745192074 --json url,headSha,headBranch,status,conclusion
python3 windows/scripts/check-delivery.py
git status --porcelain=v1
gh run view 40745192074 --log-failed
gh api repos/alexfisenkov/MacDictate/actions/runs/40745192074/artifacts --jq '.artifacts[]|{id,name,size_in_bytes,expired,digest,workflow_run}'
gh run download 40745192074 --name windows-x64-a8fe813f4a3b7f47d87f1535b0e0ffe13fcef7a8 --dir /tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts
gh run view 40745192074 --job 123016986822 --log > /tmp/macdictate-blind-acceptance.jqyq3I/repair-windows-job.log
```

Git-операции exit 0, SHA совпал, обе проверки clean status пустые. `gh workflow run` exit 0, URL выше. Локальный delivery checker exit 0, PASS. Native сценарии оцениваются только по этому отдельному Windows run, не по локальному PASS на Darwin.

### Artifact read-back второго attempt

`python3 windows/scripts/check-delivery.py --build-manifest /tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/windows-build-manifest.json --source-sha a8fe813f4a3b7f47d87f1535b0e0ffe13fcef7a8` — exit 0, PASS exact package bytes/sourceSHA.

58 файлов, из них 48 PNG. В `installed-first-launch-smoke.json`:

- `success=false`, `scenario=installed-normal-fresh-profile`, `testMode=false`.
- Проверены normal production first-run window и actual controls `NextSetupAction`, `StartStopRecording`, `CancelOperation`.
- `failure=Installed onboarding control missing: LastDictationText`.
- Указанный в JSON `installed-first-launch-smoke.png` **фактически отсутствует**. `installer-smoke.json` также отсутствует. Нельзя считать строку в массиве screenshots доказательством существования снимка или считать весь reinstall/uninstall flow успешным.

В `onboarding-smoke.json`:

- `success=true`, `realWhisper=true`, `realFixturePhraseMatched=true`.
- `resultVisibleBeforeTestScroll=true`, `resultScreenshotsUseTestScroll=false`.
- Actual visible result read-back и actual Copy → clipboard read-back включены в пройденные checks; последняя диктовка сохранена, временный capture удалён.
- Model download/setup в UI использует synthetic seam (включая ошибки network/integrity и успешное автоматическое сохранение); для одного actual bundled Whisper заранее скачан и integrity-checked закреплённый файл модели. Нельзя утверждать, что успешный HTTP download именно из GUI был реально проверен.
- Audio — fixture WAV в capture seam; hotkey activation — explicit test seam при реально установленном hook. Физические микрофон/Alt — NOT_TESTED.
- `realDeviceProbe.count=0`, capture=NOT_RUN. Actual desktop DPI=96.
- `layout-1.25-smoke.json` и `layout-1.5-smoke.json` — success=true, `syntheticLayoutStress=true`, `realWhisper=false`; это Scale/font stress с синтетическим текстом при desktop DPI96, не physical monitor acceptance.

Визуально просмотрены следующие снимки из этого же artifact:

1. [Fresh RU](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-01-fresh-ru.png): видны CTA `Начать настройку: скачать модель`, объяснение ~488МБ/автосохранения, disabled запись, кнопки теста и privacy. Result/Copy на fresh screenshot не показаны.
2. [Real ASR result before test scroll](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-07-result-before-test-scroll.png): виден точный `The quick brown fox jumps over the lazy dog.` и `Копировать текст` одновременно. Это положительное доказательство production result visibility после real bundled ASR.
3. [Result EN](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-08-result-en.png): текст и Copy видны, инструкции/статусы на английском.
4. [No device](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-03-microphone-NoDevice.png): visible actionable сообщение подключить микрофон/обновить входы, объяснение Windows privacy, запись disabled.
5. [Download recovery](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-01-download-network.png): visible сообщение проверить сеть/место/права и повторить либо выбрать .bin; текущая модель не подменяется.
6. [Fresh layout stress125%](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/layout-1.25-smoke-01-fresh-ru.png): primary setup CTA и запись видны; нижняя часть body прокручивается.
7. [Result layout stress125%](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/layout-1.25-smoke-07-result-before-test-scroll.png): synthetic result и Copy видны одновременно.
8. [Result layout stress150%](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/layout-1.5-smoke-07-result-before-test-scroll.png): synthetic result и Copy видны одновременно.
9. [Hotkey test state](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-04-hotkey-test.png): readiness показывает checked hotkey и предложение первой записи, не запускает audio автоматически.
10. [Recording](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-05-recording.png): visible recording timer, явная остановка кнопкой либо дважды левый Alt, active Stop/Cancel, model/settings controls disabled.
11. [Processing](/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts/onboarding-smoke-06-processing.png): visible local CPU recognition/progress, Cancel доступна.

Наблюдаемое отсутствие result/Copy на fresh screenshot согласуется с отсутствием LastDictationText в UIAutomation, но не снимает FAIL ordinary installed-first-launch: проверяющий не подменяет диагноз предположением.

### Требования после второго attempt — текущая доказанная граница

| Требование пользователя | Статус | Доказательство |
|---|---|---|
| Очевидное скачивание Windows-пакета | **partial** | Delivery source/byte checks PASS; внешний сайт и новая публичная поставка не проверены/не опубликованы в этом задании. |
| Понятные разрешения/микрофон | **partial** | Actual fresh/NoDevice PNG содержат объяснение Windows privacy и кнопки теста/настроек; физическое устройство отсутствует (count0), системные privacy switches не проверены. |
| Работа Alt | **partial** | Реальный hook и alternate keys зарегистрированы, policy/native smoke PASS; активация onboarding синтетическая, physical Alt NOT_TESTED. |
| Пошаговые инструкции | **implemented** | Actual RU/EN окна показывают последовательный model → microphone → recording → result/Copy; ошибки имеют visible recovery. |
| Понятный/автоматизированный первый запуск | **partial** | Model auto-save/persistence и текущее действие подтверждены seam/read-back; ordinary installed-first-launch FAIL не снят, reinstall/uninstall completion не подтверждён. |
| Работающая диктовка и текст | **partial** | Реальный bundled Whisper распознал fixture, текст+Copy видны и clipboard прочитан; physical audio не проверен. |
| Довести весь путь первого запуска | **partial** | Существенная часть реально работает в hosted runtime, но отдельная normal installed acceptance всё ещё FAIL. |

**Вердикт второго attempt: G4 не принят целиком.** Real-ASR UI и native smoke подтверждены в описанных границах; normal installed first-run остаётся открытым blocker. Нужна отдельная авторизация root на следующий исправленный SHA, если работа продолжается. Публикации и проверок на компьютере друга не было.

## Третий attempt — отдельная авторизация normal-install repair

Root явно разрешил ещё один ручной dispatch после изменения installed-first-launch проверки. Оба предыдущих FAILED сохранены выше. Проверяющий код не менял.

- Clean detached checkout: `56b45301bc0e98c12f4823e5039152a3c3dd5229`.
- Run: [40747430459](https://github.com/alexfisenkov/MacDictate/actions/runs/40747430459).
- `gh run view` подтвердил exact headSha выше и branch `codex/windows-first-run`.
- Итог GitHub: **success**, jobs `windows`, `macos`, `governance` — success; exact headSha подтверждён после завершения.
- Windows log: 62 portable checks PASS, packaging guards PASS, exact package bytes/sourceSHA PASS, native smoke success, one real bundled Whisper onboarding PASS, 34 installed UI contract examples PASS и `Installed payload, normal first-run UI, reinstall and uninstaller preservation PASS.`
- Artifact скачан exit 0 в `/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts`; actual JSON прочитаны, actual installed-fresh и ASR-result PNG просмотрены. Финальный вердикт приведён ниже.
- Artifact API: id `12841938103`, size `132293593`, expired=false, digest `sha256:cf03df4b83f24dd26e8c30b2ef397d908198d2a5543d0e549ece88d88d7e0696`, exact headSha совпадает.

Точные команды запуска:

```sh
git status --porcelain=v1
git fetch origin codex/windows-first-run
git switch --detach 56b45301bc0e98c12f4823e5039152a3c3dd5229
git rev-parse HEAD
git status --porcelain=v1
gh workflow run desktop-release.yml --ref codex/windows-first-run
gh run view 40747430459 --json url,headSha,headBranch,status,conclusion
gh api repos/alexfisenkov/MacDictate/actions/runs/40747430459/artifacts --jq '.artifacts[]|{id,name,size_in_bytes,expired,digest,workflow_run}'
gh run view 40747430459 --json url,headSha,conclusion,jobs --jq '{url,headSha,conclusion,jobs:[.jobs[]|{id:.databaseId,name,conclusion}]}'
gh run download 40747430459 --name windows-x64-56b45301bc0e98c12f4823e5039152a3c3dd5229 --dir /tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts
gh run view 40747430459 --job 123024848033 --log > /tmp/macdictate-blind-acceptance.jqyq3I/final-windows-job.log
```

Git exit 0, SHA совпал, clean status пуст до/после. Dispatch exit 0, URL выше. Дальнейших dispatch без нового явного сообщения root не выполняется.

### Финальный artifact / runtime read-back

```sh
python3 windows/scripts/check-delivery.py --build-manifest /tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/windows-build-manifest.json --source-sha 56b45301bc0e98c12f4823e5039152a3c3dd5229
git status --porcelain=v1
gh run view 40747430459 --json headSha,status,conclusion,createdAt,startedAt,updatedAt,url > /tmp/macdictate-blind-acceptance.jqyq3I/run-40747430459.json
```

Checker exit 0: `Windows delivery PASS: independent channels, pinned public manifest, canonical candidate and exact artifact bytes/sourceSHA`. Final clone status пуст. Run read-back exit 0, status completed/conclusion success/exact headSha совпал.

В финальном artifact 60 файлов, 49 PNG. Подтверждено непосредственным чтением файлов с UTF-8/BOM-aware decoding:

- [native-smoke.json](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/native-smoke.json) и [installed-smoke.json](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/installed-smoke.json): `success=true`; native Unicode/surrogate paste read-back, unchanged automatic clipboard, blocked changed window/input и registered hook/alternate keys. Physical mic/Alt NOT_TESTED.
- [onboarding-smoke.json](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/onboarding-smoke.json): `success=true`, `realWhisper=true`, `realFixturePhraseMatched=true`, `resultVisibleBeforeTestScroll=true`, `resultScreenshotsUseTestScroll=false`; actual result/Copy/clipboard checks PASS. Источники: real bundled Whisper, fixture WAV/capture seam, explicit hotkey activation seam при реально зарегистрированном hook. Actual WinMM enumeration count0, physical capture NOT_RUN.
- `layout-1.25-smoke.json`, `layout-1.5-smoke.json`: success=true, syntheticLayoutStress=true, realWhisper=false, actualDesktopDpi96. Это синтетическое масштабирование, не native125/150% acceptance.
- [installed-first-launch-smoke.json](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/installed-first-launch-smoke.json): success=true, failure=null, testMode=false, dpi96. Проверены обычный production launch, корректное fresh-empty состояние, close-to-tray, второй запуск возвращает тот же процесс, отсутствие автоматического model download при старте.
- В его actual `uiStates.fresh-empty`: NextSetupAction enabled/visible/invokable, StartStopRecording и CancelOperation visible/disabled; пустой result/Copy скрыт. В actual `uiStates.synthetic-persisted-result`: LastDictationText visible, ControlType.Edit, readOnly=true, exact ValuePattern=`SYNTHETIC installed normal-launch result: The quick brown fox jumps over the lazy dog.`; Copy visible/enabled/invokable. Фактический UIA Invoke Copy и exact clipboard read-back PASS.
- Installed populated text — **синтетически сохранённый текст**, не ASR этого запуска. Real bundled ASR доказан отдельным onboarding scenario. Эти источники не смешиваются.
- [installer-smoke.json](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/installer-smoke.json): success=true, version1.6.1, **492** payload files verified; synthetic settings/model/last-text sentinels сохранены побайтово через reinstall и uninstall. Это тест пустого runner profile с синтетическими данными, не проверка существующего профиля друга.

Независимо просмотрены actual PNG именно финального SHA:

1. [Installed normal fresh launch](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/installed-first-launch-smoke.png): normal window виден, No input device recovery, явная model CTA, объяснение Windows privacy, инструкции двойного левого Alt и tray/reopen, запись/отмена disabled.
2. [Onboarding fresh RU](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/onboarding-smoke-01-fresh-ru.png): model/setup CTA, ~488МБ, автоматическое сохранение модели, test/privacy actions видны; ложной готовности к записи нет.
3. [Real ASR result, before test scroll](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/onboarding-smoke-07-result-before-test-scroll.png): точный `The quick brown fox jumps over the lazy dog.` и `Копировать текст` одновременно видны.
4. [Synthetic layout150% result](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/layout-1.5-smoke-07-result-before-test-scroll.png): synthetic result/Copy одновременно видны; физический DPI не заявляется.
5. [Result EN](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/onboarding-smoke-08-result-en.png): exact recognized text и Copy одновременно видны, английские инструкции читаются.
6. [Processing](/tmp/macdictate-blind-acceptance.jqyq3I/final-artifacts/onboarding-smoke-06-processing.png): local CPU recognition status и Cancel видны, несовместимые действия disabled.

**WARN сохранения evidence:** JSON normal installed launch указывает `installed-first-launch-smoke.-populated.png` (точка перед `-populated`), но этого файла нет в скачанном artifact. `installed-first-launch-smoke.png` существует. Нельзя заявлять визуальную проверку отсутствующего populated installed PNG. Populated installed UI подтверждён actual UIA hierarchy/ValuePattern/clipboard; визуальный result+Copy подтверждён отдельным real-ASR PNG. Root явно решил не запускать дополнительный CI ради этого PNG; WARN сохраняется для release/evidence handoff.

### Требования исходного брифа — финальный G4

`implemented` означает подтверждение в указанном автоматическом контуре; `partial` означает доказанную часть с явно непроверенной внешней поверхностью.

| Требование пользователя | Статус | Одна evidence-линия |
|---|---|---|
| Очевидные Windows download buttons | **partial** | Source channel/pinned manifest и exact EXE/ZIP sourceSHA/hash PASS; внешний сайт/кликабельность опубликованных кнопок браузером не проверялись. |
| Понятная установка и первый экран | **implemented** | Installed normal production launch в пустом профиле + actual fresh PNG/UIA PASS, model CTA/статусы видны, запись заблокирована до готовности. |
| Понятно, почему нет запроса разрешения и что делать с микрофоном | **partial** | Actual fresh PNG содержит объяснение и privacy/test buttons; runner имеет0 real audio inputs, физическое разрешение/сигнал не проверены. |
| Alt запускает диктовку | **partial** | Реальные hook/alternate registration, policy и native paste PASS; onboarding activation использует seam, physical Alt на Windows10/11 NOT_TESTED. |
| Инструкции «что куда нажать» | **implemented** | Actual RU/EN setup/record/process/result окна и sequential model→microphone→record→recognize→Copy checks PASS; explicit instructions доступны в нормальном installed окне. |
| Автоматические сохранение/восстановление и понятные действия | **implemented** | Model/settings/last-text read-back и visible next-action/recovery PASS; ordinary reopen и sentinel preservation через reinstall/uninstall PASS. GUI HTTP success использовал synthetic seam; реальный integrity-checked model download для ASR выполнен script. |
| В итоге получить работающую диктовку/текст | **implemented** | Real bundled Whisper распознал synthetic spoken fixture; exact visible result + Copy/clipboard read-back PASS. Это подтверждает программный путь, не физический mic/Alt друга. |
| Довести весь путь первого запуска | **partial** | Полный автоматический Windows Server 2025 путь PASS; новая публичная доставка и физический Windows10/11 пользовательский путь остаются вне выполненной проверки. |

### Артефакты для передачи

Version1.6.1, sourceSHA `56b45301bc0e98c12f4823e5039152a3c3dd5229`, signed=false (по build manifest и exact byte checker):

| Файл | Bytes | SHA-256 |
|---|---:|---|
| `MacDictate_Windows_v1.6.1_x64.exe` | 54351051 | `fe85fd784649f057d16a115392b3c09cb7ceaf42e8f59beefc05d8149b3307e9` |
| `MacDictate_Windows_v1.6.1_x64.zip` | 77339968 | `55eedeed0bda8e91dc807cab00fefc9041e5c3d1151984508107e1e287c6365d` |

Финальные команды remote Windows выполнялись самим авторизованным workflow: portable tests → packaging guards → build → exact delivery/sourceSHA → native smoke → TTS fixture → onboarding one real Whisper/layout stress → installer/normal fresh+populated UIA/Copy/reopen/reinstall/uninstall. Точный log сохранён локально: `/tmp/macdictate-blind-acceptance.jqyq3I/final-windows-job.log`; run metadata: `/tmp/macdictate-blind-acceptance.jqyq3I/run-40747430459.json`.

### Что изменил проверяющий / что осталось

- Понято: пользователь хочет понятный и работающий Windows first-run до текста, включая модель, микрофон и Alt.
- Изменён только этот acceptance report; временная чистая копия и скачанные test artifacts находятся под `/tmp/macdictate-blind-acceptance.jqyq3I/`. Project source, spec, manifest, tickets и чужие reviews не правились.
- Выполнено три dispatch, каждый отдельно явно авторизован root; дальнейших запусков не было и не будет без новой авторизации. Никаких releases/publication/писем/сообщений реальным людям/платежей не выполнялось.
- G4 в автоматическом hosted контуре принят с retention WARN. Оба FAILED остаются историей, третий PASS их не стирает.
- Не проверены физические Windows10/11, microphone/Alt/сторонний editor компьютера друга, native monitor125/150%, actual GUI model HTTP success, interactive installer wizard/auto-launch checkbox/SmartScreen и live внешний download page. Локальное отсутствие SDK не трактуется как Windows runtime дефект.
- Следующие логичные шаги вне этой приёмки: исправить PNG retention в release/evidence контуре; отдельно пройти физический Windows10/11 сценарий и согласованную публикацию/доставку, сохраняя distinction между candidate и production. Никакой следующий шаг здесь не считается уже выполненным.
