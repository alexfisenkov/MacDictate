import Foundation
import Darwin

enum TextImprovementFailure: LocalizedError {
    case modelMissing
    case llamaCliMissing
    case inputTooLong(Int)
    case promptWriteFailed(String)
    case launchFailed(String)
    case nonZeroExit(Int32, String)
    case outputMissing
    case timedOut(TimeInterval)

    var errorDescription: String? {
        switch self {
        case .modelMissing:
            return "Модель улучшения текста не найдена."
        case .llamaCliMissing:
            return "Не найден llama.cpp runtime для локального улучшения текста."
        case .inputTooLong(let limit):
            return "Текст слишком длинный для безопасного улучшения второй нейросетью (лимит \(limit) символов)."
        case .promptWriteFailed(let detail):
            return "Не удалось подготовить текст для улучшения: \(detail)"
        case .launchFailed(let detail):
            return "Не удалось запустить llama.cpp runtime: \(detail)"
        case .nonZeroExit(let code, let detail):
            if detail.isEmpty {
                return "llama.cpp runtime завершился с ошибкой (код \(code))."
            }
            return "llama.cpp runtime завершился с ошибкой (код \(code)): \(detail)"
        case .outputMissing:
            return "Модель улучшения текста не вернула результат."
        case .timedOut(let timeout):
            return "Улучшение текста не завершилось за \(Self.formatDuration(timeout)). MacDictate остановил зависший процесс."
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

struct TextImprovementOutput {
    let text: String
    let trace: TextImprovementTrace
}

struct TextImprovementTrace {
    let input: String
    let preparedInput: String
    let prompt: String
    let rawOutput: String
    let cleanedOutput: String
    let finalOutput: String
    let modelPath: String
    let runtimePath: String
    let arguments: [String]
}

final class TextImprovementRunner {
    private static let defaultTimeoutSeconds: TimeInterval = 600
    private static let defaultTerminationGraceSeconds: TimeInterval = 2
    private static let defaultOutputLimitBytes = 131_072
    private static let contextTokens = 8_192
    private static let maximumInputCharacters = 6_000

    private let timeoutSeconds: TimeInterval
    private let terminationGraceSeconds: TimeInterval
    private let outputLimitBytes: Int
    private let profile: TextImprovementProfile
    private let modelPathProvider: () -> String?
    private let llamaCliPathProvider: () -> String?

    init(
        bundle: Bundle = .main,
        timeoutSeconds: TimeInterval = TextImprovementRunner.defaultTimeoutSeconds,
        terminationGraceSeconds: TimeInterval = TextImprovementRunner.defaultTerminationGraceSeconds,
        outputLimitBytes: Int = TextImprovementRunner.defaultOutputLimitBytes,
        profile: TextImprovementProfile = .professionalCopyEditor,
        modelPathProvider: (() -> String?)? = nil,
        llamaCliPathProvider: (() -> String?)? = nil
    ) {
        self.timeoutSeconds = timeoutSeconds
        self.terminationGraceSeconds = terminationGraceSeconds
        self.outputLimitBytes = outputLimitBytes
        self.profile = profile
        self.modelPathProvider = modelPathProvider ?? {
            ModelLocator.bestAvailableTextImprovementModelPath()
        }
        self.llamaCliPathProvider = llamaCliPathProvider ?? {
            TextImprovementRunner.findLlamaCliPath(in: bundle)
        }
    }

    func availableModelPath() -> String? {
        modelPathProvider()
    }

    func availableLlamaCliPath() -> String? {
        llamaCliPathProvider()
    }

    static func findLlamaCliPath(in bundle: Bundle) -> String? {
        var candidates: [String] = []
        if let resourcePath = bundle.resourcePath {
            candidates.append(resourcePath + "/bin/llama-completion")
            candidates.append(resourcePath + "/bin/llama-cli")
        }
        candidates.append("/opt/homebrew/bin/llama-completion")
        candidates.append("/opt/homebrew/bin/llama-cli")
        candidates.append("/usr/local/bin/llama-completion")
        candidates.append("/usr/local/bin/llama-cli")

        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }

        return nil
    }

    func improve(_ text: String) -> Result<String, TextImprovementFailure> {
        improveWithTrace(text).map { $0.text }
    }

    func improveWithTrace(_ text: String) -> Result<TextImprovementOutput, TextImprovementFailure> {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else {
            let trace = TextImprovementTrace(
                input: "",
                preparedInput: "",
                prompt: "",
                rawOutput: "",
                cleanedOutput: "",
                finalOutput: "",
                modelPath: "",
                runtimePath: "",
                arguments: []
            )
            return .success(TextImprovementOutput(text: "", trace: trace))
        }

        guard input.count <= Self.maximumInputCharacters else {
            return .failure(.inputTooLong(Self.maximumInputCharacters))
        }

        guard let modelPath = modelPathProvider() else {
            return .failure(.modelMissing)
        }

        guard let llamaCli = llamaCliPathProvider() else {
            return .failure(.llamaCliMissing)
        }

        let preparedInput = TextImprovementFormatter.normalize(input)
        let prompt = profile.prompt(for: preparedInput)
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
            "-n", "\(Self.maxGeneratedTokens(for: input))",
            "--temp", "0.1",
            "--top-p", "0.9",
            "--no-display-prompt",
            "-no-cnv",
            "-ngl", "99"
        ]
        task.launchPath = llamaCli
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

            let rawOutput = stdoutCollector.text()
            let cleanedOutput = Self.cleanModelOutput(rawOutput)
            let markdownAdjustedOutput = Self.stripDecorativeMarkdownIfSourceWasPlain(
                cleanedOutput,
                source: preparedInput
            )
            let guardedOutput = Self.fallbackToSourceIfOutputLooksLikeEditorialCommentary(
                markdownAdjustedOutput,
                source: preparedInput
            )
            let contentPreservingOutput = Self.fallbackToSourceIfOutputDropsSourceContent(
                guardedOutput,
                source: preparedInput
            )
            let improved = TextImprovementFormatter.normalize(contentPreservingOutput)
            guard !improved.isEmpty else {
                return .failure(.outputMissing)
            }

            let trace = TextImprovementTrace(
                input: input,
                preparedInput: preparedInput,
                prompt: prompt,
                rawOutput: rawOutput,
                cleanedOutput: contentPreservingOutput,
                finalOutput: improved,
                modelPath: modelPath,
                runtimePath: llamaCli,
                arguments: arguments
            )
            return .success(TextImprovementOutput(text: improved, trace: trace))
        } catch {
            stdoutHandle.readabilityHandler = nil
            stderrHandle.readabilityHandler = nil
            task.terminationHandler = nil
            return .failure(.launchFailed(error.localizedDescription))
        }
    }

