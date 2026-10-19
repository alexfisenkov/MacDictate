using System.Runtime.InteropServices;
using System.Text;

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
    public static async Task DismissAltMenuAsync(nint target)
    {
        if (target == 0 || NativeMethods.GetForegroundWindow() != target || !IsTargetMenuActive(target)) return;
        if (new[] { 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(key => NativeMethods.GetAsyncKeyState(key) < 0)) return;
        NativeMethods.Input[] escape = [NativeMethods.Key(0x1B, false), NativeMethods.Key(0x1B, true)];
        NativeMethods.SendInput((uint)escape.Length, escape, Marshal.SizeOf<NativeMethods.Input>());
        await Task.Delay(80); // Let the foreground menu process its dismissal before recognition.
    }
    public static async Task<bool> TryPasteAsync(string text, FocusIdentity? identity)
    {
        if (identity == null || await FocusIdentity.CaptureAsync() != identity) return false;
        nint target = identity.Window;
        if (target == 0 || NativeMethods.GetForegroundWindow() != target) return false;
        if (IsTargetMenuActive(target)) return false;
        if (new[] { 0x10, 0x11, 0x12, 0x5B, 0x5C }.Any(key => NativeMethods.GetAsyncKeyState(key) < 0)) return false;
        string normalized = System.Text.RegularExpressions.Regex.Replace(text, @"[\r\n\t]+", " ");
        foreach (var chunk in normalized.EnumerateRunes().Chunk(128))
        {
            if (await FocusIdentity.CaptureAsync() != identity) return false;
            if (NativeMethods.GetForegroundWindow() != target || IsTargetMenuActive(target)) return false;
            var keys = new List<NativeMethods.Input>(chunk.Length * 2);
            foreach (var rune in chunk)
            foreach (char character in rune.ToString())
            {
                keys.Add(NativeMethods.Unicode(character, false)); keys.Add(NativeMethods.Unicode(character, true));
            }
            if (NativeMethods.SendInput((uint)keys.Count, keys.ToArray(), Marshal.SizeOf<NativeMethods.Input>()) != keys.Count) return false;
        }
        return true;
    }
}
