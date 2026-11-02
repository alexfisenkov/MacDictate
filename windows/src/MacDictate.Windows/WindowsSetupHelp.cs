namespace MacDictate.Windows;

// Local UI copy: help remains available before a model download and without a browser.
internal static class WindowsSetupHelp
{
    internal const string PrivacyUri = "ms-settings:privacy-microphone";
    internal const string SoundUri = "ms-settings:sound";
    internal static string SourceUri(string language) => "https://support.microsoft.com/" + (language == "ru" ? "ru-ru" : "en-us") + "/windows/hardware/drivers/fix-microphone-problems";
    internal static int SuggestedWindowsMajor => OperatingSystem.IsWindowsVersionAtLeast(10, 0, 22000) ? 11 : 10;
    internal static string Text(string language, int windowsMajor) => language == "ru" ? Russian(windowsMajor) : English(windowsMajor);

    private static string Russian(int version) => $"""
        ПЕРВАЯ ДИКТОВКА · WINDOWS {version}

        Окно разрешения может не появиться — для обычного настольного приложения это нормально. Проверяем доступ по реальному звуку, а не по наличию такого окна. Версия Windows выбрана автоматически; при необходимости переключите её выше. Узнать свою версию: «Пуск → Параметры → Система → О системе».

        1. СКАЧАЙТЕ МОДЕЛЬ ОДИН РАЗ
        В главном окне нажмите «Начать настройку: скачать модель» или «Скачать модель». Дождитесь завершения (~488 МБ, нужен интернет). Модель сохраняется автоматически; отдельной кнопки Save нет. При ошибке загрузки прочитайте сообщение в главном окне. После загрузки распознавание работает без интернета.

        2. РАЗРЕШИТЕ ДОСТУП К МИКРОФОНУ
        Нажмите ниже «Доступ к микрофону в Windows». Если настройки не открылись, нажмите Win+I (клавиша с логотипом Windows + I) и пройдите путь вручную:

        {PrivacyStepsRu(version)}

        Настройка для классических приложений относится ко всем таким программам. MacDictate может отсутствовать в списке отдельных приложений — искать для него отдельный переключатель не нужно. Названия могут немного отличаться в разных обновлениях Windows. Если переключатель недоступен или написано «Некоторыми параметрами управляет ваша организация», обратитесь к администратору компьютера. MacDictate не может включить этот доступ за вас.

        3. ВЫБЕРИТЕ МИКРОФОН И ПРОВЕРЬТЕ ЗВУК
        Подключите микрофон или гарнитуру; снимите отключение звука кнопкой на устройстве. Нажмите ниже «Настройки звука» или откройте «Пуск → Параметры → Система → Звук».

        {SoundStepsRu(version)}

        Если входа нет даже в настройках Windows, проверьте подключение устройства.

        Вернитесь в главное окно MacDictate, нажмите «Обновить входы», выберите свой микрофон в списке, затем «Проверить микрофон» и говорите 3 секунды. Нужны движение индикатора и сообщение «Сигнал получен в этом сеансе. Можно записывать». Если тишина — проверьте выбранный вход, громкость и кнопку отключения звука; повторите тест. Ошибка или отсутствие устройства не всегда означают запрет доступа. После изменения настроек Windows повторите эти действия; при необходимости закройте MacDictate через меню значка → «Выход» и запустите снова.

        4. СДЕЛАЙТЕ ПЕРВУЮ ЗАПИСЬ КНОПКОЙ
        Нажмите «Вернуться в MacDictate», затем «Начать запись». Произнесите короткую фразу и нажмите «Остановить и распознать». Дождитесь текста и нажмите «Копировать текст». Откройте Блокнот или другое текстовое поле, поставьте курсор и нажмите Ctrl+V. «Отменить» останавливает запись или распознавание. Максимальная запись — 2 минуты.

        5. ПРОВЕРЬТЕ ДВОЙНОЙ ЛЕВЫЙ ALT
        В главном окне выберите DoubleAlt и нажмите «Проверить клавишу без записи». Два раза быстро нажмите и отпустите левый Alt, без других клавиш. Успешная проверка покажет, что клавиша сработала; для выхода из режима проверки нажмите «Завершить проверку клавиши». Правый Alt / AltGr не подходит. Отдельного разрешения Windows на эту клавишу не требуется.

        Для диктовки поставьте курсор в поле другого приложения: два быстрых нажатия левого Alt начинают запись, ещё два останавливают её. Не переключайте исходное поле до результата. Если Alt не срабатывает, выберите в главном окне F8 или CtrlShiftSpace (Ctrl+Shift+Пробел), проверьте эту комбинацию; одно нажатие начинает запись, повторное останавливает. Запись кнопкой доступна независимо от горячей клавиши.

        6. ЕСЛИ ТЕКСТ НЕ ВСТАВИЛСЯ
        Откройте окно MacDictate, нажмите «Копировать текст», вернитесь в нужное поле и нажмите Ctrl+V. Перед вставкой проверьте, не появился ли там уже фрагмент текста. Если проблема сохраняется, нажмите «Копировать диагностику без личных данных» в главном окне: отчёт не содержит вашу запись и распознанный текст. Не нужно отключать защиту Windows или запускать MacDictate от имени администратора.

        Закрытие главного окна оставляет MacDictate в области уведомлений возле часов. Двойной щелчок по значку или запуск из «Пуска» снова открывает это окно.

        Справка Microsoft по настройкам микрофона доступна по кнопке ниже (для открытия нужен интернет). Все шаги выше доступны без сети.
        """;