    static func cleanModelOutput(_ output: String) -> String {
        var cleaned = output
            .replacingOccurrences(of: "<|im_end|>", with: "")
            .replacingOccurrences(of: "<|endoftext|>", with: "")
            .replacingOccurrences(of: "[end of text]", with: "")
            .replacingOccurrences(of: "```text", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let removablePrefixes = [
            "Исправленный текст:",
            "Улучшенный текст:",
            "Исправленный и отформатированный текст:",
            "Вот исправленный текст:",
            "Вот улучшенный текст:",
            "Вот исправленный и отформатированный текст:",
            "Отредактированный текст:",
            "Готовый текст:",
            "Corrected text:",
            "Improved text:"
        ]

        for prefix in removablePrefixes {
            if cleaned.localizedCaseInsensitiveContains(prefix),
               let range = cleaned.range(of: prefix, options: [.caseInsensitive, .anchored]) {
                cleaned.removeSubrange(range)
                cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        cleaned = Self.extractOutputFromLeakedPromptScaffold(cleaned)
        cleaned = Self.removeStandaloneMarkdownRuleLines(cleaned)

        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func stripDecorativeMarkdownIfSourceWasPlain(_ output: String, source: String) -> String {
        guard !source.contains("**"),
              !source.contains("__"),
              !source.contains("`") else {
            return output
        }

        return output
            .replacingOccurrences(
                of: #"\*\*([^*\n]+)\*\*"#,
                with: "$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"__([^_\n]+)__"#,
                with: "$1",
                options: .regularExpression
            )
            .replacingOccurrences(
                of: #"`([^`\n]+)`"#,
                with: "$1",
                options: .regularExpression
            )
    }

    static func fallbackToSourceIfOutputLooksLikeEditorialCommentary(_ output: String, source: String) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty, !trimmedSource.isEmpty else {
            return output
        }

        let normalizedOutput = normalizeForCommentaryDetection(trimmedOutput)
        let normalizedSource = normalizeForCommentaryDetection(trimmedSource)
        let editorialMarkers = [
            "ваш текст уже",
            "ваш запрос",
            "ваш фрагмент",
            "ваше сообщение",
            "можно переписать следующим образом",
            "переписать следующим образом",
            "исправления:",
            "текст выглядит следующим образом:",
            "текст выглядит так:",
            "текст сохранен",
            "текст сохранён",
            "стиль автора сохран",
            "язык и стиль автора",
            "исходном формате",
            "готовый вариант:",
            "итоговый текст:",
            "исправленная версия:",
            "отредактированная версия:",
            "ниже исправленный текст:",
            "ниже улучшенный текст:",
            "я исправил",
            "я отредактировал",
            "конечно, я могу помочь",
            "я могу помочь с редактированием",
            "пожалуйста, предоставьте",
            "пожалуйста, пришлите",
            "предоставьте фрагмент текста",
            "предоставьте исходный текст",
            "пришлите фрагмент текста",
            "пришлите исходный текст",
            "фрагмент текста, который вам нужно обработать",
            "затрудняет редактирование",
            "для дальнейшей работы"
        ]

        let hasAddedEditorialCommentary = editorialMarkers.contains { marker in
            normalizedOutput.contains(marker) && !normalizedSource.contains(marker)
        }

        return hasAddedEditorialCommentary ? trimmedSource : output
    }

    static func fallbackToSourceIfOutputDropsSourceContent(_ output: String, source: String) -> String {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty, !trimmedSource.isEmpty else {
            return output
        }

        let sourceTokens = significantTokens(in: trimmedSource)
        guard sourceTokens.count >= 12 else {
            return output
        }

        var outputTokenCounts: [String: Int] = [:]
        for token in significantTokens(in: trimmedOutput) {
            outputTokenCounts[token, default: 0] += 1
        }

        var missingCount = 0
        for token in sourceTokens {
            if let count = outputTokenCounts[token], count > 0 {
                outputTokenCounts[token] = count - 1
            } else {
                missingCount += 1
            }
        }

        let missingRatio = Double(missingCount) / Double(sourceTokens.count)
        let lengthRatio = Double(trimmedOutput.count) / Double(trimmedSource.count)
        let likelyContentDropped = missingCount >= 6 && missingRatio >= 0.10 && lengthRatio < 0.95

        return likelyContentDropped ? trimmedSource : output
    }

    private static func extractOutputFromLeakedPromptScaffold(_ output: String) -> String {
        let outputMarkers = [
            "Выход:",
            "Результат:",
            "Исправленный текст:",
            "Улучшенный текст:",
            "Output:",
            "Corrected text:",
            "Improved text:"
        ]

        for marker in outputMarkers {
            if let range = output.range(of: marker, options: [.caseInsensitive, .backwards]) {
                let extracted = String(output[range.upperBound...])
                    .split(separator: "\n", omittingEmptySubsequences: false)
                    .map { line in
                        String(line).replacingOccurrences(
                            of: #"^\s*[-*]\s+"#,
                            with: "",
                            options: .regularExpression
                        )
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)

                if !extracted.isEmpty {
                    return extracted
                }
            }
        }

        return output
    }

    private static func normalizeForCommentaryDetection(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .lowercased()
    }

    private static func significantTokens(in text: String) -> [String] {
        let normalized = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .lowercased()
        let separators = CharacterSet.alphanumerics.inverted
        return normalized
            .components(separatedBy: separators)
            .filter { token in
                token.count >= 3 || token.rangeOfCharacter(from: .decimalDigits) != nil
            }
    }

    private static func removeStandaloneMarkdownRuleLines(_ output: String) -> String {
        output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.range(of: #"^[-*_]{3,}$"#, options: .regularExpression) == nil
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
}
