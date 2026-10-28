using System.Text;
using System.Text.RegularExpressions;

namespace MacDictate.Core;
// Native identity observations and input delivery remain caller-owned. This
// deterministic seam runs the same chunk/await policy as production paste.
public static class TextInsertion
{
    public static async Task<bool> TryAsync<TIdentity>(string text, TIdentity? identity, Func<Task<TIdentity?>> observe,
        Func<TIdentity, bool> canSend, Func<string, bool> sendChunk, CancellationToken cancellation) where TIdentity : class
    {
        cancellation.ThrowIfCancellationRequested();
        if (identity == null) return false;
        var observed = await observe().WaitAsync(cancellation);
        cancellation.ThrowIfCancellationRequested();
        if (!Equals(observed, identity) || !canSend(identity)) return false;
        string normalized = Regex.Replace(text, @"[\r\n\t]+", " ");
        foreach (var chunk in normalized.EnumerateRunes().Chunk(128))
        {
            observed = await observe().WaitAsync(cancellation);
            cancellation.ThrowIfCancellationRequested();
            if (!Equals(observed, identity) || !canSend(identity)) return false;
            cancellation.ThrowIfCancellationRequested();
            if (!sendChunk(string.Concat(chunk.Select(rune => rune.ToString())))) return false;
        }
        return true;
    }
}