    private static string PrivacyStepsRu(int version) => version >= 11 ? """
        • Откройте «Пуск → Параметры → Конфиденциальность и безопасность → Микрофон».
        • Включите «Доступ к микрофону».
        • Включите «Разрешить приложениям доступ к микрофону».
        • Прокрутите страницу вниз и включите «Разрешить классическим приложениям доступ к микрофону».
        """ : """
        • Откройте «Пуск → Параметры → Конфиденциальность → Микрофон».
        • В разделе доступа для этого устройства нажмите «Изменить» и включите доступ к микрофону для устройства, если он выключен.
        • Включите «Разрешить приложениям доступ к микрофону».
        • Прокрутите страницу вниз и включите «Разрешить классическим приложениям доступ к микрофону».
        """;

    private static string SoundStepsRu(int version) => version >= 11
        ? "В разделе «Ввод» выберите свой микрофон. Откройте его свойства стрелкой справа. В разделе «Проверка микрофона» нажмите «Начать тест», произнесите фразу, затем «Остановить тест». Можно нажать «Воспроизвести» у записанного образца, чтобы прослушать его. При слабом звуке увеличьте громкость ввода."
        : "В разделе «Ввод» выберите свой микрофон. Говорите и смотрите на шкалу «Проверьте микрофон»: она должна двигаться. Если движения нет, проверьте отключение звука и громкость устройства, затем повторите проверку.";

    private static string English(int version) => $"""
        FIRST DICTATION · WINDOWS {version}

        A permission pop-up may never appear: this is normal for a desktop app. Verify access by capturing an actual signal. The Windows version above is suggested automatically; change it if needed. Find your version in Start → Settings → System → About.

        1. DOWNLOAD THE MODEL ONCE
        In the main window, select Start setup: download model or Download model. Wait for the download (~488 MB; internet required). The model is saved automatically; there is no separate Save button. If it fails, read the message in the main window. Recognition then works offline.

        2. ALLOW MICROPHONE ACCESS
        Select Windows microphone privacy below. If Settings does not open, press Win+I (Windows logo key + I) and follow this path:

        {PrivacyStepsEn(version)}

        The desktop-app switch affects desktop apps generally. MacDictate may not have its own entry: you do not need to find an individual switch for it. Labels can vary between Windows updates. If a switch is unavailable or managed by your organization, ask the computer administrator. MacDictate cannot turn access on for you.

        3. SELECT AND TEST YOUR MICROPHONE
        Connect your microphone or headset and turn off its hardware mute. Select Sound settings below, or open Start → Settings → System → Sound.

        {SoundStepsEn(version)}

        If Windows lists no input device, check the connection.

        Return to the main MacDictate window. Select Refresh inputs, choose your microphone, then Test microphone and speak for 3 seconds. Look for a moving level meter and Signal received in this session. You can record. If silent, check the selected input, volume and mute, then test again. An error or missing device does not necessarily mean access was denied. Repeat these steps after changing Windows settings. If needed, quit MacDictate through its tray menu → Quit and launch it again.

        4. MAKE YOUR FIRST RECORDING WITH THE BUTTON
        Select Return to MacDictate, then Start recording. Say a short phrase, select Stop and recognize, wait for the text and select Copy text. Open Notepad or another text field, click where you want the text and press Ctrl+V. Cancel stops recording or recognition. The recording limit is 2 minutes.

        5. TEST DOUBLE LEFT ALT
        In the main window, select DoubleAlt and Test hotkey without recording. Quickly tap and release left Alt twice without any other keys. When the test succeeds, select Finish hotkey test to leave test mode. Right Alt / AltGr does not activate dictation. Windows requires no separate keyboard permission for this.

        To dictate into another app, focus its text field: two quick left Alt taps start recording; two more stop it. Keep that field active until recognition finishes. If Alt does not work, choose F8 or CtrlShiftSpace (Ctrl+Shift+Space) in the main window and test it; press once to start and again to stop. The recording button works independently of the hotkey.

        6. IF TEXT IS NOT INSERTED
        Open MacDictate, select Copy text, return to the target field and press Ctrl+V. Check whether part of the text was already inserted before pasting the full result. If problems continue, use Copy private-safe diagnostics in the main window; it excludes your audio and recognized text. You do not need to disable Windows protection or run MacDictate as administrator.

        Closing the main window leaves MacDictate in the notification area near the clock. Double-click its icon or launch it from Start to reopen the window.

        The Microsoft microphone help button below needs internet. All steps above remain available offline.
        """;

    private static string PrivacyStepsEn(int version) => version >= 11 ? """
        • Open Start → Settings → Privacy & security → Microphone.
        • Turn on Microphone access.
        • Enable the option that lets apps use your microphone.
        • Scroll down and enable Let desktop apps access your microphone.
        """ : """
        • Open Start → Settings → Privacy → Microphone.
        • Under access for this device, select Change and enable microphone access for the device if disabled.
        • Enable the option that allows apps to use your microphone.
        • Scroll down and enable Allow desktop apps to access your microphone.
        """;

    private static string SoundStepsEn(int version) => version >= 11
        ? "Under Input, choose your microphone and use the arrow on its right to open properties. In Microphone test, select Start test, say a phrase and select Stop test. Use Play beside the recorded sample if you want to listen to it. Raise input volume if the sound is too quiet."
        : "Under Input, select your microphone. Speak while watching the Test your microphone meter; it should respond. If it does not move, check the device mute and volume, then repeat the test.";
}
