namespace MacDictate.Windows;
// Status remains visible above the target app without taking its keyboard focus.
internal sealed class RecordingOverlay : Form
{
    private readonly Label label = new() { AutoSize = true, Padding = new Padding(12), MaximumSize = new Size(420, 0) };
    public RecordingOverlay()
    {
        FormBorderStyle = FormBorderStyle.None; ShowInTaskbar = false; TopMost = true;
        AutoScaleMode = AutoScaleMode.Dpi; AutoSize = true; AutoSizeMode = AutoSizeMode.GrowAndShrink;
        BackColor = Color.FromArgb(30, 30, 30); ForeColor = Color.White; Controls.Add(label);
        StartPosition = FormStartPosition.Manual;
    }
    protected override bool ShowWithoutActivation => true;
    protected override CreateParams CreateParams { get { var parameters = base.CreateParams; parameters.ExStyle |= 0x08000080; return parameters; } }
    public void UpdateStatus(string text)
    {
        label.Text = text;
        var area = Screen.PrimaryScreen?.WorkingArea ?? new Rectangle(0, 0, 1000, 700);
        Location = new Point(area.Right - Width - 20, area.Top + 20);
        if (!Visible) Show();
    }
}
