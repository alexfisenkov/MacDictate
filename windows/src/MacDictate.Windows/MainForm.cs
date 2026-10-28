using MacDictate.Core;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
internal sealed class MainForm : Form
{
    private readonly ComboBox uiLanguage = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 150, AccessibleName = "Interface language" };
    private readonly ComboBox language = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 150, AccessibleName = "Recognition language" };
    private readonly ComboBox hotkey = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 180, AccessibleName = "Hotkey" };
    private readonly ComboBox microphone = new() { DropDownStyle = ComboBoxStyle.DropDownList, Width = 320, DisplayMember = "Name", AccessibleName = "Microphone" };
    private readonly Label options = Label(), heading = Label(), next = Label(), readiness = Label(), privacy = Label(), instructions = Label(), model = Label(), micStatus = Label(), keyStatus = Label(), message = Label(), operationStatus = Label();
    private readonly Button nextAction = Button(), download = Button(), browse = Button(), micTest = Button(), refreshMic = Button(), privacyButton = Button(), soundButton = Button(), keyTest = Button(), copy = Button(), diagnostics = Button(), record = Button(), cancel = Button();
    private readonly ProgressBar level = new() { Minimum = 0, Maximum = 100, Width = 320, AccessibleName = "Microphone signal" };
    private readonly ProgressBar transfer = new() { Minimum = 0, Maximum = 100, Width = 320, AccessibleName = "Model download" };
    private readonly TextBox result = new() { Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, Height = 110, Width = 540, AccessibleName = "Last dictation" };
    private ViewState view;
    private readonly LocalErrorState localFeedback = new();
    private bool updating, allowClose, showWithoutActivation;
    private readonly Func<IReadOnlyList<MicrophoneDevice>> enumerate;
    public bool TestingHotkey { get; private set; }
    public event Action<AppSettings>? SettingsChanged;
    public event Action? DownloadRequested, MicrophoneTestRequested, RecordRequested, CancelRequested;
    public event Action? HiddenToTray;
    public event Action? InputConfigurationChanged;
    public event Action<MicrophoneSelection>? MicrophoneRefreshed;
    public string UiLanguage => view.Settings.UiLanguage is "ru" or "en" ? view.Settings.UiLanguage : System.Globalization.CultureInfo.CurrentUICulture.TwoLetterISOLanguageName == "ru" ? "ru" : "en";
    public string T(string ru, string en) => UiLanguage == "ru" ? ru : en;
    public MainForm(ViewState initial, Func<IReadOnlyList<MicrophoneDevice>>? enumerate = null)
    {
        view = initial; this.enumerate = enumerate ?? MicrophoneService.Enumerate;
        Text = "MacDictate"; Name = "MacDictateMainWindow";
        record.Name = "StartStopRecording"; cancel.Name = "CancelOperation"; copy.Name = "CopyLastDictation";
        result.Name = "LastDictationText"; nextAction.Name = "NextSetupAction";
        message.Name = "OperationMessage"; micStatus.Name = "MicrophoneStatus"; operationStatus.Name = "OperationStatus";
        AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96);
        ClientSize = new Size(650, 680); MinimumSize = new Size(520, 580); StartPosition = FormStartPosition.CenterScreen;
        heading.Font = new Font(Font.FontFamily, 13, FontStyle.Bold);
        var footer = new FlowLayoutPanel { Dock = DockStyle.Bottom, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, Padding = new Padding(12), WrapContents = true };
        record.MinimumSize = new Size(220, 44); cancel.MinimumSize = new Size(110, 44); footer.Controls.AddRange([record, cancel]);
        // Current state and recovery text never scroll away with setup instructions.
        var current = new FlowLayoutPanel { Name = "CurrentStatus", Dock = DockStyle.Top, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(18, 4, 18, 4) };
        current.Controls.AddRange([operationStatus, micStatus, message]);
        // Result and Copy share a non-scrolling surface above the record controls.
        var outcome = new FlowLayoutPanel { Name = "DictationResult", Dock = DockStyle.Bottom, AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(18, 0, 18, 6), Visible = false };
        result.Height = 76; outcome.Controls.AddRange([result, copy]);
        var body = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, AutoScroll = true, Padding = new Padding(18) };
        body.Controls.AddRange([heading, next, nextAction, readiness, options, Row(uiLanguage, language, hotkey), model, Row(download, browse), transfer,
            microphone, Row(micTest, refreshMic), level, privacy, Row(privacyButton, soundButton), instructions, keyTest, keyStatus, diagnostics]);
        Controls.Add(body); Controls.Add(outcome); Controls.Add(current); Controls.Add(footer);
        body.SizeChanged += (_, _) =>
        {
            int width = Math.Max(250, body.ClientSize.Width - 50);
            foreach (var label in new[] { options, heading, next, readiness, privacy, instructions, model, micStatus, keyStatus, message }) label.MaximumSize = new Size(width, 0);
            foreach (var row in body.Controls.OfType<FlowLayoutPanel>()) row.MaximumSize = new Size(width, 0);
            foreach (var button in body.Controls.OfType<Button>()) button.MaximumSize = new Size(width, 0);
            result.Width = width; microphone.Width = Math.Min(400, width);
            foreach (var label in new[] { operationStatus, micStatus, message }) label.MaximumSize = new Size(width, 0);
        };
        uiLanguage.Items.AddRange(["Русский", "English"]); language.Items.AddRange(["auto", "ru", "en"]); hotkey.Items.AddRange(["DoubleAlt", "CtrlShiftSpace", "F8"]);
        uiLanguage.SelectedIndexChanged += (_, _) => Save(view.Settings with { UiLanguage = uiLanguage.SelectedIndex == 0 ? "ru" : "en" });
        language.SelectedIndexChanged += (_, _) => Save(view.Settings with { Language = language.SelectedItem?.ToString() ?? "auto" });
        hotkey.SelectedIndexChanged += (_, _) => { TestingHotkey = false; Save(view.Settings with { Hotkey = hotkey.SelectedItem?.ToString() ?? "DoubleAlt" }); };
        microphone.SelectedIndexChanged += (_, _) => { if (microphone.SelectedItem is MicrophoneDevice device) Save(view.Settings with { MicrophoneDeviceId = device.Id }); };
        download.Click += (_, _) => DownloadRequested?.Invoke(); browse.Click += (_, _) => ChooseModel();
        micTest.Click += (_, _) => MicrophoneTestRequested?.Invoke(); refreshMic.Click += (_, _) => RefreshMicrophones(true);
        privacyButton.Click += (_, _) => { InputConfigurationChanged?.Invoke(); Open("ms-settings:privacy-microphone"); }; soundButton.Click += (_, _) => { InputConfigurationChanged?.Invoke(); Open("ms-settings:sound"); };
        keyTest.Click += (_, _) => { TestingHotkey = !TestingHotkey; keyStatus.Text = TestingHotkey ? view.Settings.Hotkey == "DoubleAlt" ? T("Дважды быстро нажмите и отпустите левый Alt. Повторите двойное нажатие для остановки записи.", "Quickly tap and release left Alt twice. Repeat the double tap to stop a recording.") : T("Нажмите выбранную клавишу: ", "Press the selected hotkey: ") + view.Settings.Hotkey : ""; Render(view); };
        record.Click += (_, _) => { TestingHotkey = false; RecordRequested?.Invoke(); };
        cancel.Click += (_, _) => CancelRequested?.Invoke();
        copy.Click += (_, _) => { try { if (result.Text.Length > 0) Clipboard.SetText(result.Text); } catch { ShowCopyFailure(); } };
        diagnostics.Click += (_, _) => { try { Clipboard.SetText(DiagnosticsText()); } catch { ShowCopyFailure(); } };
        nextAction.Click += (_, _) =>
        {
            switch (view.Readiness.Next)
            {
                case SetupStep.Runtime: Open("https://github.com/alexfisenkov/MacDictate/releases"); break;
                case SetupStep.Model: DownloadRequested?.Invoke(); break;
                case SetupStep.Microphone: MicrophoneTestRequested?.Invoke(); break;
                case SetupStep.Hotkey: TestingHotkey = true; Render(view); keyStatus.Text = T("Нажмите выбранную горячую клавишу. Для Alt нужны два быстрых нажатия слева.", "Press the selected hotkey. For Alt, tap left Alt twice quickly."); break;
                default: TestingHotkey = false; RecordRequested?.Invoke(); break;
            }
        };
        FormClosing += (_, e) => { if (!allowClose) { e.Cancel = true; Hide(); HiddenToTray?.Invoke(); } };
        VisibleChanged += (_, _) => { if (!Visible) TestingHotkey = false; };
        Resize += (_, _) => { if (WindowState == FormWindowState.Minimized) TestingHotkey = false; };
        RefreshMicrophones(); Render(view);
    }
    private static Label Label() => new() { AutoSize = true, MaximumSize = new Size(580, 0), Margin = new Padding(3, 7, 3, 4) };
    private static Button Button() => new() { AutoSize = true, MinimumSize = new Size(90, 32) };
    private static FlowLayoutPanel Row(params Control[] controls) { var row = new FlowLayoutPanel { AutoSize = true, AutoSizeMode = AutoSizeMode.GrowAndShrink, MaximumSize = new Size(550, 0), WrapContents = true }; row.Controls.AddRange(controls); return row; }
    private void Save(AppSettings settings) { if (!updating && settings != view.Settings) SettingsChanged?.Invoke(settings); }
    public bool RefreshMicrophones(bool invalidateSignal = false)
    {
        MicrophoneSelection selection;
        bool available;
        bool before = updating; updating = true;
        try
        {
            var devices = enumerate(); microphone.Items.Clear();
            selection = MicrophoneSelection.Reconcile(view.Settings.MicrophoneDeviceId, devices.Select(x => x.Id).ToArray(), invalidateSignal ? MicrophoneSelection.Invalidate(view.Microphone) : view.Microphone);
            if (devices.Count > 0) microphone.Items.Add(new MicrophoneDevice(uint.MaxValue, T("Системный вход по умолчанию", "System default input")));
            foreach (var device in devices) microphone.Items.Add(device);
            microphone.SelectedItem = microphone.Items.Cast<MicrophoneDevice>().FirstOrDefault(x => x.Id == selection.DeviceId);
            available = devices.Count > 0;
        }
        catch { selection = new(view.Settings.MicrophoneDeviceId, MicrophoneReadiness.Error); available = false; microphone.Items.Clear(); }
        finally { updating = before; }
        view = view with { Settings = view.Settings with { MicrophoneDeviceId = selection.DeviceId }, Microphone = selection.Readiness };
        // Controller receives the actual enumeration outcome, never a blanket
        // Untested notification that can overwrite NoDevice/Error after refresh.
        MicrophoneRefreshed?.Invoke(selection);
        Render(view);
        return available;
    }
    public void Render(ViewState state)
    {
        view = state; updating = true;
        try
        {
            uiLanguage.SelectedIndex = UiLanguage == "ru" ? 0 : 1; language.SelectedItem = state.Settings.Language; hotkey.SelectedItem = state.Settings.Hotkey;
            microphone.SelectedItem = microphone.Items.Cast<MicrophoneDevice>().FirstOrDefault(x => x.Id == state.Settings.MicrophoneDeviceId);
            bool idle = state.Activity == AppActivity.Idle;
            operationStatus.Text = state.Activity switch
            {
                AppActivity.Starting => T("Подготовка записи… Можно отменить.", "Preparing recording… You can cancel."),
                AppActivity.Downloading => T($"Загрузка модели · {state.DownloadPercent}%", $"Downloading model · {state.DownloadPercent}%"),
                AppActivity.TestingMicrophone => T("Проверка микрофона · говорите сейчас", "Testing microphone · speak now"),
                AppActivity.Recording => T($"● Запись · {state.ElapsedSeconds} с", $"● Recording · {state.ElapsedSeconds}s"),
                AppActivity.Processing => T("Распознавание локально на CPU… Можно отменить.", "Recognizing locally on CPU… You can cancel."),
                _ => T("MacDictate · готов к следующему действию", "MacDictate · ready for the next action")
            };
            options.Text = T("Интерфейс · язык распознавания (auto — автоматически) · горячая клавиша", "Interface · recognition language (auto = automatic) · hotkey");
            heading.Text = T("Голос → текст на этом компьютере", "Your voice → text on this computer");
            readiness.Text = T("Готовность: ", "Readiness: ") + $"Whisper {(state.RuntimeReady ? "✓" : "—")} · {T("Модель", "Model")} {(state.ModelReady ? "✓" : "—")} · {T("Микрофон", "Microphone")} {(state.Microphone == MicrophoneReadiness.Signal ? "✓" : "—")} · {T("Клавиша", "Hotkey")} {(state.HotkeyReady && state.HotkeyVerified ? "✓" : "—")}";
            next.Text = state.Readiness.Next switch
            {
                SetupStep.Runtime => T("1. Не найден локальный Whisper. Переустановите MacDictate.", "1. Local Whisper is missing. Reinstall MacDictate."),
                SetupStep.Model => T("1. Нажмите «Скачать модель» (~488 МБ). После проверки она сохранится автоматически. Затем распознавание работает без сети.", "1. Download the model (~488 MB). It is verified and saved automatically. Recognition then works offline."),
                SetupStep.Microphone => T("2. Выберите микрофон, нажмите «Проверить» и говорите 3 секунды. Разрешение подтверждается только реальным сигналом.", "2. Choose your input, select Test, and speak for 3 seconds. Only a real signal verifies the microphone."),
                SetupStep.Hotkey => T("3. Проверьте горячую клавишу. Запись кнопкой уже доступна, даже если Alt не работает.", "3. Test the hotkey. The record button already works even if Alt is unavailable."),
                _ => T("4. Нажмите «Начать запись», говорите, затем «Остановить и распознать». Текст появится ниже — нажмите «Копировать».", "4. Select Start recording, speak, then Stop and recognize. Your text appears below — select Copy.")
            };
            nextAction.Text = state.Readiness.Next switch { SetupStep.Runtime => T("Открыть выпуски", "Open releases"), SetupStep.Model => T("Начать настройку: скачать модель", "Start setup: download model"), SetupStep.Microphone => T("Проверить микрофон — 3 секунды", "Test microphone — 3 seconds"), SetupStep.Hotkey => T("Проверить горячую клавишу", "Test hotkey"), _ => T("Начать первую запись", "Start a dictation") };
            nextAction.Enabled = idle;
            model.Text = state.ModelReady ? T("Модель выбрана. Загрузка больше не нужна. Формат проверен предварительно; окончательная проверка — распознавание.", "Model selected. No download needed. Format checked; recognition performs the final validation.") : T("Модель отсутствует или не читается. Выберите Whisper ggml .bin либо скачайте проверенную модель.", "Model is missing or unreadable. Choose a Whisper ggml .bin or download the verified model.");
            download.Text = T("Скачать модель", "Download model"); browse.Text = T("Выбрать .bin…", "Choose .bin…");
            transfer.Visible = state.Activity == AppActivity.Downloading; transfer.Value = state.DownloadPercent;
            micTest.Text = T("Проверить микрофон", "Test microphone"); refreshMic.Text = T("Обновить входы", "Refresh inputs");
            micStatus.Text = state.Microphone switch { MicrophoneReadiness.Signal => T("Сигнал получен в этом сеансе. Можно записывать.", "Signal received in this session. You can record."), MicrophoneReadiness.Silent => T("Запись получена, но достаточного сигнала нет. Говорите громче, проверьте mute и выбранный вход; повторите тест.", "Capture completed without sufficient signal. Speak louder, check mute and selected input; retry the test."), MicrophoneReadiness.NoDevice => T("Нет входного устройства. Подключите микрофон и обновите входы.", "No input device. Connect a microphone and refresh inputs."), MicrophoneReadiness.Error => T("Не удалось получить список входов или записать. Проверьте настройки звука и доступ для классических приложений; обновите входы и повторите тест.", "Cannot list inputs or capture. Check Sound settings and desktop-app access; refresh inputs and retry the test."), _ => T("Микрофон ещё не проверен. Во время теста говорите и следите за уровнем.", "Microphone is not tested yet. Speak during the test and watch the level.") };
            privacy.Text = T("Windows обычно не показывает отдельный запрос для классической программы. В «Конфиденциальность → Микрофон» включите доступ к микрофону и разрешение классическим приложениям. Затем вернитесь и повторите проверку.", "Windows usually shows no separate prompt for a desktop app. In Privacy → Microphone, enable microphone access and allow desktop apps. Return here and repeat the test.");
            privacyButton.Text = T("Доступ к микрофону в Windows", "Windows microphone privacy"); soundButton.Text = T("Настройки звука", "Sound settings");
            instructions.Text = T("Глобальная запись: два быстрых нажатия левого Alt начинают запись; ещё два — останавливают. Правый Alt/AltGr и сочетания не запускают запись. Максимум 2 минуты. При запуске из другого приложения текст вводится только в исходное поле; иначе скопируйте его здесь. Закрытие окна оставляет MacDictate в трее; двойной щелчок по значку или повторный запуск открывают окно.", "Global dictation: tap left Alt twice quickly to start; tap twice again to stop. Right Alt/AltGr and chords do not record. Maximum 2 minutes. From another app, text is inserted only into the original input; otherwise copy it here. Closing this window leaves MacDictate in the tray; double-click its icon or launch again to reopen.");
            keyTest.Text = TestingHotkey ? T("Завершить проверку клавиши", "Finish hotkey test") : T("Проверить клавишу без записи", "Test hotkey without recording");
            if (!TestingHotkey) keyStatus.Text = !state.HotkeyReady ? T("Горячая клавиша недоступна: выберите F8 или Ctrl+Shift+Space. Кнопка записи работает отдельно.", "Hotkey unavailable: choose F8 or Ctrl+Shift+Space. The record button works separately.") : state.HotkeyVerified ? T("Горячая клавиша сработала.", "Hotkey activated.") : T("Клавиша зарегистрирована, ожидает проверки.", "Hotkey registered; test it here.");
            localFeedback.Render(state.Message); message.Text = localFeedback.Text; message.Visible = localFeedback.Visible;
            result.Text = state.LastText; copy.Text = T("Копировать текст", "Copy text"); copy.Enabled = result.Text.Length > 0;
            result.Parent!.Visible = result.Text.Length > 0;
            diagnostics.Text = T("Копировать диагностику без личных данных", "Copy private-safe diagnostics");
            record.Text = state.Activity == AppActivity.Recording ? T($"Остановить и распознать · {state.ElapsedSeconds} с", $"Stop and recognize · {state.ElapsedSeconds}s") : state.Activity == AppActivity.Processing ? T("Распознавание на компьютере…", "Recognizing on your computer…") : T("Начать запись", "Start recording");
            record.Enabled = state.Activity == AppActivity.Recording || idle && state.Readiness.CanRecord;
            cancel.Text = T("Отменить", "Cancel"); cancel.Enabled = !idle;
            foreach (Control control in new Control[] { download, browse, micTest, refreshMic, microphone, language, hotkey, keyTest }) control.Enabled = idle;
        }
        finally { updating = false; }
    }
    public void SetLevel(double value) => level.Value = Math.Clamp((int)(value * 100), 0, 100);
    public void ObserveHotkey(HotkeyObservation observation)
    {
        if (!TestingHotkey) return;
        keyStatus.Text = observation.Injected ? T("Программное нажатие проигнорировано.", "Injected key ignored.") : !observation.LeftAlt ? T("Правый Alt не запускает запись.", "Right Alt does not record.") : observation.Activated ? T("Двойной левый Alt сработал. Проверка завершена; теперь можно записывать.", "Double left Alt activated. Test passed; you can now record.") : T("Левый Alt получен: ", "Left Alt received: ") + (observation.Pressed ? T("нажат", "down") : T("отпущен", "up"));
    }
    internal void SetHotkeyTest(bool enabled) { TestingHotkey = enabled; Render(view); }
    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x219) RefreshMicrophones(true);
        base.WndProc(ref message);
    }
    public void ShowMain() { if (WindowState == FormWindowState.Minimized) WindowState = FormWindowState.Normal; Show(); Activate(); }
    protected override bool ShowWithoutActivation => showWithoutActivation;
    [System.Runtime.InteropServices.DllImport("user32.dll")] private static extern bool ShowWindow(nint window, int command);
    [System.Runtime.InteropServices.DllImport("user32.dll")] private static extern bool SetWindowPos(nint window, nint after, int x, int y, int width, int height, uint flags);
    public void ShowOutcome()
    {
        // Automatic completion/error recovery never takes focus from an external
        // editor. Explicit user Open/launch still uses ShowMain and Activate.
        showWithoutActivation = true;
        try { Show(); ShowWindow(Handle, 4); SetWindowPos(Handle, 0, 0, 0, 0, 0, 0x53); }
        finally { showWithoutActivation = false; }
    }
    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        var area = Screen.FromControl(this).WorkingArea;
        // At 150% a 680px design can exceed a 768px laptop display.
        MinimumSize = new Size(Math.Min(MinimumSize.Width, area.Width - 24), Math.Min(MinimumSize.Height, area.Height - 24));
        Size = new Size(Math.Min(Width, area.Width - 24), Math.Min(Height, area.Height - 24));
        Location = new Point(area.Left + (area.Width - Width) / 2, area.Top + (area.Height - Height) / 2);
    }
    public void CloseForExit() { allowClose = true; Close(); }
    internal string DiagnosticsText() => $"MacDictate Windows {Application.ProductVersion}\nOS: {Environment.OSVersion.Version}\nRuntime: {view.RuntimeReady}\nModel: {view.ModelReady}\nMicrophone: {view.Microphone}\nHotkey registered: {view.HotkeyReady}\nHotkey observed: {view.HotkeyVerified}\nActivity: {view.Activity}\nPhysical client acceptance: NOT_VERIFIED";
    internal void ShowLocalError(string text) { localFeedback.ShowError(text); Render(view); }
    private void ShowCopyFailure() => ShowLocalError(T("Не удалось скопировать. Выделите текст и нажмите Ctrl+C; повторите после закрытия другой программы, использующей буфер.", "Could not copy. Select the text and press Ctrl+C; retry after another clipboard app releases it."));
    private void ChooseModel()
    {
        using var picker = new OpenFileDialog { Filter = "Whisper ggml (*.bin)|*.bin", CheckFileExists = true };
        if (picker.ShowDialog(this) == DialogResult.OK) Save(view.Settings with { ModelPath = picker.FileName });
    }
    private void Open(string uri) { try { System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo(uri) { UseShellExecute = true }); } catch { ShowLocalError(T("Не удалось открыть настройки. Откройте их через меню «Пуск» Windows.", "Could not open settings. Open them from Windows Start.")); } }
}
