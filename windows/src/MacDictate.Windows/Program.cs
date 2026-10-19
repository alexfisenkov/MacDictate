using System.Text.Json;
using MacDictate.Core;

namespace MacDictate.Windows;
internal static class Program
{
    [STAThread]
    private static int Main(string[] args)
    {
        ApplicationConfiguration.Initialize();
        if (args.Contains("--smoke-test")) return NativeSmoke.Run(Value(args, "--report"));
        if (args.Contains("--transcribe"))
        {
            try
            {
                string text = new WhisperRunner(RuntimePath).TranscribeAsync(Value(args, "--transcribe") ?? "", Value(args, "--model") ?? "", Value(args, "--language") ?? "auto", CancellationToken.None).GetAwaiter().GetResult();
                WriteReport(new { success = true, text }, Value(args, "--report")); return 0;
            }
            catch (Exception error) { WriteReport(new { success = false, error = error.Message }, Value(args, "--report")); return 1; }
        }
        using var instance = new Mutex(true, "Local\\MacDictate.Desktop", out bool created);
        if (!created) { MessageBox.Show("MacDictate is already running. Look for its icon in the notification area.", "MacDictate"); return 0; }
        try { using var context = new TrayApplication(); Application.Run(context); return 0; }
        catch (Exception error) { MessageBox.Show(error.Message, "MacDictate could not start", MessageBoxButtons.OK, MessageBoxIcon.Error); return 1; }
        finally { instance.ReleaseMutex(); }
    }
    public static string RuntimePath => Path.Combine(AppContext.BaseDirectory, "runtime", "whisper-cli.exe");
    public static void WriteReport(object value, string? path)
    {
        string json = JsonSerializer.Serialize(value);
        if (path != null) File.WriteAllText(path, json);
        Console.WriteLine(json);
    }
    private static string? Value(string[] args, string name)
    {
        int index = Array.IndexOf(args, name); return index >= 0 && index + 1 < args.Length ? args[index + 1] : null;
    }
}
