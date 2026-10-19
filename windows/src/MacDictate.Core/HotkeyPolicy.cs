namespace MacDictate.Core;

// Receives only key metadata; no characters or keyboard history are retained.
public sealed class HotkeyPolicy
{
    private readonly HashSet<int> down = [];
    private bool cleanAlt;
    private int altKey;
    private long? lastTap;
    private long altPressedAt;
    public int DoubleTapMilliseconds { get; } = 400;
    public bool Process(int key, bool pressed, bool injected, long milliseconds, bool recording)
    {
        if (injected) return false;
        bool alt = key is 0x12 or 0xA4 or 0xA5;
        if (pressed)
        {
            if (!down.Add(key)) { cleanAlt = false; lastTap = null; return false; }
            if (alt)
            {
                cleanAlt = down.Count == 1 && key != 0xA5; // Right Alt may be AltGr.
                altKey = key;
                altPressedAt = milliseconds;
                if (!cleanAlt) lastTap = null;
            }
            else { cleanAlt = false; lastTap = null; }
            return false;
        }
        bool wasDown = down.Remove(key);
        if (!alt || !wasDown || key != altKey || !cleanAlt || down.Count != 0) return false;
        cleanAlt = false;
        if (milliseconds - altPressedAt is < 0 or > 300) { lastTap = null; return false; }
        if (lastTap is long previous && milliseconds - previous is >= 0 && milliseconds - previous <= DoubleTapMilliseconds)
        { lastTap = null; return true; }
        lastTap = milliseconds;
        return false;
    }
    public void Reset() { down.Clear(); lastTap = null; cleanAlt = false; }
}
