namespace MacDictate.Windows;

internal sealed class WindowsSetupHelpForm : Form
{
    private readonly ComboBox windowsVersion = new() { Name = "HelpWindowsVersion", DropDownStyle = ComboBoxStyle.DropDownList, Width = 160, AccessibleName = "Windows version" };
    private readonly Label choice = new() { AutoSize = true, Margin = new Padding(3, 9, 8, 3) };
    private readonly TextBox instructions = new() { Name = "WindowsSetupSteps", Multiline = true, ReadOnly = true, ScrollBars = ScrollBars.Vertical, WordWrap = true, Dock = DockStyle.Fill, AccessibleName = "Step-by-step Windows setup" };
    private readonly Button privacy = ActionButton("HelpMicrophonePrivacy"), sound = ActionButton("HelpSoundSettings"), source = ActionButton("HelpMicrosoftSource"), back = ActionButton("HelpReturnToApp");
    private readonly Label openError = new() { Name = "HelpOpenError", AutoSize = true, MaximumSize = new Size(650, 0), Visible = false, Margin = new Padding(3, 7, 3, 7) };
    private string language = "en";
    [System.ComponentModel.DesignerSerializationVisibility(System.ComponentModel.DesignerSerializationVisibility.Hidden)]
    internal int WindowsMajor { get => windowsVersion.SelectedIndex == 1 ? 11 : 10; set => windowsVersion.SelectedIndex = value >= 11 ? 1 : 0; }
    internal WindowsSetupHelpForm(Func<string, bool> openSettings, Action returnToApp)
    {
        Name = "WindowsSetupHelpWindow"; AutoScaleMode = AutoScaleMode.Dpi; AutoScaleDimensions = new SizeF(96, 96);
        ClientSize = new Size(720, 660); MinimumSize = new Size(420, 360); StartPosition = FormStartPosition.CenterParent;
        var top = new FlowLayoutPanel { Dock = DockStyle.Top, Padding = new Padding(10), AutoSize = true, WrapContents = true };
        windowsVersion.Items.AddRange(["Windows 10", "Windows 11"]); WindowsMajor = WindowsSetupHelp.SuggestedWindowsMajor;
        top.Controls.AddRange([choice, windowsVersion]);
        var actions = new FlowLayoutPanel { Dock = DockStyle.Bottom, Padding = new Padding(10), AutoSize = true, WrapContents = true };
        actions.Controls.AddRange([privacy, sound, source, back, openError]);
        var content = new Panel { Dock = DockStyle.Fill, Padding = new Padding(12, 0, 12, 8) }; content.Controls.Add(instructions);
        Controls.Add(content); Controls.Add(top); Controls.Add(actions);
        windowsVersion.SelectedIndexChanged += (_, _) => RenderText();
        void Open(string uri)
        {
            bool success = openSettings(uri);
            openError.Text = uri.StartsWith("ms-settings:", StringComparison.Ordinal)
                ? T("Не удалось открыть настройки. Нажмите Win+I и выполните шаги выше вручную.", "Settings could not open. Press Win+I and follow the steps above manually.")
                : T("Не удалось открыть справку Microsoft. Все необходимые шаги есть выше; проверьте браузер и интернет.", "Microsoft help could not open. The steps above remain available; check your browser and connection.");
            openError.Visible = !success;
        }
        privacy.Click += (_, _) => Open(WindowsSetupHelp.PrivacyUri);
        sound.Click += (_, _) => Open(WindowsSetupHelp.SoundUri);
        source.Click += (_, _) => Open(WindowsSetupHelp.SourceUri(language));
        actions.SizeChanged += (_, _) => openError.MaximumSize = new Size(Math.Max(200, actions.ClientSize.Width - 30), 0);
        back.Click += (_, _) => { Close(); returnToApp(); };
        SetLanguage(language);
    }
    private static Button ActionButton(string name) => new() { Name = name, AutoSize = true, MinimumSize = new Size(100, 36), Padding = new Padding(4) };
    private string T(string ru, string en) => language == "ru" ? ru : en;
    internal void SetLanguage(string value)
    {
        if (language == value && instructions.Text.Length > 0) return;
        language = value;
        Text = T("MacDictate — пошаговая настройка Windows", "MacDictate — step-by-step Windows setup");
        choice.Text = T("Моя версия Windows:", "My Windows version:");
        privacy.Text = T("Доступ к микрофону в Windows", "Windows microphone privacy");
        sound.Text = T("Настройки звука", "Sound settings");
        source.Text = T("Справка Microsoft ↗", "Microsoft help ↗");
        back.Text = T("Вернуться в MacDictate", "Return to MacDictate");
        openError.Visible = false;
        RenderText();
    }
    private void RenderText() { instructions.Text = WindowsSetupHelp.Text(language, WindowsMajor).ReplaceLineEndings("\r\n"); instructions.SelectionStart = 0; instructions.ScrollToCaret(); }
    protected override void OnLoad(EventArgs e)
    {
        base.OnLoad(e);
        Rectangle area = Screen.FromControl(this).WorkingArea;
        MinimumSize = new Size(Math.Min(MinimumSize.Width, area.Width - 24), Math.Min(MinimumSize.Height, area.Height - 24));
        Size = new Size(Math.Min(Width, area.Width - 24), Math.Min(Height, area.Height - 24));
        Location = new Point(area.Left + (area.Width - Width) / 2, area.Top + (area.Height - Height) / 2);
    }
}
