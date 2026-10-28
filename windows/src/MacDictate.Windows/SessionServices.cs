using MacDictate.Core;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
internal interface IAudioCapture : IDisposable
{
    string AudioPath { get; }
    bool HasSignal { get; }
    void Stop();
}
internal class SessionServices
{
    public virtual string RuntimePath => Program.RuntimePath;
    public virtual IReadOnlyList<MicrophoneDevice> Microphones() => MicrophoneService.Enumerate();
    public virtual Task<MicrophoneTestResult> TestMicrophoneAsync(uint device, IProgress<double> level, CancellationToken token) => MicrophoneService.TestAsync(device, level, token);
    public virtual IAudioCapture StartCapture(string path, uint device, IProgress<double> level) => new WaveRecorder(path, device, level);
    public virtual Task<string> TranscribeAsync(string audio, AppSettings settings, CancellationToken token) => new WhisperRunner(RuntimePath).TranscribeAsync(audio, settings.ModelPath!, settings.Language, token);
    public virtual async Task<string> DownloadModelAsync(LocalStore store, IProgress<double> progress, CancellationToken token)
    {
        var pin = ModelStore.ReadPin(Path.Combine(AppContext.BaseDirectory, "runtime-lock.json"));
        string destination = Path.Combine(store.DirectoryPath, "models", pin.FileName);
        using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
        await new ModelStore(http).DownloadAsync(pin, destination, progress, token);
        return destination;
    }
}
