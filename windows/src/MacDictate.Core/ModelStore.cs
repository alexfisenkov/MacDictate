using System.Security.Cryptography;
using System.Text.Json;

namespace MacDictate.Core;
public sealed record ModelPin(string FileName, string Url, string Sha256, long Size);
public sealed class ModelStore(HttpClient client)
{
    public static ModelPin ReadPin(string path)
    {
        using var doc = JsonDocument.Parse(File.ReadAllText(path));
        var m = doc.RootElement.GetProperty("model");
        var pin = new ModelPin(m.GetProperty("fileName").GetString()!, m.GetProperty("url").GetString()!, m.GetProperty("sha256").GetString()!, m.GetProperty("size").GetInt64());
        if (!Uri.TryCreate(pin.Url, UriKind.Absolute, out var uri) || uri.Scheme != "https" || pin.Sha256.Length != 64 || pin.Size <= 0 || Path.GetFileName(pin.FileName) != pin.FileName)
            throw new InvalidDataException("Invalid pinned model metadata.");
        return pin;
    }
    public async Task DownloadAsync(ModelPin pin, string destination, IProgress<double>? progress, CancellationToken cancellation)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(destination))!);
        cancellation.ThrowIfCancellationRequested();
        if (File.Exists(destination))
        {
            await using var existing = new FileStream(destination, FileMode.Open, FileAccess.Read, FileShare.Read, 81920, true);
            if (existing.Length == pin.Size && Convert.ToHexString(await SHA256.HashDataAsync(existing, cancellation)).Equals(pin.Sha256, StringComparison.OrdinalIgnoreCase))
            { progress?.Report(1); return; }
            throw new InvalidDataException("A different model already exists at the download path. It was preserved. Choose that model, or move it aside before downloading.");
        }
        string temporary = destination + "." + Guid.NewGuid().ToString("N") + ".download";
        try
        {
            using var response = await client.GetAsync(pin.Url, HttpCompletionOption.ResponseHeadersRead, cancellation);
            response.EnsureSuccessStatusCode();
            if (response.Content.Headers.ContentLength is long declared && declared != pin.Size) throw new InvalidDataException("Model size differs from pinned metadata.");
            await using (var input = await response.Content.ReadAsStreamAsync(cancellation))
            await using (var output = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None, 81920, true))
            using (var hash = IncrementalHash.CreateHash(HashAlgorithmName.SHA256))
            {
                var buffer = new byte[81920]; long total = 0; int count;
                while ((count = await input.ReadAsync(buffer, cancellation)) != 0)
                {
                    total += count;
                    if (total > pin.Size) throw new InvalidDataException("Model exceeds pinned size.");
                    hash.AppendData(buffer, 0, count);
                    await output.WriteAsync(buffer.AsMemory(0, count), cancellation);
                    progress?.Report((double)total / pin.Size);
                }
                if (total != pin.Size || !Convert.ToHexString(hash.GetHashAndReset()).Equals(pin.Sha256, StringComparison.OrdinalIgnoreCase))
                    throw new InvalidDataException("Model integrity check failed. Existing model was preserved.");
                await output.FlushAsync(cancellation);
            }
            cancellation.ThrowIfCancellationRequested();
            File.Move(temporary, destination, false); // A file created concurrently must also be preserved.
        }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
