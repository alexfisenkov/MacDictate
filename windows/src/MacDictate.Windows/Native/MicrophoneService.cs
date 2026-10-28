using System.Runtime.InteropServices;
using MacDictate.Core;

namespace MacDictate.Windows.Native;
internal sealed record MicrophoneDevice(uint Id, string Name);
internal sealed record MicrophoneTestResult(MicrophoneReadiness State, string Code);
internal static class MicrophoneService
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    private struct Capabilities
    {
        public ushort Manufacturer, Product;
        public uint Version;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string Name;
        public uint Formats;
        public ushort Channels, Reserved;
    }
    [DllImport("winmm.dll")] private static extern uint waveInGetNumDevs();
    [DllImport("winmm.dll", CharSet = CharSet.Unicode)] private static extern uint waveInGetDevCaps(nuint device, out Capabilities capabilities, uint size);
    public static IReadOnlyList<MicrophoneDevice> Enumerate()
    {
        return MicrophoneEnumeration.Read(waveInGetNumDevs(), id =>
        {
            uint code = waveInGetDevCaps(id, out var capabilities, (uint)Marshal.SizeOf<Capabilities>());
            return (code, new MicrophoneDevice(id, capabilities.Name));
        });
    }
    public static async Task<MicrophoneTestResult> TestAsync(uint deviceId, IProgress<double>? level, CancellationToken cancellation)
    {
        string path = Path.Combine(Path.GetTempPath(), "macdictate-mic-test-" + Guid.NewGuid().ToString("N") + ".wav");
        try
        {
            cancellation.ThrowIfCancellationRequested();
            try { if (Enumerate().Count == 0) return new(MicrophoneReadiness.NoDevice, "NO_INPUT_DEVICE"); }
            catch { return new(MicrophoneReadiness.Error, "INPUT_ENUMERATION_FAILED"); }
            return await Task.Run(async () =>
            {
                using var recorder = new WaveRecorder(path, deviceId, level);
                await Task.Delay(TimeSpan.FromSeconds(3), cancellation);
                recorder.Stop();
                return recorder.HasSignal ? new(MicrophoneReadiness.Signal, "PCM_SIGNAL") : new MicrophoneTestResult(MicrophoneReadiness.Silent, "NO_SIGNAL");
            }, cancellation);
        }
        catch (OperationCanceledException) { throw; }
        catch (Exception) { return new(MicrophoneReadiness.Error, "CAPTURE_UNAVAILABLE"); }
        finally { if (File.Exists(path)) File.Delete(path); }
    }
}
