using MacDictate.Core;

namespace MacDictate.Windows;
internal sealed class SettingsForm : Form
{
    private readonly ComboBox language = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly ComboBox hotkey = new() { DropDownStyle = ComboBoxStyle.DropDownList };
    private readonly TextBox model = new() { ReadOnly = true, Width = 450 };
    private readonly Button download = new() { Text = "Download verified model", AutoSize = true };
    private readonly Button cancel = new() { Text = "Cancel download", Enabled = false, AutoSize = true };
    private readonly Button save = new() { Text = "Save", AutoSize = true };
    private readonly ProgressBar progress = new() { Width = 440 };
    private readonly Label status = new() { AutoSize = true, MaximumSize = new Size(460, 0) };
    private CancellationTokenSource? transfer;
    private readonly LocalStore store;
    public AppSettings Result { get; private set; }
    public SettingsForm(LocalStore store, AppSettings settings)
    {
        this.store = store; Result = settings;
        Text = "MacDictate settings"; Width = 540; Height = 490; StartPosition = FormStartPosition.CenterScreen;
        FormBorderStyle = FormBorderStyle.FixedDialog; MaximizeBox = false;
        var panel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false, Padding = new Padding(18), AutoScroll = true };
        Controls.Add(panel);
        language.Items.AddRange(["auto", "ru", "en"]); language.SelectedItem = settings.Language;
        hotkey.Items.AddRange(["DoubleAlt", "CtrlShiftSpace", "F8"]); hotkey.SelectedItem = settings.Hotkey;
        model.Text = settings.ModelPath ?? "";
        var browse = new Button { Text = "Choose existing Whisper .bin model…", AutoSize = true };
        browse.Click += (_, _) => { using var picker = new OpenFileDialog { Filter = "Whisper model (*.bin)|*.bin", CheckFileExists = true }; if (picker.ShowDialog(this) == DialogResult.OK) model.Text = picker.FileName; };
        panel.Controls.AddRange([new Label { Text = "Recognition language", AutoSize = true }, language, new Label { Text = "Hotkey", AutoSize = true }, hotkey,
            new Label { Text = "Double left Alt starts; double left Alt again stops.\nCtrl+Shift+Space and F8 toggle recording.", AutoSize = true },
            new Label { Text = "Whisper model (local CPU; first download may take several minutes)", AutoSize = true }, model, browse, download, cancel, progress, status,
            new Label { Text = "Audio is deleted after recognition. Last recognized text is saved locally\nuntil replaced or cleared from the tray menu. No audio or text is uploaded.", AutoSize = true }, save]);
        download.Click += async (_, _) => await DownloadAsync(); cancel.Click += (_, _) => transfer?.Cancel();
        save.Click += (_, _) => { Result = new(language.SelectedItem?.ToString() ?? "auto", hotkey.SelectedItem?.ToString() ?? "DoubleAlt", string.IsNullOrEmpty(model.Text) ? null : model.Text); DialogResult = DialogResult.OK; Close(); };
        FormClosing += (_, e) => { if (transfer != null) { e.Cancel = true; transfer.Cancel(); status.Text = "Cancelling download; close again after cleanup."; } };
    }
    private async Task DownloadAsync()
    {
        using var cancellation = new CancellationTokenSource(); transfer = cancellation;
        download.Enabled = save.Enabled = false; cancel.Enabled = true;
        try
        {
            var pin = ModelStore.ReadPin(Path.Combine(AppContext.BaseDirectory, "runtime-lock.json"));
            string destination = Path.Combine(store.DirectoryPath, "models", pin.FileName);
            using var http = new HttpClient { Timeout = Timeout.InfiniteTimeSpan };
            status.Text = "Downloading model from Hugging Face. Your recordings stay on this computer.";
            await new ModelStore(http).DownloadAsync(pin, destination, new Progress<double>(value => progress.Value = Math.Clamp((int)(value * 100), 0, 100)), cancellation.Token);
            model.Text = destination; status.Text = "Verified model ready. Select Save to use it.";
        }
        catch (OperationCanceledException) { status.Text = "Download cancelled. Existing model was preserved."; }
        catch (Exception error) { status.Text = "Download failed: " + error.Message; }
        finally { transfer = null; download.Enabled = save.Enabled = true; cancel.Enabled = false; }
    }
}
