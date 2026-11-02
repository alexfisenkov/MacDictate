namespace MacDictate.Windows;

// Explicit --onboarding-smoke coverage; OS settings are never changed by this test.
internal static class WindowsSetupHelpSmoke
{
    internal static void Run(MainForm home, Action<string> changeLanguage, float scale, string? reportPath, List<string> checks, List<string> screenshots)
    {
        void Check(bool condition, string name) { if (!condition) throw new InvalidOperationException(name); checks.Add(name); }
        T Find<T>(Control parent, string name) where T : Control => parent.Controls.Find(name, true).OfType<T>().Single();
        var openButton = Find<Button>(home, "OpenWindowsSetupHelp");
        Check(openButton.Visible && openButton.Enabled && openButton.Parent!.ClientRectangle.Contains(openButton.Bounds), "offline setup help action is visible in the pinned main footer before a model download");
        openButton.PerformClick();
        var help = home.OwnedForms.OfType<WindowsSetupHelpForm>().Single();
        Check(help.Visible && !help.Modal && ReferenceEquals(help.Owner, home), "actual setup help opens as a modeless owned window");
        Check(ReferenceEquals(home.ShowSetupHelp(), help), "repeated help action reuses one window");
        if (scale != 1)
        {
            IEnumerable<Control> Descendants(Control parent) => parent.Controls.Cast<Control>().SelectMany(child => new[] { child }.Concat(Descendants(child)));
            var fonts = new[] { help }.Concat(Descendants(help)).Select(control => (control, control.Font.FontFamily, control.Font.Size, control.Font.Style)).ToArray();
            help.Scale(new SizeF(scale, scale));
            foreach (var (control, family, size, style) in fonts) control.Font = new Font(family, size * scale, style);
            Rectangle area = Screen.FromControl(help).WorkingArea;
            help.Size = new Size(Math.Min(help.Width, area.Width - 24), Math.Min(help.Height, area.Height - 24));
        }
        foreach (string language in new[] { "ru", "en" })
        {
            changeLanguage(language);
            foreach (int version in new[] { 10, 11 })
            {
                Find<ComboBox>(help, "HelpWindowsVersion").SelectedIndex = version == 11 ? 1 : 0;
                help.PerformLayout();
                var steps = Find<TextBox>(help, "WindowsSetupSteps");
                string path = language == "ru" ? version == 11 ? "Конфиденциальность и безопасность → Микрофон" : "Конфиденциальность → Микрофон" : version == 11 ? "Privacy & security → Microphone" : "Privacy → Microphone";
                Check(steps.Text.Contains(path) && steps.Text.Contains("WINDOWS " + version), $"{language} Windows {version} selection shows its own privacy path in the actual help textbox");
                Check(steps.Visible && steps.ReadOnly && steps.Multiline && steps.WordWrap && steps.ScrollBars == ScrollBars.Vertical && steps.ClientSize.Height > 100,
                    $"{language} Windows {version} help is readable, selectable and vertically scrollable");
                foreach (var button in help.Controls.Find("HelpReturnToApp", true).OfType<Button>().Single().Parent!.Controls.OfType<Button>())
                {
                    Size preferred = button.GetPreferredSize(new Size(button.Width, 0));
                    Check(button.Visible && button.Parent!.ClientRectangle.Contains(button.Bounds) && button.Width >= preferred.Width && button.Height >= preferred.Height,
                        $"{language} Windows {version} help action {button.Name} fits without clipping");
                }
                steps.SelectionStart = steps.TextLength; steps.ScrollToCaret();
                Point final = steps.GetPositionFromCharIndex(steps.TextLength - 1);
                Check(final.Y >= 0 && final.Y < steps.ClientSize.Height, $"{language} Windows {version} final instructions can be scrolled into view");
                steps.SelectionStart = 0; steps.ScrollToCaret();
                Snapshot(help, $"help-{language}-windows-{version}", reportPath, screenshots);
            }
        }
        Find<Button>(help, "HelpReturnToApp").PerformClick();
        Check(help.IsDisposed && home.Visible, "Return to MacDictate closes help and leaves the main window usable");
        var reopened = home.ShowSetupHelp();
        Check(reopened.Visible && !ReferenceEquals(reopened, help), "closed setup help can be opened again");
        reopened.Close();
        var destinations = new List<string>();
        using (var routing = new WindowsSetupHelpForm(uri => { destinations.Add(uri); return false; }, () => { }))
        {
            routing.SetLanguage("en"); routing.Show(home);
            foreach (string name in new[] { "HelpMicrophonePrivacy", "HelpSoundSettings", "HelpMicrosoftSource" })
            {
                Find<Button>(routing, name).PerformClick();
                Check(Find<Label>(routing, "HelpOpenError").Visible, "failed synthetic opener exposes visible local recovery for " + name);
            }
            Check(destinations.SequenceEqual(new[] { "ms-settings:privacy-microphone", "ms-settings:sound", WindowsSetupHelp.SourceUri("en") }), "actual help buttons route to the correct destinations without opening OS settings in smoke");
            Check(Find<Label>(routing, "HelpOpenError").Text.Contains("steps above"), "browser failure preserves offline instructions");
            Find<Button>(routing, "HelpMicrophonePrivacy").PerformClick();
            Check(Find<Label>(routing, "HelpOpenError").Text.Contains("Win+I"), "settings failure explains the manual Win+I fallback");
            routing.Close();
        }
        changeLanguage("ru");
    }
    private static void Snapshot(Form form, string name, string? reportPath, List<string> screenshots)
    {
        if (reportPath == null) return;
        string output = Path.GetFullPath(reportPath), folder = Path.GetDirectoryName(output)!;
        Directory.CreateDirectory(folder);
        string file = Path.GetFileNameWithoutExtension(output) + "-" + name + ".png";
        using var bitmap = new Bitmap(form.Width, form.Height);
        form.DrawToBitmap(bitmap, new Rectangle(Point.Empty, form.Size));
        bitmap.Save(Path.Combine(folder, file), System.Drawing.Imaging.ImageFormat.Png); screenshots.Add(file);
    }
}
