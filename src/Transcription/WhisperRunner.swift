import Foundation
import Darwin

enum TranscriptionFailure: LocalizedError {
    case modelMissing
    case whisperMissing
    case launchFailed(String)
    case nonZeroExit(Int32, String)
    case outputMissing
    case timedOut(TimeInterval)

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
        case .timedOut(let timeout):
            return "Распознавание не завершилось за \(Int(timeout)) сек. MacDictate остановил зависший процесс."
        }
    }
}

final class WhisperRunner {
    private let timeoutSeconds: TimeInterval
    private let terminationGraceSeconds: TimeInterval
    private let modelPathProvider: () -> String?
    private let whisperCliPathProvider: () -> String?

    init(
        bundle: Bundle = .main,
        timeoutSeconds: TimeInterval = 180,
        terminationGraceSeconds: TimeInterval = 2,
        modelPathProvider: (() -> String?)? = nil,
        whisperCliPathProvider: (() -> String?)? = nil
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.terminationGraceSeconds = terminationGraceSeconds
        self.modelPathProvider = modelPathProvider ?? {
            ModelLocator.bestAvailableModelPath()
        }
        self.whisperCliPathProvider = whisperCliPathProvider ?? {
            WhisperRunner.findWhisperCliPath(in: bundle)
        }
    }

    func availableWhisperCliPath() -> String? {
        whisperCliPathProvider()
    }

    private static func findWhisperCliPath(in bundle: Bundle) -> String? {
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
        guard let modelPath = modelPathProvider() else {
            cleanupTemporaryFiles(audioPath: audioPath)
            return .failure(.modelMissing)
        }

        guard let whisperCli = whisperCliPathProvider() else {
            cleanupTemporaryFiles(audioPath: audioPath)
            return .failure(.whisperMissing)
        }

        let task = Process()
        let stderrPipe = Pipe()
        let terminationSemaphore = DispatchSemaphore(value: 0)

        task.launchPath = whisperCli
        task.arguments = ["-m", modelPath, "-f", audioPath, "-l", "ru", "-nt", "-otxt"]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = stderrPipe
        task.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        do {
            try task.run()

            if terminationSemaphore.wait(timeout: dispatchDeadline(after: timeoutSeconds)) == .timedOut {
                stopTimedOutProcess(task, terminationSemaphore: terminationSemaphore)
                task.terminationHandler = nil
                cleanupTemporaryFiles(audioPath: audioPath)
                return .failure(.timedOut(timeoutSeconds))
            }

            task.terminationHandler = nil

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
            task.terminationHandler = nil
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

    private func stopTimedOutProcess(_ task: Process, terminationSemaphore: DispatchSemaphore) {
        if task.isRunning {
            task.terminate()
        }

        if terminationSemaphore.wait(timeout: dispatchDeadline(after: terminationGraceSeconds)) == .success {
            return
        }

        if task.isRunning {
            kill(task.processIdentifier, SIGKILL)
            _ = terminationSemaphore.wait(timeout: dispatchDeadline(after: 1))
        }
    }

    private func dispatchDeadline(after seconds: TimeInterval) -> DispatchTime {
        let milliseconds = max(0, Int(seconds * 1000))
        return .now() + .milliseconds(milliseconds)
    }
}
