using System.Runtime.InteropServices;
using MacDictate.Windows.Native;

namespace MacDictate.Windows;
internal static class NativeSmoke
{
    [DllImport("user32.dll")] private static extern nint CreateMenu();
    [DllImport("user32.dll")] private static extern nint CreatePopupMenu();
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool AppendMenu(nint menu, uint flags, nuint item, string label);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool SetMenu(nint window, nint menu);
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] private static extern bool DestroyMenu(nint menu);
    public static int Run(string? reportPath)
    {
        int result = 1;
        using var form = new Form { Text = "MacDictate native integration smoke", Width = 540, Height = 240 };
        var textbox = new TextBox { Multiline = true, Dock = DockStyle.Top, Height = 70 };
        var secondTextbox = new TextBox { Multiline = true, Dock = DockStyle.Bottom, Height = 45 };
        form.Controls.Add(textbox);
        form.Controls.Add(secondTextbox);
        nint menu = CreateMenu(), submenu = CreatePopupMenu();
        AppendMenu(submenu, 0, 1, "&Example"); AppendMenu(menu, 0x10, (nuint)submenu, "&File"); SetMenu(form.Handle, menu);
        form.Shown += async (_, _) =>
        {
            try
            {
                using var keyboard = new KeyboardService(); int activations = 0;
                keyboard.Activated += () => activations++; keyboard.Configure("DoubleAlt");
                form.Activate(); textbox.Focus(); NativeMethods.SetForegroundWindow(form.Handle);
                await Task.Delay(250);
                if (NativeMethods.GetForegroundWindow() != form.Handle) throw new InvalidOperationException("Interactive foreground desktop is unavailable.");
                NativeMethods.Input[] alt = [NativeMethods.Key(0xA4, false), NativeMethods.Key(0xA4, true), NativeMethods.Key(0xA4, false), NativeMethods.Key(0xA4, true)];
                if (NativeMethods.SendInput((uint)alt.Length, alt, Marshal.SizeOf<NativeMethods.Input>()) != alt.Length) throw new InvalidOperationException("Injected input was blocked.");
                await Task.Delay(150);
                if (activations != 0) throw new InvalidOperationException("Injected Alt events must not trigger recording.");
                await PasteService.DismissAltMenuAsync(form.Handle);
                textbox.Focus();
                var original = await PasteService.CaptureTargetAsync() ?? throw new InvalidOperationException("UI Automation could not identify the original input.");
                NativeMethods.Input[] singleAlt = [NativeMethods.Key(0xA4, false), NativeMethods.Key(0xA4, true)];
                NativeMethods.SendInput((uint)singleAlt.Length, singleAlt, Marshal.SizeOf<NativeMethods.Input>());
                await Task.Delay(100);
                if (!PasteService.IsTargetMenuActive(form.Handle)) throw new InvalidOperationException("Native menu did not activate for the stop-Alt simulation.");
                if (await PasteService.TryPasteAsync("unsafe while menu active", original)) throw new InvalidOperationException("Paste must reject an active native menu.");
                await PasteService.DismissAltMenuAsync(form.Handle);
                if (PasteService.IsTargetMenuActive(form.Handle)) throw new InvalidOperationException("Stop-Alt menu was not dismissed.");
                textbox.Focus();
                original = await PasteService.CaptureTargetAsync() ?? throw new InvalidOperationException("Input identity could not be recaptured.");
                secondTextbox.Focus();
                await Task.Delay(80);
                if (await PasteService.TryPasteAsync("unsafe other input", original)) throw new InvalidOperationException("Paste allowed another input in the same window.");
                if (textbox.Text.Length != 0 || secondTextbox.Text.Length != 0) throw new InvalidOperationException("Changed-focus guard modified an input.");
                textbox.Focus();
                original = await PasteService.CaptureTargetAsync() ?? throw new InvalidOperationException("Original input identity unavailable after restoring focus.");
                const string input = "MacDictate smoke: Привет 👋\r\nWindows!";
                const string expected = "MacDictate smoke: Привет 👋 Windows!";
                Clipboard.SetText("MacDictate smoke clipboard sentinel");
                if (!await PasteService.TryPasteAsync(input, original)) throw new InvalidOperationException("Native SendInput paste failed.");
                await Task.Delay(250);
                if (textbox.Text != expected) throw new InvalidOperationException("TextBox did not receive normalized Unicode text.");
                if (Clipboard.GetText() != "MacDictate smoke clipboard sentinel") throw new InvalidOperationException("Automatic dictation must preserve the clipboard.");
                if (await PasteService.TryPasteAsync("unsafe", original with { Window = new nint(12345) })) throw new InvalidOperationException("Paste allowed a changed foreground target.");
                if (await PasteService.TryPasteAsync("unsafe", null)) throw new InvalidOperationException("Paste allowed an unidentified input.");
                keyboard.Configure("F8"); keyboard.Configure("CtrlShiftSpace"); keyboard.Configure("DoubleAlt");
                Program.WriteReport(new { success = true, keyboardHook = "installed; injected events ignored", paste = "Unicode/surrogate readback; newline normalized without Return; native Alt-menu dismissed", clipboard = "unchanged by automatic dictation", changedFocus = "different window and different input in same window blocked; both inputs read back unchanged", alternateHotkeys = "registered", physicalMicrophone = "NOT_TESTED", physicalAlt = "NOT_TESTED" }, reportPath);
                result = 0;
            }
            catch (Exception error) { Program.WriteReport(new { success = false, error = error.Message }, reportPath); }
            finally { SetMenu(form.Handle, 0); DestroyMenu(menu); form.Close(); }
        };
        Application.Run(form); return result;
    }
}
