using MacDictate.Core;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
internal sealed class TrayApplication : ApplicationContext
{
    private readonly NotifyIcon tray;
    private readonly KeyboardService keyboard;
    private readonly LocalStore store;
    private readonly SessionServices services;
    private readonly DictationInteraction interaction;
    private readonly MainForm home;
    private readonly RecordingOverlay overlay = new();
    private readonly System.Windows.Forms.Timer clock = new() { Interval = 250 };
    private readonly ToolStripMenuItem action = new(), status = new() { Enabled = false };
    private IAudioCapture? recorder;
    private CancellationTokenSource? operation;
    private FocusIdentity? target;
    private ViewState view;
    private DateTime started;
    private bool shuttingDown, exiting, trayExplanationShown;
    internal MainForm Home => home;
    internal ViewState View => view;
    public TrayApplication() : this(new LocalStore(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MacDictate")), new SessionServices()) { }
    internal TrayApplication(LocalStore store, SessionServices services, DictationInteraction? interaction = null)
    {
        this.store = store; this.services = services; this.interaction = interaction ?? new DictationInteraction();
        var settings = store.LoadSettings();
        view = new(settings, File.Exists(services.RuntimePath), ModelFile.IsUsable(settings.ModelPath), MicrophoneReadiness.Untested, false, false, AppActivity.Idle, "", store.LoadLastText());
        home = new(view, services.Microphones); home.CreateControl(); _ = home.Handle;
        home.SettingsChanged += UpdateSettings;
        home.DownloadRequested += async () => await DownloadAsync();
        home.MicrophoneTestRequested += async () => await TestMicrophoneAsync();
        home.RecordRequested += async () => await ToggleAsync(false);
        home.CancelRequested += Cancel;
        home.MicrophoneRefreshed += selection =>
        {
            if (view.Activity != AppActivity.Idle) return;
            try
            {
                var updated = view.Settings with { MicrophoneDeviceId = selection.DeviceId };
                bool changed = updated != view.Settings;
                if (changed) store.SaveSettings(updated);
                view = view with { Settings = updated, Microphone = selection.Readiness };
                if (changed) view = view with { Message = T("Выбранный вход отключён. Доступный вход выбран и сохранён; проверьте микрофон заново.", "The selected input disconnected. An available input was selected and saved; test the microphone again.") };
            }
            catch { view = view with { Microphone = MicrophoneReadiness.Error, Message = T("Не удалось сохранить вход. Проверьте права на локальные настройки и повторите.", "Cannot save the input. Check local settings permissions and retry.") }; }
            Render();
        };
        home.InputConfigurationChanged += () => { if (view.Activity == AppActivity.Idle) ReconcileMicrophone(true); };
        home.HiddenToTray += () =>
        {
            if (trayExplanationShown) return; trayExplanationShown = true;
            tray?.ShowBalloonTip(5000, "MacDictate", T("Программа работает в трее. Двойной щелчок по значку или повторный запуск откроет окно.", "MacDictate is running in the tray. Double-click the icon or launch again to reopen."), ToolTipIcon.Info);
        };
        keyboard = new KeyboardService();
        keyboard.Activated += () => Dispatch(async () => await ActivateHotkeyAsync());
        keyboard.Observed += observation => Dispatch(() => { home.ObserveHotkey(observation); });
        tray = new NotifyIcon { Icon = SystemIcons.Application, Text = "MacDictate", Visible = true };
        var menu = new ContextMenuStrip();
        menu.Items.Add("MacDictate…", null, (_, _) => ShowMain());
        action.Click += async (_, _) => await ToggleAsync(false);
        menu.Items.AddRange([status, action]);
        menu.Items.Add(T("Отменить", "Cancel"), null, (_, _) => Cancel());
        menu.Items.Add(T("Показать / копировать текст…", "Show / copy text…"), null, (_, _) => ShowMain());
        menu.Items.Add(T("Очистить сохранённый текст", "Clear saved text"), null, (_, _) => { try { store.SaveLastText(""); view = view with { LastText = "" }; Render(); } catch { Fail(T("Не удалось очистить текст. Проверьте права на локальную папку.", "Cannot clear saved text. Check local folder permissions.")); } });
        menu.Items.Add(T("Выход", "Quit"), null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu; tray.DoubleClick += (_, _) => ShowMain();
        clock.Tick += async (_, _) => { if (view.Activity != AppActivity.Recording) return; view = view with { ElapsedSeconds = (int)(DateTime.UtcNow - started).TotalSeconds }; Render(); if (view.ElapsedSeconds >= 120) await StopAsync(); };
        ConfigureKeyboard(); ReconcileMicrophone(); Render(); home.Show();
    }
    private string T(string ru, string en) => home.T(ru, en);
    private void Dispatch(Action callback)
    {
        if (exiting || home.IsDisposed) return;
        try { home.BeginInvoke(() => { if (!exiting) callback(); }); }
        catch (InvalidOperationException) { /* The UI can finish disposal between the check and post. */ }
    }
    internal void RequestShow() => Dispatch(ShowMain);
    internal int KeyboardThreadId => keyboard.MessageLoopThreadId;
    internal async Task ActivateHotkeyAsync()
    {
        view = view with { HotkeyVerified = true }; Render();
        if (!home.TestingHotkey) await ToggleAsync(true);
    }
    internal void ShowMain() { if (!shuttingDown) { RefreshFiles(); home.ShowMain(); Render(); } }
    private void RefreshFiles() => view = view with { RuntimeReady = File.Exists(services.RuntimePath), ModelReady = ModelFile.IsUsable(view.Settings.ModelPath) };
    private bool ReconcileMicrophone(bool invalidateSignal = false) => home.RefreshMicrophones(invalidateSignal);
    private void ConfigureKeyboard()
    {
        try { keyboard.Configure(view.Settings.Hotkey); view = view with { HotkeyReady = true, HotkeyVerified = false }; }
        catch { view = view with { HotkeyReady = false, HotkeyVerified = false, Message = T("Не удалось включить клавишу. Выберите F8 или Ctrl+Shift+Space; можно записывать кнопкой.", "Cannot enable hotkey. Choose F8 or Ctrl+Shift+Space; you can use the record button.") }; }
    }
    internal void UpdateSettings(AppSettings settings)
    {
        if (view.Activity != AppActivity.Idle) return;
        try
        {
            store.SaveSettings(settings);
            bool changedKey = settings.Hotkey != view.Settings.Hotkey, changedInput = settings.MicrophoneDeviceId != view.Settings.MicrophoneDeviceId;
            view = view with { Settings = settings, Microphone = changedInput ? MicrophoneReadiness.Untested : view.Microphone, Message = "" };
            RefreshFiles(); if (changedKey) ConfigureKeyboard(); Render();
        }
        catch { Fail(T("Настройки не сохранены. Проверьте свободное место и права на локальную папку; повторите выбор.", "Settings were not saved. Check free disk space and local folder permissions, then repeat the selection.")); }
    }
    internal async Task DownloadAsync()
    {
        if (view.Activity != AppActivity.Idle) return;
        using var cancellation = new CancellationTokenSource(); operation = cancellation;
        view = view with { Activity = AppActivity.Downloading, Message = T("Загрузка проверенной модели с Hugging Face. Ваши записи остаются на компьютере.", "Downloading the verified model from Hugging Face. Your recordings stay on this computer."), DownloadPercent = 0 }; Render();
        try
        {
            string path = await services.DownloadModelAsync(store, new Progress<double>(value => { if (view.Activity == AppActivity.Downloading) { view = view with { DownloadPercent = Math.Clamp((int)(100 * value), 0, 100) }; Render(); } }), cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            var settings = view.Settings with { ModelPath = path };
            store.SaveSettings(settings); view = view with { Settings = settings, Message = T("Модель проверена и сохранена автоматически. Следующий шаг — микрофон.", "Verified model saved automatically. Next, test the microphone.") }; RefreshFiles();
        }
        catch (OperationCanceledException) { SetMessage(T("Загрузка отменена. Существующая модель сохранена. Можно повторить.", "Download cancelled. Existing model preserved. You can retry.")); }
        catch (Exception error) when (ModelDownloadRecovery.Classify(error) == ModelDownloadFailure.Integrity)
        {
            SetMessage(T("Проверка целостности модели не пройдена: SHA-256 или размер не совпадают, либо по пути уже есть другая модель. Существующие файлы сохранены. Повторите скачивание или нажмите «Выбрать .bin» и укажите существующую модель Whisper.", "Model integrity verification failed: SHA-256 or size does not match, or a different model already exists at the destination. Existing files were preserved. Retry the download or select Choose .bin to use an existing Whisper model."));
        }
        catch { SetMessage(T("Загрузка или сохранение не завершены. Проверьте сеть, место и права; повторите или выберите существующую .bin. Файл другой модели не заменяется.", "Download or save did not complete. Check network, space and permissions; retry or choose an existing .bin. A different existing model is never overwritten.")); }
        finally { operation = null; view = view with { Activity = AppActivity.Idle }; Render(); FinishExit(); }
    }
    internal async Task TestMicrophoneAsync()
    {
        if (view.Activity != AppActivity.Idle) return;
        if (!ReconcileMicrophone()) { Render(); return; }
        using var cancellation = new CancellationTokenSource(); operation = cancellation;
        view = view with { Microphone = MicrophoneReadiness.Untested, Activity = AppActivity.TestingMicrophone, Message = T("Говорите сейчас — 3 секунды. Тестовая запись будет удалена.", "Speak now for 3 seconds. The test recording will be deleted.") }; Render();
        try
        {
            var outcome = await services.TestMicrophoneAsync(view.Settings.MicrophoneDeviceId, new Progress<double>(home.SetLevel), cancellation.Token);
            view = view with { Microphone = outcome.State, Message = "" };
        }
        catch (OperationCanceledException) { SetMessage(T("Проверка отменена. Можно повторить.", "Microphone test cancelled. You can retry.")); }
        catch { view = view with { Microphone = MicrophoneReadiness.Error }; SetMessage(T("Ошибка проверки. Откройте доступ к микрофону и повторите.", "Microphone test failed. Open microphone privacy settings and retry.")); }
        finally { operation = null; home.SetLevel(0); view = view with { Activity = AppActivity.Idle }; Render(); FinishExit(); }
    }
    internal async Task ToggleAsync(bool global)
    {
        if (shuttingDown) return;
        if (view.Activity == AppActivity.Recording) { await StopAsync(); return; }
        if (view.Activity != AppActivity.Idle) return;
        RefreshFiles();
        if (!ReconcileMicrophone()) { home.ShowOutcome(); return; }
        if (!view.Readiness.CanRecord) { SetMessage(T("Сначала выполните выделенный шаг настройки.", "Complete the indicated setup step first.")); home.ShowOutcome(); return; }
        string path = Path.Combine(Path.GetTempPath(), "macdictate-audio-" + Guid.NewGuid().ToString("N") + ".wav");
        using var cancellation = new CancellationTokenSource(); operation = cancellation;
        view = view with { Activity = AppActivity.Starting, Message = "" }; Render();
        try
        {
            // Never capture our own UI as an insertion target, even for a global key.
            bool external = global && interaction.IsExternalTarget(home.Handle);
            recorder = await OperationBoundary.CompleteAfterAsync(
                () => external ? interaction.CaptureTargetAsync() : Task.FromResult<FocusIdentity?>(null),
                identity => { target = identity; return services.StartCapture(path, view.Settings.MicrophoneDeviceId, new Progress<double>(home.SetLevel)); }, cancellation.Token);
            started = DateTime.UtcNow; view = view with { Activity = AppActivity.Recording, ElapsedSeconds = 0, Message = T("Говорите. Для остановки нажмите кнопку или дважды левый Alt.", "Speak now. Stop with the button or by tapping left Alt twice.") }; clock.Start();
        }
        catch (OperationCanceledException) { DeleteAudio(path); target = null; SetMessage(T("Подготовка записи отменена. Микрофон не запущен.", "Recording preparation cancelled. The microphone was not started.")); }
        catch { DeleteAudio(path); view = view with { Microphone = MicrophoneReadiness.Error, Activity = AppActivity.Idle }; SetMessage(T("Запись не началась. Проверьте вход и доступ к микрофону Windows, затем повторите тест.", "Recording did not start. Check input and Windows microphone access, then retry the test.")); home.ShowOutcome(); }
        finally { operation = null; if (recorder == null) view = view with { Activity = AppActivity.Idle }; Render(); FinishExit(); }
    }
    internal async Task StopAsync()
    {
        if (recorder == null || view.Activity != AppActivity.Recording) return;
        clock.Stop(); var captured = recorder; recorder = null;
        view = view with { Activity = AppActivity.Processing, Message = T("Распознавание локально на CPU. Это может занять время. Можно отменить.", "Recognizing locally on CPU. This may take time. You can cancel.") }; Render();
        using var cancellation = new CancellationTokenSource(); operation = cancellation;
        try
        {
            if (target != null) await interaction.DismissAltMenuAsync(target.Window, cancellation.Token);
            cancellation.Token.ThrowIfCancellationRequested();
            try { captured.Stop(); }
            catch { view = view with { Microphone = MicrophoneReadiness.Error }; throw; }
            if (!captured.HasSignal) { view = view with { Microphone = MicrophoneReadiness.Silent }; throw new InvalidDataException("NO_SIGNAL"); }
            try { captured.Dispose(); }
            catch { view = view with { Microphone = MicrophoneReadiness.Error }; throw; }
            view = view with { Microphone = MicrophoneReadiness.Signal };
            bool saved = true;
            string text = await OperationBoundary.CompleteAfterAsync(() => services.TranscribeAsync(captured.AudioPath, view.Settings, cancellation.Token), recognized =>
            {
                if (string.IsNullOrWhiteSpace(recognized)) throw new InvalidDataException("NO_TEXT");
                view = view with { LastText = recognized };
                try { store.SaveLastText(recognized); } catch { saved = false; }
                return recognized;
            }, cancellation.Token, waitForCleanup: true);
            cancellation.Token.ThrowIfCancellationRequested();
            bool pasted = !shuttingDown && target != null && await interaction.TryPasteAsync(text, target, cancellation.Token);
            SetMessage(!saved ? T("Текст готов, но не сохранён на диск. Скопируйте перед выходом; проверьте место и права.", "Text ready, but not saved to disk. Copy before quitting; check space and permissions.") : pasted ? T("Текст введён в исходное поле и сохранён локально.", "Text inserted into the original input and saved locally.") : T("Текст готов ниже. Нажмите «Копировать». Если поле или фокус изменились, автоматический ввод безопасно пропускается.", "Text is ready below. Select Copy. If focus or input changed, automatic insertion is safely skipped."));
            if (!pasted && !shuttingDown) home.ShowOutcome();
        }
        catch (OperationCanceledException) { SetMessage(T("Обработка или ввод отменены. Доступный текст можно скопировать; можно записать снова.", "Processing or insertion cancelled. Any available text can be copied; you can record again.")); if (!shuttingDown) home.ShowOutcome(); }
        catch { SetMessage(view.Microphone == MicrophoneReadiness.Silent ? T("Достаточного сигнала нет. Проверьте mute и вход, говорите во время теста, затем повторите.", "Insufficient signal. Check mute and input, speak during the test, then retry.") : view.Microphone == MicrophoneReadiness.Error ? T("Ошибка записи или освобождения микрофона. Проверьте доступ и вход, перезапустите программу и повторите тест микрофона.", "Microphone capture or cleanup failed. Check access and input, restart the app and retry the microphone test.") : T("Распознавание не завершено. Проверьте модель и runtime; при пустом тексте повторите запись с речью. Можно выбрать другую модель или переустановить приложение.", "Recognition did not complete. Check model and runtime; if no text was recognized, record speech again. Choose another model or reinstall the app.")); if (!shuttingDown) home.ShowOutcome(); }
        finally { Cleanup(captured); target = null; operation = null; home.SetLevel(0); view = view with { Activity = AppActivity.Idle }; Render(); FinishExit(); }
    }
    internal void Cancel()
    {
        clock.Stop(); operation?.Cancel();
        if (recorder is { } active) { recorder = null; Cleanup(active); target = null; view = view with { Activity = AppActivity.Idle }; SetMessage(T("Запись отменена. Аудио удалено.", "Recording cancelled. Audio deleted.")); }
    }
    private void SetMessage(string message) { view = view with { Message = message }; Render(); }
    private void Fail(string message) => SetMessage(message);
    private void Render()
    {
        if (exiting) return;
        home.Render(view); status.Text = view.Activity.ToString(); action.Text = view.Activity == AppActivity.Recording ? T("Остановить и распознать", "Stop and recognize") : T("Начать запись", "Start recording");
        action.Enabled = view.Activity == AppActivity.Recording || view.Activity == AppActivity.Idle;
        tray.Icon = view.Activity == AppActivity.Recording ? SystemIcons.Warning : SystemIcons.Application;
        tray.Text = "MacDictate — " + view.Activity;
        if (view.Activity is AppActivity.Recording or AppActivity.Processing) overlay.UpdateStatus(view.Activity == AppActivity.Recording ? T($"● Запись {view.ElapsedSeconds} с · двойной Alt: стоп", $"● Recording {view.ElapsedSeconds}s · double Alt: stop") : T("Распознавание локально…", "Recognizing locally…")); else overlay.Hide();
    }
    private static void DeleteAudio(string path) { try { File.Delete(path); } catch (Exception error) when (error is IOException or UnauthorizedAccessException) { } }
    private void Cleanup(IAudioCapture active) { try { active.Dispose(); } catch { SetMessage(T("Микрофон не освободился корректно. Перезапустите MacDictate перед новой записью.", "Microphone cleanup failed. Restart MacDictate before recording again.")); } finally { DeleteAudio(active.AudioPath); } }
    private void FinishExit() { if (shuttingDown && view.Activity == AppActivity.Idle) ExitThread(); }
    protected override void ExitThreadCore()
    {
        if (exiting) return; shuttingDown = true; Cancel();
        if (view.Activity != AppActivity.Idle) return;
        exiting = true; keyboard.Dispose(); clock.Dispose(); overlay.Dispose(); tray.Visible = false; tray.Dispose(); home.CloseForExit(); home.Dispose(); base.ExitThreadCore();
    }
}

// Only the explicit onboarding CLI injects an alternative interaction. Production
// always uses native focus identity and fail-closed input delivery below.
internal class DictationInteraction
{
    public virtual bool IsExternalTarget(nint home) => NativeMethods.GetForegroundWindow() != home;
    public virtual Task<FocusIdentity?> CaptureTargetAsync() => PasteService.CaptureTargetAsync();
    public virtual Task DismissAltMenuAsync(nint target, CancellationToken cancellation) => PasteService.DismissAltMenuAsync(target, cancellation);
    public virtual Task<bool> TryPasteAsync(string text, FocusIdentity? identity, CancellationToken cancellation) => PasteService.TryPasteAsync(text, identity, cancellation);
}
