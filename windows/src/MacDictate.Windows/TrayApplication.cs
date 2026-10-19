using MacDictate.Core;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
internal sealed class TrayApplication : ApplicationContext
{
    private readonly Control dispatcher = new();
    private readonly NotifyIcon tray;
    private readonly KeyboardService keyboard;
    private readonly LocalStore store;
    private readonly System.Windows.Forms.Timer limit = new() { Interval = 120000 };
    private readonly ToolStripMenuItem action = new("Start recording"), cancel = new("Cancel"), status = new("Ready") { Enabled = false };
    private AppSettings settings;
    private WaveRecorder? recorder;
    private CancellationTokenSource? recognition;
    private FocusIdentity? target;
    private bool shuttingDown;
    private bool busy;
    private bool modal;
    private string lastText;
    public TrayApplication()
    {
        dispatcher.CreateControl();
        store = new LocalStore(Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "MacDictate"));
        settings = store.LoadSettings();
        lastText = store.LoadLastText();
        keyboard = new KeyboardService { IsRecording = () => recorder != null };
        keyboard.Activated += () => dispatcher.BeginInvoke(async () => await ToggleAsync());
        tray = new NotifyIcon { Icon = SystemIcons.Application, Text = "MacDictate — ready", Visible = true };
        var menu = new ContextMenuStrip();
        action.Click += async (_, _) => await ToggleAsync();
        cancel.Click += (_, _) => Cancel();
        menu.Items.AddRange([status, action, cancel, new ToolStripSeparator()]);
        menu.Items.Add("Settings / download model…", null, (_, _) => OpenSettings());
        menu.Items.Add("Show / copy last dictation…", null, (_, _) => ShowLast());
        menu.Items.Add("Clear saved dictation", null, (_, _) => { try { store.SaveLastText(""); lastText = ""; } catch (Exception error) { Error(error); } });
        menu.Items.Add("About / releases", null, (_, _) => System.Diagnostics.Process.Start(new System.Diagnostics.ProcessStartInfo("https://github.com/alexfisenkov/MacDictate/releases") { UseShellExecute = true }));
        menu.Items.Add(new ToolStripSeparator()); menu.Items.Add("Quit", null, (_, _) => ExitThread());
        tray.ContextMenuStrip = menu; tray.DoubleClick += (_, _) => OpenSettings();
        limit.Tick += async (_, _) => { limit.Stop(); await StopAsync(); };
        try { keyboard.Configure(settings.Hotkey); } catch (Exception error) { Error(error); }
        if (settings.ModelPath == null || !File.Exists(settings.ModelPath)) dispatcher.BeginInvoke(OpenSettings);
    }
    private async Task ToggleAsync()
    {
        if (shuttingDown || busy || modal) return;
        if (recorder != null) { await StopAsync(); return; }
        if (settings.ModelPath == null || !File.Exists(settings.ModelPath)) { OpenSettings(); return; }
        string path = Path.Combine(Path.GetTempPath(), "macdictate-audio-" + Guid.NewGuid().ToString("N") + ".wav");
        try
        {
            busy = true; target = await PasteService.CaptureTargetAsync();
            if (shuttingDown) return;
            recorder = new WaveRecorder(path); limit.Start();
            tray.Icon = SystemIcons.Warning; SetStatus("Recording — double Alt stops (max 2 min)"); action.Text = "Stop and recognize";
        }
        catch (Exception error) { DeleteAudio(path); Error(error); }
        finally { busy = false; if (shuttingDown) ExitThread(); }
    }
    private async Task StopAsync()
    {
        if (recorder == null || busy) return;
        limit.Stop(); var captured = recorder; recorder = null; busy = true;
        action.Enabled = false; tray.Icon = SystemIcons.Information; SetStatus("Recognizing locally…");
        using var cancellation = new CancellationTokenSource(); recognition = cancellation;
        try
        {
            if (target != null) await PasteService.DismissAltMenuAsync(target.Window);
            captured.Stop(); captured.Dispose();
            string text = await new WhisperRunner(Program.RuntimePath).TranscribeAsync(captured.AudioPath, settings.ModelPath!, settings.Language, cancellation.Token);
            lastText = text;
            bool saved = true;
            try { store.SaveLastText(text); } catch (Exception error) when (error is IOException or UnauthorizedAccessException) { saved = false; }
            if (!shuttingDown)
            {
                bool pasted = await PasteService.TryPasteAsync(text, target);
                SetStatus(pasted ? "Text sent; last dictation saved" : "Text ready — open last dictation to copy");
                if (!pasted) tray.ShowBalloonTip(5000, "MacDictate: text ready", "Focus changed, keys are held, or Windows blocked paste. Use Show / copy last dictation.", ToolTipIcon.Info);
                if (!saved) tray.ShowBalloonTip(5000, "MacDictate: text not saved to disk", "Last dictation remains available in this session. Copy it before quitting; check free disk space and local folder permissions.", ToolTipIcon.Warning);
            }
        }
        catch (OperationCanceledException) { if (!shuttingDown) SetStatus("Cancelled"); }
        catch (Exception error) { if (!shuttingDown) Error(error); }
        finally
        {
            CleanupRecorder(captured); recognition = null; busy = false;
            if (!shuttingDown) { tray.Icon = SystemIcons.Application; action.Text = "Start recording"; action.Enabled = true; }
            else ExitThread();
        }
    }
    private void Cancel()
    {
        limit.Stop(); recognition?.Cancel();
        if (recorder is { } active) { recorder = null; CleanupRecorder(active); action.Text = "Start recording"; tray.Icon = SystemIcons.Application; SetStatus("Cancelled"); }
    }
    private void OpenSettings()
    {
        if (modal || shuttingDown) return;
        if (busy || recorder != null) { tray.ShowBalloonTip(3000, "MacDictate", "Stop or cancel the current recording first.", ToolTipIcon.Info); return; }
        using var form = new SettingsForm(store, settings);
        modal = true;
        DialogResult result;
        try { result = form.ShowDialog(); } finally { modal = false; }
        if (result != DialogResult.OK) return;
        try { keyboard.Configure(form.Result.Hotkey); store.SaveSettings(form.Result); settings = form.Result; SetStatus("Ready"); }
        catch (Exception error) { try { keyboard.Configure(settings.Hotkey); } catch { } Error(error); }
    }
    private void ShowLast()
    {
        if (modal || shuttingDown) return;
        if (busy || recorder != null) { tray.ShowBalloonTip(3000, "MacDictate", "Wait for recognition, or stop or cancel the recording before opening last dictation.", ToolTipIcon.Info); return; }
        modal = true;
        try
        {
            using var form = new Form { Text = "Last dictation — saved on this computer", Width = 650, Height = 400, StartPosition = FormStartPosition.CenterScreen };
            var text = new TextBox { Multiline = true, ReadOnly = true, Dock = DockStyle.Fill, ScrollBars = ScrollBars.Vertical, Text = lastText };
            var copy = new Button { Text = "Copy text", Dock = DockStyle.Bottom, Height = 40 };
            copy.Click += (_, _) => { try { if (text.Text.Length > 0) Clipboard.SetText(text.Text); } catch (Exception error) { Error(error); } };
            form.Controls.Add(text); form.Controls.Add(copy); form.ShowDialog();
        }
        catch (Exception error) { Error(error); }
        finally { modal = false; }
    }
    private void Error(Exception error)
    {
        if (shuttingDown) return;
        bool previousModal = modal; modal = true;
        try { SetStatus("Needs attention"); MessageBox.Show(error.Message, "MacDictate", MessageBoxButtons.OK, MessageBoxIcon.Warning); }
        finally { modal = previousModal; }
    }
    private void SetStatus(string text) { status.Text = text; tray.Text = ("MacDictate — " + text)[..Math.Min(63, 13 + text.Length)]; }
    private static void DeleteAudio(string path) { try { File.Delete(path); } catch (IOException) { } }
    private void CleanupRecorder(WaveRecorder active)
    {
        try { active.Dispose(); }
        catch (Exception error) { Error(error); }
        finally { DeleteAudio(active.AudioPath); }
    }
    protected override void ExitThreadCore()
    {
        shuttingDown = true; Cancel();
        if (busy) return; // Keep the message loop alive until subprocess/temp cleanup completes.
        keyboard.Dispose(); limit.Dispose(); tray.Visible = false; tray.Dispose(); dispatcher.Dispose(); base.ExitThreadCore();
    }
}
