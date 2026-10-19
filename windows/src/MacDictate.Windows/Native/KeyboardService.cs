using System.ComponentModel;
using System.Runtime.InteropServices;
using MacDictate.Core;

namespace MacDictate.Windows.Native;
internal sealed class KeyboardService : NativeWindow, IDisposable
{
    private readonly HotkeyPolicy policy = new();
    private readonly NativeMethods.HookProc callback;
    private nint hook;
    private string mode = "DoubleAlt";
    public Func<bool> IsRecording { get; set; } = () => false;
    public event Action? Activated;
    public KeyboardService()
    {
        CreateHandle(new CreateParams());
        callback = OnKey;
    }
    public void Configure(string value)
    {
        NativeMethods.UnregisterHotKey(Handle, 1);
        if (hook != 0) { NativeMethods.UnhookWindowsHookEx(hook); hook = 0; }
        policy.Reset(); mode = value;
        if (value == "DoubleAlt")
        {
            hook = NativeMethods.SetWindowsHookEx(13, callback, NativeMethods.GetModuleHandle(null), 0);
            if (hook == 0) throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot observe Alt taps. Try another hotkey in Settings.");
        }
        else if (!NativeMethods.RegisterHotKey(Handle, 1, value == "F8" ? 0x4000u : 0x4006u, value == "F8" ? 0x77u : 0x20u))
            throw new Win32Exception(Marshal.GetLastWin32Error(), "Hotkey already used by another app. Choose another key.");
    }
    private nint OnKey(int code, nint message, nint data)
    {
        if (code >= 0 && mode == "DoubleAlt")
        {
            var item = Marshal.PtrToStructure<NativeMethods.KeyboardHook>(data);
            bool pressed = message == 0x100 || message == 0x104;
            bool released = message == 0x101 || message == 0x105;
            // An already held modifier can predate hook installation; disqualify it too.
            if (pressed && item.Key is 0x12 or 0xA4 or 0xA5 && new[] { 0x10, 0x11, 0x5B, 0x5C }.Any(k => NativeMethods.GetAsyncKeyState(k) < 0)) policy.Reset();
            else if ((pressed || released) && policy.Process((int)item.Key, pressed, (item.Flags & 0x12) != 0, Environment.TickCount64, IsRecording())) Activated?.Invoke();
        }
        return NativeMethods.CallNextHookEx(hook, code, message, data);
    }
    protected override void WndProc(ref Message message)
    {
        if (message.Msg == 0x312) Activated?.Invoke();
        base.WndProc(ref message);
    }
    public void Dispose()
    {
        NativeMethods.UnregisterHotKey(Handle, 1);
        if (hook != 0) NativeMethods.UnhookWindowsHookEx(hook);
        DestroyHandle(); GC.KeepAlive(callback);
    }
}
