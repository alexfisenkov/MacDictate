using System.Net;
using System.Security.Cryptography;
using MacDictate.Core;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
// Only Program's explicit --onboarding-smoke branch constructs these fixtures.
// Normal launch has no environment switches or synthetic readiness path.
internal static class OnboardingSmoke
{
    public static int Run(string? reportPath, string? modelPath = null, string? fixtureWave = null)
    {
        string directory = Path.Combine(Path.GetTempPath(), "MacDictate-onboarding-test-" + Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(directory);
        var checks = new List<string>(); var screenshots = new List<string>();
        int result = 1;
        try
        {
            // Explicit smoke CLI only: a controlled layout stress, never a fake monitor DPI.
            string[] args = Environment.GetCommandLineArgs();
            int scaleIndex = Array.IndexOf(args, "--layout-scale");
            string? scaleValue = scaleIndex >= 0 && scaleIndex + 1 < args.Length ? args[scaleIndex + 1] : null;
            float layoutScale = scaleIndex < 0 ? 1 : scaleValue switch { "1.25" => 1.25f, "1.5" => 1.5f, _ => throw new ArgumentException("--layout-scale must be 1.25 or 1.5") };
            var store = new LocalStore(directory); store.SaveSettings(new(UiLanguage: "ru"));
            if ((modelPath == null) != (fixtureWave == null)) throw new ArgumentException("Both --model and --fixture-wave are required for real recognition acceptance.");
            if (modelPath != null && (!ModelFile.IsUsable(modelPath) || !File.Exists(fixtureWave) || !File.Exists(Program.RuntimePath))) throw new InvalidOperationException("Real recognition fixture, model, or bundled runtime is unavailable.");
            var fixtures = new SyntheticServices(directory, fixtureWave);
            var interaction = new SyntheticInteraction();
            byte[]? originalFixtureHash = fixtureWave == null ? null : SHA256.HashData(File.ReadAllBytes(fixtureWave));
            using var context = new TrayApplication(store, fixtures, interaction);
            context.Home.BeginInvoke(async () =>
            {
                try
                {
                    void Check(bool condition, string name) { if (!condition) throw new InvalidOperationException(name); checks.Add(name); }
                    T Control<T>(string name) where T : Control => context.Home.Controls.Find(name, true).OfType<T>().Single();
                    bool InViewport(Control control)
                    {
                        if (!control.Visible || control.Parent == null) return false;
                        Rectangle bounds = control.Parent.RectangleToScreen(control.Bounds);
                        for (Control? parent = control.Parent; parent != null; parent = parent.Parent)
                            if (!parent.Visible || !parent.RectangleToScreen(parent.ClientRectangle).Contains(bounds)) return false;
                        return true;
                    }
                    void CheckCurrentStatus(string scenario)
                    {
                        foreach (string name in new[] { "OperationStatus", "MicrophoneStatus" })
                            Check(InViewport(Control<Label>(name)), scenario + ": current " + name + " is in the visible window viewport");
                        if (context.View.Message.Length > 0)
                        {
                            var label = Control<Label>("OperationMessage");
                            Check(label.Text == context.View.Message && InViewport(label), scenario + ": actual current recovery/progress message reads back in the visible viewport");
                        }
                    }
                    async Task WaitForIdle()
                    {
                        var deadline = System.Diagnostics.Stopwatch.StartNew();
                        while (context.View.Activity != AppActivity.Idle)
                        {
                            if (deadline.Elapsed > TimeSpan.FromMinutes(6)) throw new TimeoutException("Recognition did not return to idle.");
                            await Task.Delay(30);
                        }
                    }
                    void Snapshot(string name)
                    {
                        if (reportPath == null) return;
                        string output = Path.GetFullPath(reportPath); string folder = Path.GetDirectoryName(output)!;
                        Directory.CreateDirectory(folder);
                        string file = Path.GetFileNameWithoutExtension(output) + "-" + name + ".png";
                        using var bitmap = new Bitmap(context.Home.Width, context.Home.Height);
                        context.Home.DrawToBitmap(bitmap, new Rectangle(Point.Empty, context.Home.Size));
                        bitmap.Save(Path.Combine(folder, file), System.Drawing.Imaging.ImageFormat.Png); screenshots.Add(file);
                    }
                    void CheckLayout(string language)
                    {
                        var action = Control<Button>("NextSetupAction");
                        var body = action.Parent as ScrollableControl ?? throw new InvalidOperationException("Setup action needs scrollable content.");
                        context.Home.PerformLayout();
                        foreach (var button in new[] { action, Control<Button>("StartStopRecording"), Control<Button>("CancelOperation") })
                        {
                            var parent = button.Parent!;
                            Check(button.Visible && parent.ClientRectangle.Contains(button.Bounds) && InViewport(button), $"{language} layout: {button.Name} fits its visible parent and window viewport");
                            Size preferred = button.GetPreferredSize(new Size(button.Width, 0));
                            Check(button.Width >= preferred.Width && button.Height >= preferred.Height, $"{language} layout: {button.Name} text fits at requested scale");
                        }
                        var footer = Control<Button>("StartStopRecording").Parent!;
                        Check(context.Home.ClientRectangle.Contains(footer.Bounds), $"{language} layout: record/cancel footer fits the main window");
                        foreach (var label in body.Controls.OfType<Label>().Where(label => label.Visible && label.Text.Length > 0))
                            Check(label.Height >= label.GetPreferredSize(new Size(label.Width, 0)).Height, $"{language} layout: body label wraps without vertical clipping");
                        foreach (var label in Control<Label>("OperationStatus").Parent!.Controls.OfType<Label>().Where(label => label.Visible && label.Text.Length > 0))
                            Check(label.Height >= label.GetPreferredSize(new Size(label.Width, 0)).Height, $"{language} layout: current status label wraps without vertical clipping");
                        CheckCurrentStatus(language);
                    }
                    void CheckResultVisible()
                    {
                        var text = Control<TextBox>("LastDictationText");
                        Check(InViewport(text) && InViewport(Control<Button>("CopyLastDictation")), "production result text and Copy are visible together without any test scrolling");
                    }
                    await Task.Delay(100);
                    int actualDesktopDpi = context.Home.DeviceDpi;
                    if (layoutScale != 1)
                    {
                        IEnumerable<Control> Descendants(Control parent) => parent.Controls.Cast<Control>().SelectMany(child => new[] { child }.Concat(Descendants(child)));
                        var fonts = new[] { context.Home }.Concat(Descendants(context.Home)).Select(control => (control, control.Font.FontFamily, control.Font.Size, control.Font.Style)).ToArray();
                        context.Home.Scale(new SizeF(layoutScale, layoutScale));
                        // Scale() changes geometry; explicitly stress inherited and heading fonts too.
                        foreach (var (control, family, size, style) in fonts) control.Font = new Font(family, size * layoutScale, style);
                        Rectangle area = Screen.FromControl(context.Home).WorkingArea;
                        context.Home.Size = new Size(Math.Min(context.Home.Width, area.Width), Math.Min(context.Home.Height, area.Height));
                        context.Home.PerformLayout();
                    }
                    CheckLayout("ru");
                    Check(context.Home.Visible && context.View.Readiness.Next == SetupStep.Model, "fresh launch visible with model as next action");
                    Check(context.KeyboardThreadId != Environment.CurrentManagedThreadId && context.View.HotkeyReady, "real native hook owns a separate pumping thread");
                    Snapshot("01-fresh-ru");
                    foreach (string failure in new[] { "network", "integrity" })
                    {
                        fixtures.DownloadFailure = failure; await context.DownloadAsync();
                        Check(!context.View.ModelReady && context.View.Activity == AppActivity.Idle && store.LoadSettings().ModelPath == null && Control<Button>("NextSetupAction").Enabled, "failed synthetic download blocks readiness and permits retry: " + failure);
                        Check(context.View.Message.Length > 0 && (failure != "integrity" || context.View.Message.Contains("SHA-256")), "download recovery text is populated: " + failure);
                        CheckCurrentStatus("download " + failure);
                        Snapshot("01-download-" + failure);
                    }
                    fixtures.DownloadFailure = null;
                    await context.DownloadAsync();
                    Check(context.View.ModelReady && store.LoadSettings().ModelPath == context.View.Settings.ModelPath, "verified synthetic download automatically persisted without Save");
                    Snapshot("02-model-saved");
                    foreach (var state in new[] { MicrophoneReadiness.NoDevice, MicrophoneReadiness.Silent, MicrophoneReadiness.Error, MicrophoneReadiness.Signal })
                    {
                        fixtures.Microphone = state; await context.TestMicrophoneAsync();
                        Check(context.View.Microphone == state && (state == MicrophoneReadiness.Signal || !context.View.Readiness.CanRecord), "synthetic microphone outcome: " + state);
                        CheckCurrentStatus("microphone " + state);
                        if (state == MicrophoneReadiness.NoDevice)
                        {
                            context.Home.RefreshMicrophones(true);
                            Check(context.View.Microphone == MicrophoneReadiness.NoDevice, "empty synthetic enumeration remains NoDevice after a refresh");
                        }
                        Snapshot("03-microphone-" + state);
                    }
                    fixtures.EnumerationFailure = true; context.Home.RefreshMicrophones(true);
                    Check(context.View.Microphone == MicrophoneReadiness.Error && !context.View.Readiness.CanRecord, "synthetic capabilities failure remains Error after refresh");
                    CheckCurrentStatus("enumeration failure"); fixtures.EnumerationFailure = false; await context.TestMicrophoneAsync();
                    context.Home.SetHotkeyTest(true);
                    context.Home.ObserveHotkey(new(true, false, false, true));
                    await context.ActivateHotkeyAsync();
                    Check(context.View.HotkeyVerified && context.View.Activity == AppActivity.Idle, "explicit test activation is visible and never starts audio");
                    Snapshot("04-hotkey-test"); context.Home.SetHotkeyTest(false);
                    interaction.HoldCapture(); int capturesBeforeCancel = fixtures.CaptureCount;
                    Task starting = context.ToggleAsync(true);
                    Check(context.View.Activity == AppActivity.Starting && Control<Button>("CancelOperation").Enabled, "synthetic pending target exposes cancellable Starting");
                    CheckCurrentStatus("starting"); Control<Button>("CancelOperation").PerformClick();
                    await starting.WaitAsync(TimeSpan.FromSeconds(2)); interaction.ReleaseCapture(); await Task.Delay(20);
                    Check(context.View.Activity == AppActivity.Idle && fixtures.CaptureCount == capturesBeforeCancel, "actual controller Cancel before target discovery completes never starts capture");
                    interaction.Reset();
                    if (modelPath != null) { context.UpdateSettings(context.View.Settings with { ModelPath = modelPath, Language = "en" }); fixtures.UseRealRecognition = true; }
                    Control<Button>("StartStopRecording").PerformClick();
                    Check(context.View.Activity == AppActivity.Recording, "Home record button starts synthetic capture"); Snapshot("05-recording");
                    CheckCurrentStatus("recording");
                    Control<Button>("StartStopRecording").PerformClick(); await Task.Delay(30);
                    Check(context.View.Activity == AppActivity.Processing, "processing and cancellation are visible"); Snapshot("06-processing");
                    CheckCurrentStatus("processing");
                    await WaitForIdle();
                    string expectedText = context.View.LastText;
                    Check(context.View.Activity == AppActivity.Idle && expectedText.Length > 0 && (modelPath != null || expectedText == SyntheticServices.TestText), "transcription appears in actual Home result surface");
                    Check(Control<TextBox>("LastDictationText").Text == expectedText, "visible result textbox reads back recognized text");
                    CheckResultVisible(); CheckCurrentStatus("recognized result");
                    Control<Button>("CopyLastDictation").PerformClick(); Check(Clipboard.GetText() == expectedText, "actual Copy button writes recognized text to clipboard");
                    if (modelPath != null) Check(expectedText.Contains("quick brown fox", StringComparison.OrdinalIgnoreCase), "real bundled Whisper recognizes expected synthetic fixture phrase");
                    fixtures.UseRealRecognition = false;
                    Check(store.LoadLastText() == expectedText && !File.Exists(fixtures.LastCapture), "last text persisted and captured temporary audio deleted");
                    Check(!context.Home.DiagnosticsText().Contains(expectedText) && !context.Home.DiagnosticsText().Contains(directory), "copy diagnostics excludes transcript and profile path");
                    bool resultVisibleBeforeTestScroll = InViewport(Control<TextBox>("LastDictationText")) && InViewport(Control<Button>("CopyLastDictation"));
                    Check(resultVisibleBeforeTestScroll, "resultVisibleBeforeTestScroll is a required production visibility assertion");
                    Snapshot("07-result-before-test-scroll");
                    Snapshot("07-result-ru");
                    context.UpdateSettings(context.View.Settings with { UiLanguage = "en" }); CheckLayout("en"); CheckResultVisible(); Snapshot("08-result-en");
                    await context.ToggleAsync(false); string? cancelledAudio = fixtures.LastCapture; context.Cancel();
                    Check(context.View.Activity == AppActivity.Idle && !File.Exists(cancelledAudio), "cancel recording deletes only synthetic captured audio");
                    await context.ToggleAsync(false); Task recognizing = context.StopAsync(); context.Cancel(); await recognizing;
                    Check(context.View.Activity == AppActivity.Idle && context.View.LastText == expectedText, "cancel recognition retains prior result and returns to idle");
                    fixtures.Transcript = "SYNTHETIC LATE ANSWER THAT MUST NOT BE PUBLISHED"; fixtures.AfterRecognition = context.Cancel;
                    await context.ToggleAsync(false); await context.StopAsync(); fixtures.AfterRecognition = null;
                    Check(context.View.LastText == expectedText && store.LoadLastText() == expectedText && Control<TextBox>("LastDictationText").Text == expectedText,
                        "actual controller cancellation immediately after ASR prevents late answer publication and persistence");
                    CheckCurrentStatus("cancelled after ASR"); CheckResultVisible();
                    // Real foreground read-back around synthetic focus/input timing.
                    // There is no real SendInput or UIA identity claim in this seam.
                    using (var external = new Form { Text = "Synthetic acceptance target", Width = 400, Height = 160 })
                    {
                        var input = new TextBox { Dock = DockStyle.Fill, Multiline = true }; external.Controls.Add(input);
                        external.Show(); external.Activate(); input.Focus(); await Task.Delay(80);
                        Check(NativeMethods.GetForegroundWindow() == external.Handle, "real foreground is the isolated synthetic external target before insertion timing tests");
                        fixtures.Transcript = string.Concat(Enumerable.Repeat("SYNTHETIC PASTE TIMING. ", 20));
                        foreach (int observation in new[] { 1, 2, 3 })
                        {
                            context.Home.Hide(); interaction.HoldPaste(observation);
                            await context.ToggleAsync(true); Task inserting = context.StopAsync();
                            await interaction.PasteHeld.Task.WaitAsync(TimeSpan.FromSeconds(3)); context.Cancel();
                            await inserting.WaitAsync(TimeSpan.FromSeconds(2)); interaction.ReleasePaste(); await Task.Delay(20);
                            Check(context.View.Activity == AppActivity.Idle && interaction.SentChunks == Math.Max(0, observation - 2), "actual controller Cancel reaches synthetic UIA/chunk boundary " + observation);
                            Check(NativeMethods.GetForegroundWindow() == external.Handle, "automatic recovery/result reveal preserves external foreground after cancel boundary " + observation);
                            Check(Control<TextBox>("LastDictationText").Text == fixtures.Transcript && store.LoadLastText() == fixtures.Transcript,
                                "cancelled insertion keeps the recognized text available for manual recovery " + observation);
                            CheckResultVisible(); CheckCurrentStatus("cancelled insertion " + observation);
                        }
                        expectedText = fixtures.Transcript; interaction.Reset(); external.Close();
                    }
                    context.ShowMain();
                    fixtures.ReturnEmptyText = true; await context.ToggleAsync(false); await context.StopAsync();
                    Check(context.View.LastText == expectedText && context.View.Activity == AppActivity.Idle, "empty recognition never replaces the last successful text");
                    CheckCurrentStatus("empty recognition error"); CheckResultVisible();
                    var validSettings = context.View.Settings;
                    context.UpdateSettings(validSettings with { ModelPath = Path.Combine(directory, "missing-test-model.bin") });
                    Check(context.View.Readiness.Next == SetupStep.Model && !context.View.Readiness.CanRecord, "missing model exposes actionable blocked state");
                    Snapshot("09-missing-model"); context.UpdateSettings(validSettings);
                    string runtime = fixtures.RuntimePath; File.Delete(runtime); context.ShowMain();
                    Check(context.View.Readiness.Next == SetupStep.Runtime && !context.View.Readiness.CanRecord, "missing runtime exposes actionable blocked state");
                    Snapshot("09-missing-runtime");
                    File.WriteAllText(runtime, "synthetic runtime marker"); context.ShowMain();
                    context.Home.Hide(); context.RequestShow(); await Task.Delay(80);
                    Check(context.Home.Visible, "activation request reopens an existing Home window");
                    var reloaded = store.LoadSettings();
                    Check(reloaded.UiLanguage == "en" && ModelFile.IsUsable(reloaded.ModelPath), "model and language survive settings read-back");
                    if (fixtureWave != null) Check(SHA256.HashData(File.ReadAllBytes(fixtureWave)).SequenceEqual(originalFixtureHash!), "caller fixture preserved byte-for-byte");
                    Check(SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Untested, true).Next == SetupStep.Microphone, "new session never inherits a green microphone");
                    int devices = 0; string enumeration = "not available";
                    try { devices = MicrophoneService.Enumerate().Count; enumeration = "real WinMM enumeration only"; } catch { enumeration = "real WinMM enumeration failed"; }
                    Program.WriteReport(new { success = true, scenario = "isolated-onboarding", checks, screenshots,
                        sources = new { microphone = fixtureWave == null ? "synthetic PCM seam; physical capture NOT_TESTED" : "synthetic fixture WAV copied to capture seam; physical capture NOT_TESTED", keyboard = "real dedicated hook installed; activation via explicit test seam; physical Alt NOT_TESTED", recognition = modelPath == null ? "synthetic transcript seam; real Whisper validated separately" : "real bundled Whisper" },
                        realWhisper = modelPath != null, syntheticMicrophone = true, syntheticHotkeyActivation = true, syntheticFocusAndInputTiming = true, realFixturePhraseMatched = modelPath != null,
                        resultVisibleBeforeTestScroll, resultScreenshotsUseTestScroll = false,
                        realDeviceProbe = new { enumeration, count = devices, capture = "NOT_RUN" }, physicalWindows10 = "NOT_TESTED", physicalWindows11 = "NOT_TESTED",
                        syntheticLayoutStress = layoutScale != 1, requestedLayoutScale = layoutScale, actualDesktopDpi,
                        dpi = "actual desktop DPI reported separately; synthetic control Scale is not native 125/150 percent monitor acceptance" }, reportPath);
                    result = 0;
                }
                catch (Exception error) { Program.WriteReport(new { success = false, scenario = "isolated-onboarding", failedCheck = error is InvalidOperationException ? error.Message : error.GetType().Name, checks, screenshots, physicalMicrophone = "NOT_TESTED", physicalAlt = "NOT_TESTED" }, reportPath); }
                finally { context.ExitThread(); }
            });
            Application.Run(context);
        }
        catch (Exception error) { Program.WriteReport(new { success = false, scenario = "isolated-onboarding", error = error.GetType().Name }, reportPath); }
        finally { Directory.Delete(directory, true); }
        return result;
    }
    private sealed class SyntheticServices : SessionServices
    {
        public const string TestText = "SYNTHETIC TEST TRANSCRIPT — not microphone speech.";
        private readonly string directory;
        private readonly string? fixtureWave;
        public override string RuntimePath => Path.Combine(directory, "synthetic-runtime-marker.exe");
        public MicrophoneReadiness Microphone { get; set; } = MicrophoneReadiness.Signal;
        public bool ReturnEmptyText { get; set; }
        public bool EnumerationFailure { get; set; }
        public string Transcript { get; set; } = TestText;
        public Action? AfterRecognition { get; set; }
        public int CaptureCount { get; private set; }
        public string? DownloadFailure { get; set; }
        public bool UseRealRecognition { get; set; }
        public string? LastCapture { get; private set; }
        public SyntheticServices(string directory, string? fixtureWave) { this.directory = directory; this.fixtureWave = fixtureWave; File.WriteAllText(RuntimePath, "synthetic runtime marker"); }
        public override IReadOnlyList<MicrophoneDevice> Microphones() => EnumerationFailure ? throw new IOException("SYNTHETIC_CAPABILITIES_FAILURE")
            : Microphone == MicrophoneReadiness.NoDevice ? [] : [new(0, "Synthetic test input (not a physical microphone)")];
        public override async Task<MicrophoneTestResult> TestMicrophoneAsync(uint device, IProgress<double> level, CancellationToken token)
        {
            token.ThrowIfCancellationRequested(); level.Report(Microphone == MicrophoneReadiness.Signal ? .3 : 0); await Task.Delay(40, token);
            return new(Microphone, "SYNTHETIC_" + Microphone);
        }
        public override IAudioCapture StartCapture(string path, uint device, IProgress<double> level) { CaptureCount++; LastCapture = path; return new SyntheticCapture(path, fixtureWave); }
        public override async Task<string> TranscribeAsync(string audio, AppSettings settings, CancellationToken token)
        {
            if (UseRealRecognition) return await new WhisperRunner(Program.RuntimePath).TranscribeAsync(audio, settings.ModelPath!, settings.Language, token);
            await Task.Delay(200, token); AfterRecognition?.Invoke(); return ReturnEmptyText ? "" : Transcript;
        }
        public override async Task<string> DownloadModelAsync(LocalStore store, IProgress<double> progress, CancellationToken token)
        {
            if (DownloadFailure == "network") throw new HttpRequestException("Synthetic offline fixture");
            byte[] content = new byte[2048]; System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(content, 0x67676d6c);
            using var http = new HttpClient(new FixtureHandler(content));
            string path = Path.Combine(store.DirectoryPath, "models", "synthetic-only.bin");
            string expectedHash = DownloadFailure == "integrity" ? new string('0', 64) : Convert.ToHexString(SHA256.HashData(content));
            await new ModelStore(http).DownloadAsync(new("synthetic-only.bin", "https://example.invalid/synthetic", expectedHash, content.Length), path, progress, token);
            return path;
        }
    }
    // Explicit CLI-only async timing seam. Production DictationInteraction never
    // constructs these synthetic identities or substitutes input delivery.
    private sealed class SyntheticInteraction : DictationInteraction
    {
        private readonly FocusIdentity identity = new(1, 1, 1, 1, "SYNTHETIC_TEST_IDENTITY");
        private TaskCompletionSource<FocusIdentity?>? capture, observation;
        private bool synthetic;
        private int heldObservation, observations;
        public int SentChunks { get; private set; }
        public TaskCompletionSource<bool> PasteHeld { get; private set; } = new();
        public void HoldCapture() { synthetic = true; capture = new(); }
        public void ReleaseCapture() { capture?.TrySetResult(identity); capture = null; }
        public void HoldPaste(int number) { synthetic = true; heldObservation = number; observations = 0; SentChunks = 0; observation = new(); PasteHeld = new(); }
        public void ReleasePaste() { observation?.TrySetResult(identity); observation = null; }
        public void Reset() { ReleaseCapture(); ReleasePaste(); synthetic = false; heldObservation = 0; }
        public override bool IsExternalTarget(nint home) => synthetic || base.IsExternalTarget(home);
        public override Task<FocusIdentity?> CaptureTargetAsync() => synthetic ? capture?.Task ?? Task.FromResult<FocusIdentity?>(identity) : base.CaptureTargetAsync();
        public override Task DismissAltMenuAsync(nint target, CancellationToken cancellation) => synthetic ? Task.CompletedTask : base.DismissAltMenuAsync(target, cancellation);
        public override Task<bool> TryPasteAsync(string text, FocusIdentity? target, CancellationToken cancellation)
        {
            if (!synthetic) return base.TryPasteAsync(text, target, cancellation);
            Task<FocusIdentity?> Observe()
            {
                if (++observations != heldObservation) return Task.FromResult<FocusIdentity?>(identity);
                PasteHeld.TrySetResult(true); return observation!.Task;
            }
            return TextInsertion.TryAsync(text, target, Observe, _ => true, _ => { SentChunks++; return true; }, cancellation);
        }
    }
    private sealed class SyntheticCapture : IAudioCapture
    {
        private readonly PcmSignalMeter meter = new();
        public string AudioPath { get; }
        public bool HasSignal => meter.HasSignal;
        public SyntheticCapture(string path, string? fixtureWave)
        {
            AudioPath = path;
            if (fixtureWave != null)
            {
                // Never mutate or delete the caller's fixture; cleanup owns only this copy.
                File.Copy(fixtureWave, path, false);
                using var file = File.OpenRead(path); using var reader = new BinaryReader(file);
                if (reader.ReadUInt32() != 0x46464952) throw new InvalidDataException("Fixture must be RIFF WAV.");
                reader.ReadUInt32(); if (reader.ReadUInt32() != 0x45564157) throw new InvalidDataException("Fixture must be WAV.");
                bool format = false;
                while (file.Position + 8 <= file.Length)
                {
                    uint chunk = reader.ReadUInt32(), size = reader.ReadUInt32(); long next = file.Position + size + (size & 1);
                    if (next > file.Length) throw new InvalidDataException("Truncated WAV fixture.");
                    if (chunk == 0x20746d66 && size >= 16)
                    {
                        ushort encoding = reader.ReadUInt16(), channels = reader.ReadUInt16(); uint rate = reader.ReadUInt32(); reader.ReadUInt32(); reader.ReadUInt16(); ushort bits = reader.ReadUInt16();
                        format = encoding == 1 && channels == 1 && rate == 16000 && bits == 16;
                    }
                    if (chunk == 0x61746164)
                    {
                        if (!format || size > 120 * 32000) throw new InvalidDataException("Fixture must be <=120 seconds of mono PCM16 16kHz.");
                        meter.Append(reader.ReadBytes((int)size)); break;
                    }
                    file.Position = next;
                }
            }
            else { byte[] pcm = new byte[32000]; for (int i = 1; i < pcm.Length; i += 2) pcm[i] = 12; meter.Append(pcm); File.WriteAllBytes(path, pcm); }
        }
        public void Stop() { }
        public void Dispose() { }
    }
    private sealed class FixtureHandler(byte[] bytes) : HttpMessageHandler
    {
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken) => Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) });
    }
}
