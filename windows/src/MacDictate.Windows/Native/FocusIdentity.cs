using System.Runtime.InteropServices;
using System.Windows.Automation;

namespace MacDictate.Windows.Native;
internal sealed record FocusIdentity(nint Window, nint InputWindow, uint Process, uint Thread, string AutomationId)
{
    // A hung accessibility provider cannot consume unbounded worker threads.
    private static readonly SemaphoreSlim querySlot = new(1, 1);
    public static async Task<FocusIdentity?> CaptureAsync()
    {
        var native = NativeSnapshot();
        if (native == null || !await querySlot.WaitAsync(0)) return null;
        var query = Task.Run(() =>
        {
            try
            {
                var element = AutomationElement.FocusedElement;
                if (element == null || !element.Current.IsKeyboardFocusable || !element.Current.HasKeyboardFocus) return null;
                int[]? runtime = element.GetRuntimeId();
                return runtime is { Length: > 0 } ? string.Join(",", runtime) : null;
            }
            catch (Exception) { return null; }
            finally { querySlot.Release(); }
        });
        string? automation;
        try { automation = await query.WaitAsync(TimeSpan.FromMilliseconds(500)); }
        catch (TimeoutException) { return null; }
        var after = NativeSnapshot();
        return automation != null && native == after ? new(native.Value.Window, native.Value.InputWindow, native.Value.Process, native.Value.Thread, automation) : null;
    }
    private static (nint Window, nint InputWindow, uint Process, uint Thread)? NativeSnapshot()
    {
        nint window = NativeMethods.GetForegroundWindow();
        uint thread = NativeMethods.GetWindowThreadProcessId(window, out uint process);
        var info = new NativeMethods.GuiThreadInfo { Size = (uint)Marshal.SizeOf<NativeMethods.GuiThreadInfo>() };
        if (window == 0 || thread == 0 || !NativeMethods.GetGUIThreadInfo(thread, ref info) || info.Focus == 0) return null;
        return (window, info.Focus, process, thread);
    }
}
