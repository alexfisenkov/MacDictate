import Cocoa
import AVFoundation

final class EnvironmentDiagnostics {
    private let whisperRunner: WhisperRunner

    init(whisperRunner: WhisperRunner = WhisperRunner()) {
        self.whisperRunner = whisperRunner
    }

    func currentIssue() -> EnvironmentIssue? {
        if !AXIsProcessTrusted() {
            return .accessibilityMissing
        }

        switch currentMicrophonePermissionState() {
        case .authorized:
            break
        case .notDetermined:
            return .microphonePending
        case .denied:
            return .microphoneDenied
        }

        if ModelLocator.bestAvailableModelPath() == nil {
            return .modelMissing
        }

        if whisperRunner.availableWhisperCliPath() == nil {
            return .whisperMissing
        }

        return nil
    }

    func currentMicrophonePermissionState() -> MicrophonePermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .notDetermined:
            return .notDetermined
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }
    }

    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}
