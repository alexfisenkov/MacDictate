using System.ComponentModel;
using System.Runtime.InteropServices;

namespace MacDictate.Windows.Native;
internal sealed class WaveRecorder : IDisposable
{
    [StructLayout(LayoutKind.Sequential, Pack = 2)] private struct Format { public ushort Tag, Channels; public uint Rate, BytesPerSecond; public ushort Align, Bits, Extra; }
    [StructLayout(LayoutKind.Sequential)] private struct Header { public nint Data; public uint Length, Recorded; public nuint User; public uint Flags, Loops; public nint Next; public nuint Reserved; }
    [DllImport("winmm.dll")] private static extern uint waveInOpen(out nint input, uint device, ref Format format, nint notificationEvent, nuint instance, uint flags);
    [DllImport("winmm.dll")] private static extern uint waveInPrepareHeader(nint input, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveInUnprepareHeader(nint input, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveInAddBuffer(nint input, nint header, uint size);
    [DllImport("winmm.dll")] private static extern uint waveInStart(nint input);
    [DllImport("winmm.dll")] private static extern uint waveInReset(nint input);
    [DllImport("winmm.dll")] private static extern uint waveInClose(nint input);
    private readonly List<(GCHandle Buffer, nint Header)> buffers = [];
    private readonly object gate = new();
    private readonly AutoResetEvent notification = new(false);
    private FileStream? output;
    private Thread? worker;
    private nint device;
    private volatile bool recording;
    private bool disposed;
    private Exception? captureError;
    private long bytes;
    private const long MaximumBytes = 120L * 32000;
    private static uint HeaderSize => (uint)Marshal.SizeOf<Header>();
    public string AudioPath { get; }
    public WaveRecorder(string path)
    {
        AudioPath = path;
        try
        {
            output = new FileStream(path, FileMode.CreateNew, FileAccess.ReadWrite, FileShare.None);
            output.Write(new byte[44]);
            var format = new Format { Tag = 1, Channels = 1, Rate = 16000, BytesPerSecond = 32000, Align = 2, Bits = 16 };
            Check(waveInOpen(out device, uint.MaxValue, ref format, notification.SafeWaitHandle.DangerousGetHandle(), 0, 0x50000));
            for (int i = 0; i < 4; i++)
            {
                var buffer = GCHandle.Alloc(new byte[8000], GCHandleType.Pinned);
                nint header;
                try { header = Marshal.AllocHGlobal((int)HeaderSize); }
                catch { buffer.Free(); throw; }
                Marshal.StructureToPtr(new Header { Data = buffer.AddrOfPinnedObject(), Length = 8000 }, header, false);
                buffers.Add((buffer, header));
                Check(waveInPrepareHeader(device, header, HeaderSize)); Check(waveInAddBuffer(device, header, HeaderSize));
            }
            recording = true;
            worker = new Thread(CaptureLoop) { IsBackground = true, Name = "MacDictate audio capture" }; worker.Start();
            Check(waveInStart(device));
        }
        catch (Exception original)
        {
            try { Dispose(); }
            catch (Exception cleanup) { throw new AggregateException("Microphone setup and cleanup failed. Restart MacDictate before retrying.", original, cleanup); }
            throw;
        }
    }
    private void CaptureLoop()
    {
        try
        {
            while (true)
            {
                notification.WaitOne();
                lock (gate)
                {
                    foreach (var item in buffers)
                    {
                        var header = Marshal.PtrToStructure<Header>(item.Header);
                        if ((header.Flags & 1) == 0) continue; // WHDR_DONE; never touch a driver-owned buffer.
                        if (header.Recorded > 0 && bytes < MaximumBytes)
                        {
                            int count = (int)Math.Min(header.Recorded, MaximumBytes - bytes);
                            byte[] data = new byte[count]; Marshal.Copy(header.Data, data, 0, count);
                            output!.Write(data); bytes += count;
                        }
                        if (recording && bytes < MaximumBytes) Check(waveInAddBuffer(device, item.Header, HeaderSize));
                    }
                    if (!recording || bytes >= MaximumBytes) break;
                }
            }
        }
        catch (Exception error) { captureError = error; }
    }
    public void Stop()
    {
        lock (gate) { recording = false; if (device != 0) Check(waveInReset(device)); }
        notification.Set(); worker?.Join();
        var stream = output ?? throw new ObjectDisposedException(nameof(WaveRecorder));
        stream.Position = 0;
        using var writer = new BinaryWriter(stream, System.Text.Encoding.ASCII, true);
        writer.Write("RIFF"u8); writer.Write((uint)(36 + bytes)); writer.Write("WAVEfmt "u8); writer.Write(16u);
        writer.Write((ushort)1); writer.Write((ushort)1); writer.Write(16000u); writer.Write(32000u); writer.Write((ushort)2); writer.Write((ushort)16);
        writer.Write("data"u8); writer.Write((uint)bytes); stream.Flush();
        if (captureError != null) throw new IOException("Microphone capture failed. Check Windows sound input settings.", captureError);
        if (bytes < 1600) throw new IOException("Recording is too short. Check microphone access and record some speech.");
    }
    private static void Check(uint result)
    {
        if (result != 0) throw new Win32Exception((int)result, $"Microphone error {result}. Allow desktop microphone access in Windows Settings > Privacy (Windows 10) or Privacy & security (Windows 11) > Microphone, and select a working default input in Sound.");
    }
    public void Dispose()
    {
        if (disposed) return; disposed = true;
        var errors = new List<Exception>();
        bool nativeReleased = device == 0;
        try
        {
            lock (gate)
            {
                recording = false;
                if (device != 0 && waveInReset(device) is uint reset && reset != 0) errors.Add(new IOException($"Microphone reset failed ({reset})."));
            }
            notification.Set(); worker?.Join();
            foreach (var item in buffers)
            {
                uint result = device == 0 ? 0 : waveInUnprepareHeader(device, item.Header, HeaderSize);
                var header = Marshal.PtrToStructure<Header>(item.Header);
                // Retain the pinned allocation if a broken driver still owns it; freeing it would corrupt memory.
                if ((header.Flags & 0x10) != 0 || result is not (0 or 34))
                { errors.Add(new IOException($"Microphone did not release a native buffer ({result}); restart MacDictate.")); continue; }
                Marshal.FreeHGlobal(item.Header); item.Buffer.Free();
            }
            buffers.Clear();
            if (device != 0)
            {
                uint close = waveInClose(device); nativeReleased = close == 0;
                if (close != 0) errors.Add(new IOException($"Microphone close failed ({close}); restart MacDictate."));
            }
        }
        finally
        {
            device = 0;
            try { output?.Dispose(); }
            catch (IOException error) { errors.Add(error); }
            finally
            {
                output = null;
                if (nativeReleased) notification.Dispose();
                else GCHandle.Alloc(notification); // Broken driver may still signal this event; retain its handle safely.
            }
        }
        if (errors.Count > 0) throw new AggregateException("Microphone cleanup failed. Native driver-owned memory was preserved safely; restart MacDictate.", errors);
    }
}
