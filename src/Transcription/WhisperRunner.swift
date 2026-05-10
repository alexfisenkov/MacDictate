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
            return "Распознавание не завершилось за \(Self.formatDuration(timeout)). MacDictate остановил зависший процесс."
        }
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let roundedSeconds = max(0, Int(seconds.rounded()))
        if roundedSeconds >= 60, roundedSeconds % 60 == 0 {
            return "\(roundedSeconds / 60) мин"
        }
        return "\(roundedSeconds) сек"
    }
}

final class WhisperRunner {
    private static let defaultTimeoutSeconds: TimeInterval = 1_800
    private static let defaultTerminationGraceSeconds: TimeInterval = 2
    private static let defaultStderrLimitBytes = 16_384

    private let timeoutSeconds: TimeInterval
    private let terminationGraceSeconds: TimeInterval
    private let stderrLimitBytes: Int
    private let modelPathProvider: () -> String?
    private let whisperCliPathProvider: () -> String?

    init(
        bundle: Bundle = .main,
        timeoutSeconds: TimeInterval = WhisperRunner.defaultTimeoutSeconds,
        terminationGraceSeconds: TimeInterval = WhisperRunner.defaultTerminationGraceSeconds,
        stderrLimitBytes: Int = WhisperRunner.defaultStderrLimitBytes,
        modelPathProvider: (() -> String?)? = nil,
        whisperCliPathProvider: (() -> String?)? = nil
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.terminationGraceSeconds = terminationGraceSeconds
        self.stderrLimitBytes = stderrLimitBytes
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
        let stderrHandle = stderrPipe.fileHandleForReading
        let stderrCollector = ProcessOutputCollector(limitBytes: stderrLimitBytes)
        let terminationSemaphore = DispatchSemaphore(value: 0)

        task.launchPath = whisperCli
        task.arguments = ["-m", modelPath, "-f", audioPath, "-l", "ru", "-nt", "-otxt"]
        if let backendPath = Self.bundledGGMLBackendPath(forWhisperCli: whisperCli) {
            var environment = ProcessInfo.processInfo.environment
            environment["GGML_BACKEND_PATH"] = backendPath
            task.environment = environment
        }
        task.standardOutput = FileHandle.nullDevice
        task.standardError = stderrPipe
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stderrCollector.append(data)
        }
        task.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        do {
            try task.run()

            if terminationSemaphore.wait(timeout: dispatchDeadline(after: timeoutSeconds)) == .timedOut {
                stopTimedOutProcess(task, terminationSemaphore: terminationSemaphore)
                stderrHandle.readabilityHandler = nil
                task.terminationHandler = nil
                cleanupTemporaryFiles(audioPath: audioPath)
                return .failure(.timedOut(timeoutSeconds))
            }

            stderrHandle.readabilityHandler = nil
            task.terminationHandler = nil

            stderrCollector.append(stderrHandle.readDataToEndOfFile())
            let stderrText = stderrCollector.text()

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
            stderrHandle.readabilityHandler = nil
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

    private static func bundledGGMLBackendPath(forWhisperCli whisperCli: String) -> String? {
        let cliURL = URL(fileURLWithPath: whisperCli)
        let resourcesURL = cliURL.deletingLastPathComponent().deletingLastPathComponent()
        guard resourcesURL.lastPathComponent == "Resources" else {
            return nil
        }

        let backendURL = resourcesURL.appendingPathComponent("libexec/ggml", isDirectory: true)
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: backendURL.path, isDirectory: &isDirectory), isDirectory.boolValue {
            return backendURL.path
        }

        return nil
    }
}

private final class ProcessOutputCollector {
    private let limitBytes: Int
    private let queue = DispatchQueue(label: "com.alexfisenkov.macdictate.process-output")
    private var buffer = Data()
    private var truncated = false

    init(limitBytes: Int) {
        self.limitBytes = max(0, limitBytes)
    }

    func append(_ data: Data) {
        guard !data.isEmpty else { return }

        queue.sync {
            guard buffer.count < limitBytes else {
                truncated = true
                return
            }

            let remaining = limitBytes - buffer.count
            if data.count <= remaining {
                buffer.append(data)
            } else {
                buffer.append(data.prefix(remaining))
                truncated = true
            }
        }
    }

    func text() -> String {
        queue.sync {
            var text = String(data: buffer, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if truncated {
                let suffix = "[stderr truncated]"
                text = text.isEmpty ? suffix : "\(text)\n\(suffix)"
            }

            return text
        }
    }
}
