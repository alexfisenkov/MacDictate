namespace MacDictate.Core;

// Shared async boundary for capture startup and ASR publication. Callers own
// native handles, UI state, and cleanup; this layer never touches Win32.
public static class OperationBoundary
{
    public static async Task<TResult> CompleteAfterAsync<TInput, TResult>(Func<Task<TInput>> prepare, Func<TInput, TResult> complete, CancellationToken cancellation, bool waitForCleanup = false)
    {
        cancellation.ThrowIfCancellationRequested();
        Task<TInput> pending = prepare();
        // Native focus discovery can be abandoned; a process-owning ASR action
        // must finish its cancellation/pipe cleanup before callers delete audio.
        var input = waitForCleanup ? await pending : await pending.WaitAsync(cancellation);
        cancellation.ThrowIfCancellationRequested();
        return complete(input);
    }
}
