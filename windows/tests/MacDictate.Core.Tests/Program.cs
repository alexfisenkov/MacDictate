using System.Net;
using System.Security.Cryptography;
using System.Text;
using MacDictate.Core;

// The Windows test apphost doubles as a deterministic subprocess fixture.
if (args.Contains("-of"))
{
    string mode = File.ReadAllText(args[Array.IndexOf(args, "-m") + 1]);
    if (mode == "fail") return 7;
    if (mode == "timeout") { await Task.Delay(20000); return 8; }
    string prefix = args[Array.IndexOf(args, "-of") + 1];
    await File.WriteAllTextAsync(prefix + ".txt", mode == "empty" ? "  " : "Привет\nfixture");
    if (mode == "flood") for (int i = 0; i < 10000; i++) { Console.Error.WriteLine(new string('e', 200)); Console.WriteLine(new string('o', 200)); }
    return 0;
}

int checks = 0;
void Check(bool value, string message) { checks++; if (!value) throw new Exception(message); }
async Task Throws<T>(Func<Task> run) where T : Exception
{
    try { await run(); } catch (T) { checks++; return; }
    throw new Exception($"Expected {typeof(T).Name}");
}
HotkeyPolicy policy = new();
bool Key(int key, bool down, long time, bool recording = false, bool injected = false) => policy.Process(key, down, injected, time, recording);
Check(!Key(0xA4, true, 0) && !Key(0xA4, false, 50), "Single Alt starts recording");
Check(!Key(0xA4, true, 100) && Key(0xA4, false, 150), "Double left Alt must start");
Check(!Key(0xA4, true, 200, true) && !Key(0xA4, false, 250, true), "One Alt must not stop");
Check(!Key(0xA4, true, 300, true) && Key(0xA4, false, 350, true), "Double Alt stops");
policy.Reset(); Key(0xA4, true, 0); Key(0x09, true, 20); Key(0x09, false, 30); Check(!Key(0xA4, false, 40), "Alt+Tab must not start");
Key(0xA4, true, 50); Check(!Key(0xA4, false, 70), "Combo must reset double tap");
policy.Reset(); Key(0x11, true, 0); Key(0xA5, true, 5); Key(0xA5, false, 20); Key(0x11, false, 25); Key(0xA5, true, 40); Check(!Key(0xA5, false, 60), "AltGr/right Alt must never trigger");
policy.Reset(); Key(0xA4, true, 0); Key(0xA4, true, 20); Check(!Key(0xA4, false, 40), "Repeat must disqualify tap");
policy.Reset(); Key(0xA4, true, 0, injected: true); Key(0xA4, false, 20, injected: true); Key(0xA4, true, 30); Check(!Key(0xA4, false, 40), "Injected events must not seed double tap");
policy.Reset(); Key(0xA4, true, 0); Key(0xA4, false, 20); Key(0xA4, true, 500); Check(!Key(0xA4, false, 520), "Distant taps must not trigger");
policy.Reset(); Key(0xA4, true, 0); Check(!Key(0xA4, false, 500), "Held Alt must not count as a tap"); Key(0xA4, true, 550); Check(!Key(0xA4, false, 600), "Held Alt must not seed double tap");
string directory = Path.Combine(Path.GetTempPath(), "MacDictate tests space Привет " + Guid.NewGuid().ToString("N"));
Directory.CreateDirectory(directory);
try
{
    var store = new LocalStore(directory); Check(store.LoadSettings() == new AppSettings(), "Missing settings fallback");
    var settings = new AppSettings("ru", "F8", Path.Combine(directory, "model space.bin")); store.SaveSettings(settings); Check(store.LoadSettings() == settings, "Settings roundtrip");
    File.WriteAllText(Path.Combine(directory, "settings.json"), "{\"Language\":\"ru\",\"Hotkey\":\"F8\",\"ModelPath\":\"old.bin\"}");
    Check(store.LoadSettings().MicrophoneDeviceId == uint.MaxValue && store.LoadSettings().UiLanguage == "", "Legacy settings must preserve values and default new setup fields");
    Check(SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Untested, true).Next == SetupStep.Microphone, "Model and hook alone must not declare microphone ready");
    Check(SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Untested, true).CanRecord, "Untested microphone permits explicit real trial without claiming verified readiness");
    Check(!SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Silent, true).CanRecord, "Silence must block trial readiness");
    Check(SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Signal, false).CanRecord && SetupReadiness.Evaluate(true, true, MicrophoneReadiness.Signal, false).Next == SetupStep.Hotkey, "Record button remains usable when hotkey registration fails");
    Check(SetupReadiness.Evaluate(false, true, MicrophoneReadiness.Signal, true).Next == SetupStep.Runtime && !SetupReadiness.Evaluate(true, false, MicrophoneReadiness.Signal, true).CanRecord, "Missing runtime or model must block recording");
    var disconnected = MicrophoneSelection.Reconcile(7, new uint[] { 0, 2 }, MicrophoneReadiness.Signal);
    Check(disconnected.DeviceId == 0 && disconnected.Readiness == MicrophoneReadiness.Untested, "Disconnected saved input must choose an available input and invalidate its prior signal");
    store.SaveSettings(store.LoadSettings() with { MicrophoneDeviceId = disconnected.DeviceId });
    Check(store.LoadSettings().MicrophoneDeviceId == 0, "Replacement input selection must survive settings read-back");
    Check(MicrophoneSelection.Reconcile(0, new uint[] { 0, 2 }, MicrophoneReadiness.Signal).Readiness == MicrophoneReadiness.Signal, "Unchanged available input retains session signal");
    Check(MicrophoneSelection.Reconcile(uint.MaxValue, new uint[] { 0 }, MicrophoneReadiness.Signal).DeviceId == uint.MaxValue, "Available system-default input selection must remain stable");
    var noDevices = MicrophoneSelection.Reconcile(7, Array.Empty<uint>(), MicrophoneReadiness.Signal);
    Check(noDevices.DeviceId == uint.MaxValue && noDevices.Readiness == MicrophoneReadiness.NoDevice, "No devices clears stale ID and never keeps green readiness");
    Check(MicrophoneSelection.Reconcile(noDevices.DeviceId, new uint[] { 0 }, noDevices.Readiness).Readiness == MicrophoneReadiness.Untested, "Reconnected input becomes testable without inheriting prior signal");
    Check(MicrophoneSelection.Invalidate(noDevices.Readiness) == MicrophoneReadiness.NoDevice &&
        MicrophoneSelection.Invalidate(MicrophoneReadiness.Error) == MicrophoneReadiness.Error,
        "Refreshing input configuration must preserve actual NoDevice and enumeration Error statuses");
    Check(MicrophoneEnumeration.Read<string>(0, _ => throw new Exception("No capabilities call expected")).Count == 0, "Zero physical inputs remains distinct from capability failure");
    await Throws<IOException>(() => Task.FromResult(MicrophoneEnumeration.Read(1, _ => (5u, "unavailable input"))));
    // Deterministic async startup seam: cancellation arrives during target/UIA
    // discovery, before the actual microphone capture is allowed to start.
    using (var cancelStart = new CancellationTokenSource())
    {
        var pendingTarget = new TaskCompletionSource<string?>(); int starts = 0;
        Task<int> starting = OperationBoundary.CompleteAfterAsync(() => pendingTarget.Task, _ => ++starts, cancelStart.Token);
        cancelStart.Cancel(); pendingTarget.SetResult("synthetic external target");
        bool cancelledStart = false;
        try { await starting; } catch (OperationCanceledException) { cancelledStart = true; }
        using var cancelPublish = new CancellationTokenSource(); int publications = 0; bool cancelledPublication = false;
        try
        {
            await OperationBoundary.CompleteAfterAsync(() => { cancelPublish.Cancel(); return Task.FromResult("late ASR answer"); },
                _ => ++publications, cancelPublish.Token, waitForCleanup: true);
        }
        catch (OperationCanceledException) { cancelledPublication = true; }
        Check(cancelledStart && starts == 0 && cancelledPublication && publications == 0,
            "Cancel during async target discovery or immediately after ASR must prevent capture/publication");
    }
    // Synthetic UIA observations/sends exercise the production insertion policy.
    // No Win32 input, clipboard, or real target app is used by this portable test.
    bool allInsertionCancellationsBlocked = true;
    foreach (int cancelObservation in new[] { 1, 2, 3 })
    {
        using var cancelPaste = new CancellationTokenSource(); int observations = 0, chunksSent = 0; bool cancelledPaste = false;
        var pendingObservation = new TaskCompletionSource<string?>();
        Task<string?> Observe()
        {
            observations++;
            return observations == cancelObservation ? pendingObservation.Task : Task.FromResult<string?>("target");
        }
        Task<bool> inserting = TextInsertion.TryAsync(new string('x', 300), "target", Observe, _ => true, _ => { chunksSent++; return true; }, cancelPaste.Token);
        cancelPaste.Cancel(); pendingObservation.SetResult("target");
        try { await inserting; } catch (OperationCanceledException) { cancelledPaste = true; }
        allInsertionCancellationsBlocked &= cancelledPaste && chunksSent == Math.Max(0, cancelObservation - 2);
    }
    Check(allInsertionCancellationsBlocked, "Cancel during initial UIA, before first SendInput chunk, or before later chunks must stop insertion");
    var meter = new PcmSignalMeter(); meter.Append(new byte[16000]); Check(!meter.HasSignal && meter.Level == 0, "Silent PCM never verifies a microphone");
    byte[] speechPcm = new byte[16000]; for (int i = 0; i < speechPcm.Length; i += 2) { speechPcm[i] = 0; speechPcm[i + 1] = 16; }
    meter.Append(speechPcm); Check(meter.HasSignal && meter.Level > .1, "Sustained nonzero PCM establishes actual signal");
    var transient = new PcmSignalMeter(); transient.Append([255, 127]); transient.Append(new byte[16000]); Check(!transient.HasSignal, "One isolated full-scale spike cannot verify microphone");
    string invalidModel = Path.Combine(directory, "invalid.bin"); File.WriteAllBytes(invalidModel, new byte[2048]);
    Check(!ModelFile.IsUsable(invalidModel) && !ModelFile.IsUsable(null), "Existing arbitrary files must not declare a Whisper model ready");
    byte[] headerModel = new byte[2048]; System.Buffers.Binary.BinaryPrimitives.WriteUInt32LittleEndian(headerModel, 0x67676d6c); File.WriteAllBytes(invalidModel, headerModel);
    Check(ModelFile.IsUsable(invalidModel), "Whisper ggml header passes preliminary model check; actual ASR remains required");
    store.SaveLastText("Привет мир"); Check(store.LoadLastText() == "Привет мир", "Unicode recovery roundtrip"); store.SaveLastText(""); Check(store.LoadLastText() == "", "Clear recovery text");
    byte[] content = Encoding.UTF8.GetBytes("verified model fixture");
    var pin = new ModelPin("fixture.bin", "https://example.invalid/model", Convert.ToHexString(SHA256.HashData(content)), content.Length);
    string destination = Path.Combine(directory, pin.FileName);
    using var http = new HttpClient(new StubHandler(content));
    var modelStore = new ModelStore(http);
    await modelStore.DownloadAsync(pin, destination, null, CancellationToken.None); Check(File.ReadAllBytes(destination).SequenceEqual(content), "Verified download");
    await modelStore.DownloadAsync(pin, destination, null, CancellationToken.None); Check(File.ReadAllBytes(destination).SequenceEqual(content), "Existing pinned model is reused");
    string custom = Path.Combine(directory, "custom-existing.bin"); File.WriteAllText(custom, "user selected model");
    await Throws<InvalidDataException>(() => modelStore.DownloadAsync(pin, custom, null, CancellationToken.None));
    Check(File.ReadAllText(custom) == "user selected model", "Successful download cannot overwrite a different existing model");
    await Throws<InvalidDataException>(() => modelStore.DownloadAsync(pin with { Sha256 = new string('0', 64) }, destination, null, CancellationToken.None));
    Check(File.ReadAllBytes(destination).SequenceEqual(content), "Hash failure preserves valid model");
    await Throws<InvalidDataException>(() => modelStore.DownloadAsync(pin with { Sha256 = new string('0', 64) }, Path.Combine(directory, "bad-hash.bin"), null, CancellationToken.None));
    try { await modelStore.DownloadAsync(pin with { Sha256 = new string('0', 64) }, Path.Combine(directory, "recovery-bad-hash.bin"), null, CancellationToken.None); throw new Exception("Invalid hash unexpectedly accepted"); }
    catch (InvalidDataException failure) { Check(ModelDownloadRecovery.Classify(failure) == ModelDownloadFailure.Integrity, "Actual SHA verification failure must select integrity recovery instead of network advice"); }
    Check(ModelDownloadRecovery.Classify(new IOException("disk unavailable")) == ModelDownloadFailure.TransferOrStorage, "Storage failure remains distinct from integrity failure");
    await Throws<InvalidDataException>(() => modelStore.DownloadAsync(pin with { Size = 2 }, destination, null, CancellationToken.None));
    using var cancelled = new CancellationTokenSource(); cancelled.Cancel();
    await Throws<OperationCanceledException>(() => modelStore.DownloadAsync(pin, destination, null, cancelled.Token));
    Check(File.ReadAllBytes(destination).SequenceEqual(content), "Cancellation preserves valid model");
    using var midTransfer = new CancellationTokenSource();
    string partialDestination = Path.Combine(directory, "pending.bin");
    await Throws<OperationCanceledException>(() => modelStore.DownloadAsync(pin, partialDestination, new ImmediateProgress(() => midTransfer.Cancel()), midTransfer.Token));
    Check(!File.Exists(partialDestination), "Mid-transfer cancellation never commits an incomplete model");
    Check(File.ReadAllBytes(destination).SequenceEqual(content), "Mid-transfer cancellation preserves valid model");
    Check(Directory.GetFiles(directory, "*.download").Length == 0, "Partial download cleanup");
    await Throws<FileNotFoundException>(() => new WhisperRunner(Path.Combine(directory, "missing.exe")).TranscribeAsync("audio", "model", "auto", CancellationToken.None));
    if (!OperatingSystem.IsWindows())
    {
        string audio = Path.Combine(directory, "sample audio.wav"), model = Path.Combine(directory, "model file.bin"), script = Path.Combine(directory, "fake whisper");
        File.WriteAllBytes(audio, [0]); File.WriteAllBytes(model, [0]);
        async Task Script(string body) { if (OperatingSystem.IsWindows()) throw new PlatformNotSupportedException(); await File.WriteAllTextAsync(script, "#!/bin/sh\n" + body); File.SetUnixFileMode(script, UnixFileMode.UserRead | UnixFileMode.UserWrite | UnixFileMode.UserExecute); }
        await Script("while [ \"$1\" != \"\" ]; do if [ \"$1\" = \"-of\" ]; then shift; output=$1; fi; shift; done\nprintf 'Привет\\nfixture' > \"$output.txt\"\n");
        Check(await new WhisperRunner(script).TranscribeAsync(audio, model, "ru", CancellationToken.None) == "Привет fixture", "Process argument paths with spaces/Unicode");
        await Script("exit 7\n"); await Throws<InvalidOperationException>(() => new WhisperRunner(script).TranscribeAsync(audio, model, "auto", CancellationToken.None));
        await Script("sleep 20\n"); await Throws<TimeoutException>(() => new WhisperRunner(script, TimeSpan.FromMilliseconds(100)).TranscribeAsync(audio, model, "auto", CancellationToken.None));
        using var cancel = new CancellationTokenSource(100); await Throws<OperationCanceledException>(() => new WhisperRunner(script).TranscribeAsync(audio, model, "auto", cancel.Token));
    }
    else
    {
        string audio = Path.Combine(directory, "sample audio.wav"), model = Path.Combine(directory, "model file.bin");
        string executable = Path.Combine(AppContext.BaseDirectory, "MacDictate.Core.Tests.exe");
        File.WriteAllBytes(audio, [0]); File.WriteAllText(model, "success");
        Check(await new WhisperRunner(executable).TranscribeAsync(audio, model, "ru", CancellationToken.None) == "Привет fixture", "Windows process paths with spaces and Unicode");
        File.WriteAllText(model, "flood"); Check(await new WhisperRunner(executable).TranscribeAsync(audio, model, "auto", CancellationToken.None) == "Привет fixture", "Both process pipes drain without deadlock");
        File.WriteAllText(model, "fail"); await Throws<InvalidOperationException>(() => new WhisperRunner(executable).TranscribeAsync(audio, model, "auto", CancellationToken.None));
        File.WriteAllText(model, "empty"); await Throws<InvalidDataException>(() => new WhisperRunner(executable).TranscribeAsync(audio, model, "auto", CancellationToken.None));
        File.WriteAllText(model, "timeout"); await Throws<TimeoutException>(() => new WhisperRunner(executable, TimeSpan.FromMilliseconds(150)).TranscribeAsync(audio, model, "auto", CancellationToken.None));
        using var cancel = new CancellationTokenSource(150); await Throws<OperationCanceledException>(() => new WhisperRunner(executable).TranscribeAsync(audio, model, "auto", cancel.Token));
    }
    Console.WriteLine($"PASS {checks} portable policy/storage/download/process checks");
}
finally { Directory.Delete(directory, true); }
return 0;

sealed class StubHandler(byte[] bytes) : HttpMessageHandler
{
    protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        cancellationToken.ThrowIfCancellationRequested();
        return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) { Content = new ByteArrayContent(bytes) });
    }
}
sealed class ImmediateProgress(Action callback) : IProgress<double>
{
    public void Report(double value) => callback();
}
