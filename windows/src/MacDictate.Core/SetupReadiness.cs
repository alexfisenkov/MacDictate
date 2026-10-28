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
