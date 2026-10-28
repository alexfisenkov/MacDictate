namespace MacDictate.Windows;
internal sealed class InstanceActivation : IDisposable
{
    private const string Name = "Local\\MacDictate.Desktop.ShowWindow";
    private readonly EventWaitHandle signal = new(false, EventResetMode.AutoReset, Name);
    private readonly RegisteredWaitHandle listener;
    public InstanceActivation(Action show) => listener = ThreadPool.RegisterWaitForSingleObject(signal, (_, _) => show(), null, Timeout.Infinite, false);
    public static bool NotifyExisting()
    {
        // The first instance may still be creating its activation endpoint.
        for (int attempt = 0; attempt < 20; attempt++)
        {
            try { using var existing = EventWaitHandle.OpenExisting(Name); existing.Set(); return true; }
            catch (WaitHandleCannotBeOpenedException) { Thread.Sleep(50); }
        }
        return false;
    }
    public void Dispose() { listener.Unregister(null); signal.Dispose(); }
}
