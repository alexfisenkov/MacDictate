# F1 — Заключительный ремонт первого запуска

**Требования:** R02, R03, R05, R06, R07, R08i, R09i, R10i
**Зависит от:** —
**Зона:** `windows/src/MacDictate.Core` · `windows/src/MacDictate.Windows/MainForm.cs` · `windows/src/MacDictate.Windows/TrayApplication.cs` · `windows/src/MacDictate.Windows/Native/MicrophoneService.cs` · `windows/src/MacDictate.Windows/Native/PasteService.cs` · `windows/src/MacDictate.Windows/OnboardingSmoke.cs` · `windows/tests` · `web-landing/index.html`
**Волна:** 3
**Ревью:** да — ремонт ветки
**Модель:** сильная

## Что должно заработать
Все FIX NOW whole-branch review закрыты одним согласованным ремонтом, без маскировки результата тестовыми скроллами и без продолжения действий после Cancel. Новые функции сверх этого не добавляются.

## Из брифа, дословно
> «ничерта не понятно, никаких инструкций что куда нажать?»
> «Никаких автоматических действий, и ни какой работы в итоге! Доводи до конца!»

## Разделы спецификации
Истории R02/R03/R05/R06/R07/R08i/R09i/R10i, все связанные error/cancel/visibility случаи. interfaces.md, notes.md.

## Критерии приёмки — FIX NOW дословно из ревью
- [ ] MainForm.cs:82, TrayApplication.cs:35: после обновления пустого списка входов NoDevice сбрасывается в Untested; ошибка перечисления тоже затирается. Пользователь видит неверную готовность. Сохранять фактический статус после refresh. MicrophoneService.cs:23: отличать ошибку waveInGetDevCaps от отсутствия устройств.
- [ ] TrayApplication.cs:180, MainForm.cs:37: после распознавания LastDictationText и Copy остаются ниже видимой области длинной формы. Производственный UI должен показать оба элемента вместе; тест уже требует resultVisibleBeforeTestScroll.
- [ ] MainForm.cs:133: сообщения об ошибке и ходе операции расположены ниже длинных инструкций. При открытии окна после отказа пользователь может видеть прежний верх экрана. Показывать актуальный статус в видимой области.
- [ ] TrayApplication.cs:151: при глобальном запуске Cancel во время ожидания UI Automation ничего не отменяет; после ожидания запись начинается. Отменять состояние Starting и проверять его перед StartCapture.
- [ ] TrayApplication.cs:180, PasteService.cs:22: если нажать Cancel после ответа Whisper, пока UI Automation ищет поле, SendInput всё ещё может вставить текст. Проверять отмену после ASR и перед отправкой каждого фрагмента.
- [ ] web-landing/index.html:63: главная Windows-кнопка без успешного JS/fetch ведёт к #download, а не к EXE. Задать ей закреплённый EXE URL в исходном HTML.

## Ограничения ремонта
Один writer, no new dependencies, no model/userdata deletion, no version/publication/hostedCI. Нужны RED→GREEN регрессии ошибок/отмены; code-local54baseline. Production scrolling/reveal не должен забирать foreground у внешнего поля до безопасного ввода. Synthetic layout/PCM/hotkey остаются явно помечены. REPORT из ревью об уже лежащем другом model hash не включён в FIX NOW, не расширять список молча.
