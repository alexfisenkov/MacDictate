namespace MacDictate.Core;

public static class ModelFile
{
    // Preliminary format/readability check, not a promise that all model tensors are valid.
    public static bool IsUsable(string? path)
    {
        if (string.IsNullOrWhiteSpace(path)) return false;
        try
        {
            using var file = File.OpenRead(path);
            using var reader = new BinaryReader(file);
            return file.Length > 1024 && reader.ReadUInt32() == 0x67676d6c;
        }
        catch (Exception error) when (error is IOException or UnauthorizedAccessException or ArgumentException or NotSupportedException) { return false; }
    }
}
