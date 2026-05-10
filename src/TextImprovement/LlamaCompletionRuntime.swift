import Foundation
import Darwin

struct TextImprovementModelRun {
    let prompt: String
    let rawOutput: String
    let outputWasTruncated: Bool
    let arguments: [String]
}

final class LlamaCompletionRuntime {
    private static let contextTokens = 8_192

    private let timeoutSeconds: TimeInterval
    private let terminationGraceSeconds: TimeInterval
    private let outputLimitBytes: Int

    init(
        timeoutSeconds: TimeInterval,
        terminationGraceSeconds: TimeInterval,
        outputLimitBytes: Int
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.terminationGraceSeconds = terminationGraceSeconds
        self.outputLimitBytes = outputLimitBytes
    }

    static func findRuntimePath(in bundle: Bundle) -> String? {
        LlamaRuntimeLocator.findRuntimePath(in: bundle)
    }

    func run(
        prompt: String,
        modelPath: String,
        runtimePath: String,
        tokenBasis: String
    ) -> Result<TextImprovementModelRun, TextImprovementFailure> {
        let promptPath: String
        do {
            promptPath = try writePromptFile(prompt)
        } catch {
            return .failure(.promptWriteFailed(error.localizedDescription))
        }
        defer { try? FileManager.default.removeItem(atPath: promptPath) }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutHandle = stdoutPipe.fileHandleForReading
        let stderrHandle = stderrPipe.fileHandleForReading
        let stdoutCollector = TextProcessOutputCollector(limitBytes: outputLimitBytes)
        let stderrCollector = TextProcessOutputCollector(limitBytes: 16_384)
        let terminationSemaphore = DispatchSemaphore(value: 0)

        let task = Process()
        let arguments = [
            "-m", modelPath,
            "-f", promptPath,
            "-c", "\(Self.contextTokens)",
            "-n", "\(Self.maxGeneratedTokens(for: tokenBasis))",
            "--temp", "0.1",
            "--top-p", "0.9",
            "--no-display-prompt",
            "-no-cnv",
            "-ngl", "99"
        ]
        task.launchPath = runtimePath
        task.arguments = arguments
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            stdoutCollector.append(data)
        }
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
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil
                task.terminationHandler = nil
                return .failure(.timedOut(timeoutSeconds))
            }

            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            task.terminationHandler = nil

            stdoutCollector.append(stdoutHandle.readDataToEndOfFile())
            stderrCollector.append(stderrHandle.readDataToEndOfFile())

            let stderrText = stderrCollector.text()
            guard task.terminationStatus == 0 else {
                return .failure(.nonZeroExit(task.terminationStatus, stderrText))
            }

            return .success(TextImprovementModelRun(
                prompt: prompt,
                rawOutput: stdoutCollector.text(),
                outputWasTruncated: stdoutCollector.wasTruncated(),
                arguments: arguments
            ))
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            task.terminationHandler = nil
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    private func writePromptFile(_ prompt: String) throws -> String {
        let promptURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("macdictate-text-improvement-\(UUID().uuidString).txt")
        try prompt.write(to: promptURL, atomically: true, encoding: .utf8)
        return promptURL.path
    }

    private static func maxGeneratedTokens(for input: String) -> Int {
        let estimatedTokens = input.unicodeScalars.count / 3
        return min(2_048, max(256, estimatedTokens + 128))
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

private final class TextProcessOutputCollector {
    private let limitBytes: Int
    private let queue = DispatchQueue(label: "com.alexfisenkov.macdictate.text-process-output")
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
                let suffix = "[output truncated]"
                text = text.isEmpty ? suffix : "\(text)\n\(suffix)"
            }

            return text
        }
    }

    func wasTruncated() -> Bool {
        queue.sync {
            truncated
        }
    }
}
