namespace MacDictate.Core;

public enum MicrophoneReadiness { Untested, NoDevice, Silent, Error, Signal }
public enum SetupStep { Runtime, Model, Microphone, Hotkey, Dictation }
public sealed record SetupReadiness(SetupStep Next, bool CanRecord)
{
    public static SetupReadiness Evaluate(bool runtime, bool model, MicrophoneReadiness microphone, bool hotkey)
    {
        bool input = microphone == MicrophoneReadiness.Signal;
        return new(!runtime ? SetupStep.Runtime : !model ? SetupStep.Model : !input ? SetupStep.Microphone : !hotkey ? SetupStep.Hotkey : SetupStep.Dictation,
            runtime && model && microphone is MicrophoneReadiness.Signal or MicrophoneReadiness.Untested);
    }
}

public sealed record MicrophoneSelection(uint DeviceId, MicrophoneReadiness Readiness)
{
    public static MicrophoneSelection Reconcile(uint storedId, IReadOnlyCollection<uint> availableIds, MicrophoneReadiness readiness)
    {
        if (availableIds.Count == 0) return new(uint.MaxValue, MicrophoneReadiness.NoDevice);
        if (storedId == uint.MaxValue || availableIds.Contains(storedId)) return new(storedId, readiness == MicrophoneReadiness.NoDevice ? MicrophoneReadiness.Untested : readiness);
        return new(availableIds.First(), MicrophoneReadiness.Untested);
    }
}

public enum ModelDownloadFailure { Integrity, TransferOrStorage }
public static class ModelDownloadRecovery
{
    public static ModelDownloadFailure Classify(Exception failure) => failure is InvalidDataException ? ModelDownloadFailure.Integrity : ModelDownloadFailure.TransferOrStorage;
}
