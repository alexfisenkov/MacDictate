using MacDictate.Core;

namespace MacDictate.Windows;
internal enum AppActivity { Idle, Downloading, TestingMicrophone, Starting, Recording, Processing }
internal sealed record ViewState(AppSettings Settings, bool RuntimeReady, bool ModelReady,
    MicrophoneReadiness Microphone, bool HotkeyReady, bool HotkeyVerified, AppActivity Activity,
    string Message, string LastText, int ElapsedSeconds = 0, int DownloadPercent = 0)
{
    public SetupReadiness Readiness => SetupReadiness.Evaluate(RuntimeReady, ModelReady, Microphone, HotkeyReady && HotkeyVerified);
}
