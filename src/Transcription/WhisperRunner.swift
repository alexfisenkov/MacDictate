import Foundation

enum TranscriptionFailure: LocalizedError {
    case modelMissing
    case whisperMissing
    case launchFailed(String)
    case nonZeroExit(Int32, String)
    case outputMissing

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "Модель Whisper не найдена."
        case .whisperMissing:
            return "Не найден whisper-cli."
        case .launchFailed(let detail):
            return "Не удалось запустить whisper-cli: \(detail)"
        case .nonZeroExit(let code, let detail):
            if detail.isEmpty {
                return "whisper-cli завершился с ошибкой (код \(code))."
            }
            return "whisper-cli завершился с ошибкой (код \(code)): \(detail)"
        case .outputMissing:
            return "Whisper не вернул результат распознавания."
        }
    }
}

final class WhisperRunner {
    private let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func availableWhisperCliPath() -> String? {
        var candidates: [String] = []
        if let resourcePath = bundle.resourcePath {
            candidates.append(resourcePath + "/bin/whisper-cli")
        }
        candidates.append("/opt/homebrew/bin/whisper-cli")
        candidates.append("/usr/local/bin/whisper-cli")

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }

    func transcribe(audioPath: String) -> Result<String, TranscriptionFailure> {
        guard let modelPath = ModelLocator.bestAvailableModelPath() else {
            cleanupTemporaryFiles(audioPath: audioPath)
            return .failure(.modelMissing)
        }

        guard let whisperCli = availableWhisperCliPath() else {
            cleanupTemporaryFiles(audioPath: audioPath)
            return .failure(.whisperMissing)
        }

        let task = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()

        task.launchPath = whisperCli
        task.arguments = ["-m", modelPath, "-f", audioPath, "-l", "ru", "-nt", "-otxt"]
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        do {
            try task.run()
            task.waitUntilExit()

            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrText = String(data: stderrData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard task.terminationStatus == 0 else {
                cleanupTemporaryFiles(audioPath: audioPath)
                return .failure(.nonZeroExit(task.terminationStatus, stderrText))
            }

            let txtPath = audioPath + ".txt"
            guard FileManager.default.fileExists(atPath: txtPath) else {
                cleanupTemporaryFiles(audioPath: audioPath)
                return .failure(.outputMissing)
            }

            let transcribedResult = try String(contentsOfFile: txtPath, encoding: .utf8)
            cleanupTemporaryFiles(audioPath: audioPath)
            return .success(transcribedResult)
        } catch {
            cleanupTemporaryFiles(audioPath: audioPath)
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    func cleanOutput(_ text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "[БЕЗ ЗВУКА]", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[без звука]", with: "")
        cleaned = cleaned.replacingOccurrences(of: "[ШУМ]", with: "")
        cleaned = cleaned.replacingOccurrences(of: "(БЕЗ ЗВУКА)", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned
    }

    private func cleanupTemporaryFiles(audioPath: String) {
        try? FileManager.default.removeItem(atPath: audioPath)
        try? FileManager.default.removeItem(atPath: audioPath + ".txt")
    }
}
