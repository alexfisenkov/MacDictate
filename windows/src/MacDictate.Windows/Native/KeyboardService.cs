using System.ComponentModel;
using System.Runtime.InteropServices;
using MacDictate.Core;

namespace MacDictate.Windows.Native;
internal sealed record HotkeyObservation(bool LeftAlt, bool Pressed, bool Injected, bool Activated);

// The hook and WM_HOTKEY always live on their own pumping thread. The hook
// only updates policy and posts metadata; application work runs after it returns.
internal sealed class KeyboardService : IDisposable
{
    private readonly Thread thread;
    private readonly ManualResetEventSlim started = new();
    private Control? dispatcher;
    private HookWindow? window;
    private Exception? startupError;
    private bool disposed;
    public Func<bool> IsRecording { get; set; } = () => false;
    public event Action? Activated;
    public event Action<HotkeyObservation>? Observed;
    public int MessageLoopThreadId { get; private set; }
    public KeyboardService()
    {
        thread = new Thread(Run) { IsBackground = true, Name = "MacDictate keyboard message loop" };
        thread.SetApartmentState(ApartmentState.STA); thread.Start();
        if (!started.Wait(TimeSpan.FromSeconds(5))) throw new TimeoutException("Keyboard service did not start. Restart MacDictate.");
        if (startupError != null) throw new InvalidOperationException("Keyboard service could not start.", startupError);
    }
    private void Run()
    {
        try
        {
            MessageLoopThreadId = Environment.CurrentManagedThreadId;
            using var control = new Control(); control.CreateControl(); dispatcher = control;
            using var hookWindow = new HookWindow(this); window = hookWindow;
            started.Set(); Application.Run();
        }
        catch (Exception error) { startupError = error; started.Set(); }
        finally { dispatcher = null; window = null; }
    }
    public void Configure(string value)
    {
        ObjectDisposedException.ThrowIf(disposed, this);
        if (dispatcher == null) throw new InvalidOperationException("Keyboard message loop is unavailable. Restart MacDictate.");
        dispatcher.Invoke(() => window!.Configure(value));
    }
    public void Dispose()
    {
        if (disposed) return; disposed = true;
        if (dispatcher is { IsDisposed: false } control) control.BeginInvoke(Application.ExitThread);
        if (Thread.CurrentThread != thread) thread.Join(TimeSpan.FromSeconds(3));
        started.Dispose();
    }
    private sealed class HookWindow : NativeWindow, IDisposable
    {
        private readonly KeyboardService owner;
        private readonly HotkeyPolicy policy = new();
        private readonly NativeMethods.HookProc callback;
        private nint hook;
        private string mode = "";
        public HookWindow(KeyboardService owner)
        {
            this.owner = owner; callback = OnKey;
            CreateHandle(new CreateParams());
        }
        public void Configure(string value)
        {
            if (value is not ("DoubleAlt" or "F8" or "CtrlShiftSpace")) throw new ArgumentException("Unsupported hotkey.");
            NativeMethods.UnregisterHotKey(Handle, 1);
            if (hook != 0) { NativeMethods.UnhookWindowsHookEx(hook); hook = 0; }
            policy.Reset(); mode = value;
            // Observe Alt in all modes so setup can visibly test the default key.
            hook = NativeMethods.SetWindowsHookEx(13, callback, NativeMethods.GetModuleHandle(null), 0);
            if (hook == 0 && value == "DoubleAlt") throw new Win32Exception(Marshal.GetLastWin32Error(), "Cannot observe Alt taps. Restart MacDictate or choose another hotkey.");
            if (value != "DoubleAlt" && !NativeMethods.RegisterHotKey(Handle, 1, value == "F8" ? 0x4000u : 0x4006u, value == "F8" ? 0x77u : 0x20u))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "Hotkey is already used by another app. Choose another key.");
        }
        private nint OnKey(int code, nint message, nint data)
        {
            if (code >= 0)
            {
                var item = Marshal.PtrToStructure<NativeMethods.KeyboardHook>(data);
                bool pressed = message == 0x100 || message == 0x104;
                bool released = message == 0x101 || message == 0x105;
                if (pressed || released)
                {
                    bool injected = (item.Flags & 0x12) != 0;
                    bool activated = false;
                    if (pressed && item.Key is 0x12 or 0xA4 or 0xA5 && new[] { 0x10, 0x11, 0x5B, 0x5C }.Any(k => NativeMethods.GetAsyncKeyState(k) < 0)) policy.Reset();
                    else activated = policy.Process((int)item.Key, pressed, injected, Environment.TickCount64, false);
                    if (item.Key is 0x12 or 0xA4 or 0xA5)
                    {
                        int flags = (item.Key != 0xA5 ? 1 : 0) | (pressed ? 2 : 0) | (injected ? 4 : 0) | (activated && mode == "DoubleAlt" ? 8 : 0);
                        NativeMethods.PostMessage(Handle, 0x8002, flags, 0);
                    }
                }
            }
            return NativeMethods.CallNextHookEx(hook, code, message, data);
        }
        protected override void WndProc(ref Message message)
        {
            if (message.Msg == 0x8002)
            {
                int flags = (int)message.WParam;
                owner.Observed?.Invoke(new((flags & 1) != 0, (flags & 2) != 0, (flags & 4) != 0, (flags & 8) != 0));
                if ((flags & 8) != 0) owner.Activated?.Invoke();
            }
            if (message.Msg == 0x312) owner.Activated?.Invoke();
            base.WndProc(ref message);
        }
        public void Dispose()
        {
            NativeMethods.UnregisterHotKey(Handle, 1);
            if (hook != 0) NativeMethods.UnhookWindowsHookEx(hook);
            DestroyHandle(); GC.KeepAlive(callback);
        }
    }
}
