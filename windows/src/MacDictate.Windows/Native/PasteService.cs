using System.Runtime.InteropServices;
using MacDictate.Core;

namespace MacDictate.Windows.Native;
internal static class PasteService
{
    public static Task<FocusIdentity?> CaptureTargetAsync() => FocusIdentity.CaptureAsync();
    public static bool IsTargetMenuActive(nint target)
    {
        uint thread = NativeMethods.GetWindowThreadProcessId(target, out _);
        var info = new NativeMethods.GuiThreadInfo { Size = (uint)Marshal.SizeOf<NativeMethods.GuiThreadInfo>() };
        return thread != 0 && NativeMethods.GetGUIThreadInfo(thread, ref info) && (info.Flags & 0x1C) != 0;
    }
    public static async Task DismissAltMenuAsync(nint target, CancellationToken cancellation = default)
    {
        cancellation.ThrowIfCancellationRequested();
        if (target == 0 || NativeMethods.GetForegroundWindow() != target || !IsTargetMenuActive(target)) return;
        if (new[] { 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(key => NativeMethods.GetAsyncKeyState(key) < 0)) return;
        NativeMethods.Input[] escape = [NativeMethods.Key(0x1B, false), NativeMethods.Key(0x1B, true)];
        cancellation.ThrowIfCancellationRequested();
        NativeMethods.SendInput((uint)escape.Length, escape, Marshal.SizeOf<NativeMethods.Input>());
        await Task.Delay(80, cancellation); // Let the foreground menu process its dismissal before recognition.
    }
    public static Task<bool> TryPasteAsync(string text, FocusIdentity? identity, CancellationToken cancellation = default)
    {
        return TextInsertion.TryAsync(text, identity, FocusIdentity.CaptureAsync,
            current => current.Window != 0 && NativeMethods.GetForegroundWindow() == current.Window && !IsTargetMenuActive(current.Window)
                && !new[] { 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(key => NativeMethods.GetAsyncKeyState(key) < 0),
            chunk =>
        {
            var keys = new List<NativeMethods.Input>(chunk.Length * 2);
            foreach (char character in chunk)
            {
                keys.Add(NativeMethods.Unicode(character, false)); keys.Add(NativeMethods.Unicode(character, true));
            }
            cancellation.ThrowIfCancellationRequested();
            return NativeMethods.SendInput((uint)keys.Count, keys.ToArray(), Marshal.SizeOf<NativeMethods.Input>()) == keys.Count;
        }, cancellation);
    }
}
