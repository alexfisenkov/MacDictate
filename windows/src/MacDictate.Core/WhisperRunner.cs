using System.Diagnostics;
using System.Text;
using System.Text.RegularExpressions;

namespace MacDictate.Core;
public sealed class WhisperRunner(string executable, TimeSpan? timeout = null)
{
    public async Task<string> TranscribeAsync(string audio, string model, string language, CancellationToken cancellation)
    {
        if (!File.Exists(executable)) throw new FileNotFoundException("Bundled Whisper runtime is missing. Reinstall MacDictate.");
        if (!File.Exists(audio)) throw new FileNotFoundException("Recording is unavailable.");
        if (!File.Exists(model)) throw new FileNotFoundException("Choose or download a Whisper model in Settings.");
        if (language is not ("auto" or "ru" or "en")) throw new ArgumentException("Unsupported language.");
        string prefix = Path.Combine(Path.GetTempPath(), "macdictate-" + Guid.NewGuid().ToString("N"));
        var info = new ProcessStartInfo(executable) { UseShellExecute = false, CreateNoWindow = true, RedirectStandardError = true, RedirectStandardOutput = true };
        foreach (string argument in new[] { "-m", Path.GetFullPath(model), "-f", Path.GetFullPath(audio), "-l", language, "-otxt", "-of", prefix, "-nt", "-np", "-t", Math.Clamp(Environment.ProcessorCount / 2, 1, 8).ToString() }) info.ArgumentList.Add(argument);
        using var process = new Process { StartInfo = info };
        using var deadline = new CancellationTokenSource(timeout ?? TimeSpan.FromMinutes(5));
        using var linked = CancellationTokenSource.CreateLinkedTokenSource(cancellation, deadline.Token);
        try
        {
            if (!process.Start()) throw new InvalidOperationException("Cannot start Whisper.");
            // Drain both streams without retaining transcript or sensitive diagnostics.
            Task stdout = DrainAsync(process.StandardOutput), stderr = DrainAsync(process.StandardError);
            try { await process.WaitForExitAsync(linked.Token); }
            catch (OperationCanceledException)
            {
                try { if (!process.HasExited) process.Kill(true); } catch (InvalidOperationException) { }
                await process.WaitForExitAsync(CancellationToken.None);
                await Task.WhenAll(stdout, stderr);
                if (cancellation.IsCancellationRequested) throw;
                throw new TimeoutException("Recognition timed out. Try a shorter recording or smaller model.");
            }
            await Task.WhenAll(stdout, stderr);
            if (process.ExitCode != 0) throw new InvalidOperationException($"Whisper failed (exit {process.ExitCode}). Check model and reinstall the runtime if needed.");
            if (!File.Exists(prefix + ".txt")) throw new InvalidDataException("Whisper produced no text file.");
            string text = (await File.ReadAllTextAsync(prefix + ".txt", Encoding.UTF8, cancellation)).Trim();
            text = Regex.Replace(text, @"\[(?:BLANK_AUDIO|SILENCE|MUSIC)\]", "", RegexOptions.IgnoreCase).Trim();
            text = Regex.Replace(text, @"\s+", " ").Trim(); // Segment boundaries must not become Enter/send actions.
            if (string.IsNullOrWhiteSpace(text)) throw new InvalidDataException("No speech recognized. Check your microphone and try again.");
            return text;
        }
        finally { if (File.Exists(prefix + ".txt")) File.Delete(prefix + ".txt"); }
    }
    private static async Task DrainAsync(StreamReader reader)
    {
        var buffer = new char[4096];
        while (await reader.ReadAsync(buffer) != 0) { }
    }
}
