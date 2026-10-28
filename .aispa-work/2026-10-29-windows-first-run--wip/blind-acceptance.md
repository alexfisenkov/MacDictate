# Независимая приёмка Windows first-run

Дата: 2026-10-29 (Asia/Makassar). Проверяющий видел только исходный `2026-10-29-brief.md` из каталога прогона. Спецификации, manifest, tickets и чужие reviews не открывались. Исходники проекта не изменялись.

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
- Artifact скачан exit 0 в `/tmp/macdictate-blind-acceptance.jqyq3I/repair-artifacts`; JSON прочитаны и 8 actual PNG независимо просмотрены (подробнее ниже).
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
