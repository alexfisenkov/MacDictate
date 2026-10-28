# MacDictate для Windows

Бесплатная локальная диктовка для Windows x64. Основное окно показывает настройку, запись и результат; значок остаётся в области уведомлений. Приложение записывает микрофон и распознаёт речь через bundled whisper.cpp на CPU. Лицензия, активация и сервер приложения не требуются.

Windows-версия включает диктовку, выбор языка, настройку клавиш, установку модели и восстановление последнего текста. Автоматическое улучшение текста второй моделью пока доступно только в macOS-версии.

[Условия использования и политика конфиденциальности](https://alexfisenkov.github.io/MacDictate/legal.html). Их копии на русском и английском включены в папку `legal` внутри пакета.

## Установка и первая диктовка

Эти шаги относятся к опубликованной [Windows1.6.1](https://github.com/alexfisenkov/MacDictate/releases/tag/v1.6.1) от `2026-10-28T19:07:43Z`. Закреплённые EXE/ZIP-ссылки и SHA-256 находятся в `web-landing/downloads/latest-windows.json`; публичный файл проверки — `WINDOWS-SHA256SUMS` из того же GitHub Release. Windows-канал обновлён отдельно: macOS и глобальный latest остаются1.6.0. Обновлённый исходник сайта ожидает финальной Pages-публикации и HTTPS read-back.

1. На странице продукта выберите **Скачать установщик EXE · Windows10/11 x64**. EXE — рекомендуемый вариант: устанавливается для текущего пользователя, добавляет программу в меню «Пуск», после установки открывает окно MacDictate. **Portable ZIP** — альтернатива без установки: распакуйте всю папку и запустите `MacDictate.exe`; папка `runtime` должна оставаться рядом. .NET и Python отдельно не нужны.
2. В основном окне нажмите **Начать настройку: скачать модель** / **Start setup: download model**. Загрузка ~488МБ требует интернета; размер и SHA-256 проверяются, модель и настройки сохраняются автоматически. Кнопка Save не нужна. Уже выбранная пригодная модель используется повторно; чужой файл с отличающимся hash не заменяется молча. Можно выбрать совместимую Whisper ggml `.bin`.
3. Выберите вход, нажмите **Проверить микрофон** / **Test microphone** и говорите 3 секунды. Индикатор должен показать сигнал. При тишине проверьте mute и вход, повторите тест. Кнопка **Доступ к микрофону в Windows** / **Windows microphone privacy** открывает системные настройки: Windows11 — Settings → Privacy & security → Microphone; Windows10 — Settings → Privacy → Microphone. Включите доступ и разрешение классическим приложениям, вернитесь и повторите тест. Для этой desktop-программы Windows обычно не показывает отдельный запрос разрешения.
4. Нажмите **Начать запись** / **Start recording**, произнесите фразу, затем **Остановить и распознать** / **Stop and recognize**. Дождитесь текста в окне и нажмите **Копировать текст** / **Copy text**. Это первая проверка без зависимости от Alt. **Отменить** / **Cancel** останавливает запись или распознавание.
5. В окне проверьте горячую клавишу. Для глобальной диктовки поставьте курсор в обычное текстовое поле, дважды быстро нажмите и отпустите **левый Alt** для начала записи; ещё два нажатия останавливают запись. Не удерживайте клавишу. Right Alt/AltGr, Alt+Tab, сочетания и автоповтор не запускают запись. Альтернативы **Ctrl+Shift+Space** / **F8** переключают запись повторным нажатием. Максимум записи — две минуты.
6. Сохраняйте исходное поле активным до результата. Автоввод допускается только при совпадении UIAutomation identity и native HWND; неизвестное поле, смена фокуса, модификаторы или повышенные права означают безопасный отказ. Текст остаётся в основном окне: скопируйте его вручную. Если ввод прервался частично, проверьте уже вставленный фрагмент перед вставкой всего текста. Windows Unicode-ввод не гарантирует принятие каждым сторонним редактором.

Закрытие окна оставляет программу в трее. Двойной щелчок по значку либо повторный запуск из «Пуска» открывают то же окно. Состояния записи/распознавания остаются видимыми. Настройки, вход и языки `auto`/`ru`/`en` сохраняются; очистка последнего текста доступна из меню значка.

### Если Windows предупреждает о запуске

Пакет пока **без Authenticode-подписи**. Проверьте, что источник — официальный GitHub Release; сверьте SHA-256 EXE/ZIP с `WINDOWS-SHA256SUMS` этого же выпуска. При доступной кнопке после проверки можно выбрать **Подробнее → Выполнить в любом случае** / **More info → Run anyway**. Smart App Control или политика организации могут запрещать запуск без такой кнопки — обратитесь к администратору. Не отключайте защиту Windows и не считайте unsigned-пакет подписанным.

### Безопасный отчёт в поддержку

В окне выберите **Копировать диагностику без личных данных** / **Copy private-safe diagnostics**. Отчёт содержит версию, OS version, состояния runtime/model/microphone/hotkey и операции. В него не входят аудио, расшифровка, пути профиля, имя микрофона, заголовки чужих окон, аккаунты или пароли. Отправляйте только этот текст, если не договорились об отдельном материале; не присылайте записи, диктовку и снимки личных переписок.

## Локальные данные и ограничения

- Настройки, скачанная модель и последний текст: `%LOCALAPPDATA%\MacDictate`. Последний текст хранится до замены либо команды очистки. При явном ручном копировании буфер обмена Windows может сохранять текст, если включены история или синхронизация буфера.
- Временная WAV-запись удаляется после успеха, ошибки, отмены и штатного выхода. Принудительное завершение процесса или отключение питания может оставить временную запись в `%TEMP%`; удалите `macdictate-audio-*.wav` вручную при необходимости.
- Аудио и распознанный текст не отправляются по сети и не пишутся в диагностические логи. Интернет нужен только для явной загрузки модели и открытия страницы релизов.
- Windows 10 (2004+) / 11 x64 — целевая платформа. Сборка и native smoke в GitHub проверяются на **Windows Server 2025**; это не заменяет проверку физического микрофона, клавиш и вставки на Windows 10/11. Поддержка жизненного цикла самой Windows и .NET зависит от Microsoft.
- Инсталляция рядом с portable-копией допустима, но одновременно работает один экземпляр приложения на пользовательский сеанс. Обновляйте всю папку пакета: runtime и lock-файл входят в поставку.

## Сборка и проверки

Из корня desktop Git-репозитория (`macos/`):

```sh
windows/scripts/check-local.sh
python3 windows/scripts/check-delivery.py
```

SDK закреплён в `windows/global.json`; из Windows-папки выполняются publish/package scripts. Cross-build на Mac проверяет компиляцию, но не исполняет Win32.

Native Windows интеграция:

```powershell
MacDictate.exe --smoke-test --report native-smoke.json
MacDictate.exe --transcribe sample.wav --model model.bin --language en --report asr-smoke.json
MacDictate.exe --onboarding-smoke --model model.bin --fixture-wave synthetic.wav --report onboarding-smoke.json
MacDictate.exe --onboarding-smoke --layout-scale 1.25 --report layout-1.25-smoke.json
MacDictate.exe --onboarding-smoke --layout-scale 1.5 --report layout-1.5-smoke.json
```

Запускайте WinExe через `Start-Process -Wait -PassThru` и проверяйте `ExitCode` и JSON-файл; полагаться на вывод в консоль не требуется. Native smoke открывает собственный TextBox, проверяет реальный Unicode-ввод, суррогатную пару и безопасную замену перевода строки пробелом с read-back, сохранность буфера обмена, закрытие активного native Alt-меню, запрет чужого окна и другого TextBox в том же окне с проверкой неизменности обоих полей, регистрацию hook/альтернативных клавиш и игнорирование injected Alt. Физический микрофон и физические нажатия Alt этим тестом не проверяются. `--transcribe` использует существующий файл, не удаляя переданный пользователем источник.

## Карта кода

- `src/MacDictate.Core`: pure hotkey policy, settings/last text store, pinned model downloader, bounded Whisper process runner.
- `src/MacDictate.Windows/Native`: WinMM event-driven capture с pinned buffers, keyboard hook, foreground/input-safe Unicode SendInput bridge и ограниченная по времени UI Automation identity. WPF framework reference нужен только для системного UI Automation API; интерфейс приложения остаётся WinForms.
- `src/MacDictate.Windows/TrayApplication.cs`: lifecycle и связка сценария диктовки; MainForm отображает readiness/состояние; SessionServices отделяет native capture и ASR от явных test seams.
- `tests/MacDictate.Core.Tests`: console harness без test-framework зависимостей; реальные ошибки, отмена, timeout, integrity/atomic replacement.
- `runtime-lock.json`, `scripts/`: источник runtime/model pins и упаковка, принадлежат release-контуру.

## Восстановление после отдельных ошибок

Если доступность стороннего приложения зависла, автоввод безопасно отключается: последняя диктовка остаётся для ручного копирования. Перезапустите MacDictate, чтобы восстановить проверку фокуса. Файл модели с отличающимся SHA не перезаписывается: перенесите его в другое место и повторите загрузку, либо выберите существующую рабочую модель. Windows10 Home/Pro находится вне текущего официального списка поддержки .NET10; проверка совместимости на клиентской ОС остаётся отдельной.

Если SmartScreen показывает неизвестного издателя, сначала сравните SHA-256 файла с `WINDOWS-SHA256SUMS` из того же релиза (`Get-FileHash -LiteralPath "$env:USERPROFILE\Downloads\MacDictate_Windows_v1.6.1_x64.exe" -Algorithm SHA256`; замените путь в кавычках на путь к скачанному файлу). Если проверка совпала и вы доверяете источнику, Windows может предложить **More info → Run anyway**. При запрете политикой организации обратитесь к администратору; отключать защиту системы для установки не требуется.

## Финальная автоматическая приёмка1.6.1

Один ручной `.github/workflows/desktop-release.yml` после локальных проверок и review: governance/Swift regressions, Windows core/build, sourceSHA+actual package hashes, native hook/paste smoke, UI onboarding с реальным bundled Whisper на синтетическом TTS, два дешёвых layout-stress125/150%, installer payload/normal fresh launch/reopen/reinstall/uninstall.

`test-onboarding.ps1 -WavePath <synthetic.wav>` загружает ровно одну закреплённую модель, использует кириллицу/пробелы/emoji в путях и выполняет **один** реальный ASR через кнопки окна. PCM берётся из синтетического WAV через capture seam; клавиша активируется test seam, реальный hook регистрируется. Это не физический микрофон/Alt. Дополнительные layout-прогоны используют синтетический transcript seam, масштабируют геометрию и шрифт, проверяют bounds/перенос текста, сохраняют RU/EN PNG и отдельно actual desktop DPI. Они не доказывают native монитор125/150%.

`test-install.ps1` сравнивает каждый файл с исходным self-contained payload, запускает native smoke и обычный installed EXE без test CLI в действительно пустом профиле runner. UIAutomation проверяет новый экран/кнопки, запрет ложной готовности, закрытие в трей и повторный запуск. Скрипт отказывается трогать существующий профиль. Синтетические settings/model/last-text sentinels должны пережить reinstall и uninstall побайтово. JSON/PNG и release EXE/ZIP сохраняются в CI artifacts; сырой WAV, модель и пользовательские данные не загружаются.

Финальный run [40747430459](https://github.com/alexfisenkov/MacDictate/actions/runs/40747430459) на source `56b45301bc0e98c12f4823e5039152a3c3dd5229` прошёл все три jobs. Actual JSON подтвердили 62 portable checks, real bundled ASR на synthetic PCM/key seams, normal installed fresh launch/reopen и populated UIA/Copy/clipboard, 492 payload files и сохранность synthetic sentinels при reinstall/uninstall. Два ранних failed attempts и разрешённые repairs сохранены в acceptance report. Релиз `releases/versions/v1.6.1/RELEASE.md` имеет статус `public_release`: четыре public API digest/size совпали с проверенными артефактами; Pages/browser/HTTP-download read-back ещё не выполнен.

Actual desktop DPI96; layout125/150% проверен синтетическим масштабированием. Один populated installed PNG отсутствует в artifact; actual UIA/clipboard PASS и отдельный real-ASR result PNG не заменяют визуальную проверку этого отсутствующего файла. Физические Windows10/11 microphone/Alt/editor, native125/150%, GUI HTTP-success model download и interactive installer/SmartScreen остаются NOT_RUN.
