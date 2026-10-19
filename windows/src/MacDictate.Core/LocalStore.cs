using System.Text.Json;

namespace MacDictate.Core;
public sealed record AppSettings(string Language = "auto", string Hotkey = "DoubleAlt", string? ModelPath = null);
public sealed class LocalStore
{
    public string DirectoryPath { get; }
    public LocalStore(string directory) { DirectoryPath = directory; Directory.CreateDirectory(directory); }
    public AppSettings LoadSettings()
    {
        try { return JsonSerializer.Deserialize<AppSettings>(File.ReadAllText(Path.Combine(DirectoryPath, "settings.json"))) ?? new(); }
        catch (Exception e) when (e is IOException or JsonException or UnauthorizedAccessException) { return new(); }
    }
    public void SaveSettings(AppSettings settings) => AtomicWrite("settings.json", JsonSerializer.Serialize(settings));
    public string LoadLastText()
    {
        try { return File.ReadAllText(Path.Combine(DirectoryPath, "last-dictation.txt")); }
        catch (IOException) { return ""; }
    }
    public void SaveLastText(string text) => AtomicWrite("last-dictation.txt", text);
    private void AtomicWrite(string name, string text)
    {
        string target = Path.Combine(DirectoryPath, name), temporary = target + "." + Guid.NewGuid().ToString("N") + ".tmp";
        try { File.WriteAllText(temporary, text); File.Move(temporary, target, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}
