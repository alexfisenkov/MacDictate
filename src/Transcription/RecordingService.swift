import Foundation
import AVFoundation

enum RecordingFailure: LocalizedError {
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .startFailed(let detail):
            return detail
        }
    }
}

final class RecordingService {
    private let tempWavPath: String
    private var audioRecorder: AVAudioRecorder?

    init(tempWavPath: String = "/tmp/mac_dictate_dist.wav", cleanupStaleFilesOnInit: Bool = true) {
        self.tempWavPath = tempWavPath
        if cleanupStaleFilesOnInit {
            cleanupTemporaryFiles()
        }
    }

    var isRecording: Bool {
        audioRecorder != nil
    }

    var recordingPath: String {
        tempWavPath
    }

    func start() -> Result<Void, RecordingFailure> {
        cleanupTemporaryFiles()

        let audioFilename = URL(fileURLWithPath: tempWavPath)
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 16000.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false
        ]

        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.prepareToRecord()
            if audioRecorder?.record() != true {
                audioRecorder = nil
                return .failure(.startFailed("Не удалось начать запись. Проверьте доступ к микрофону."))
            }

            return .success(())
        } catch {
            audioRecorder = nil
            return .failure(.startFailed("Не удалось начать запись. Проверьте доступ к микрофону."))
        }
    }

    func stop() {
        audioRecorder?.stop()
        audioRecorder = nil
    }

    func cleanupTemporaryFiles() {
        try? FileManager.default.removeItem(atPath: tempWavPath)
        try? FileManager.default.removeItem(atPath: tempWavPath + ".txt")
    }
}
