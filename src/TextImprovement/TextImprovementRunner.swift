import Foundation

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

final class TextImprovementRunner {
    private static let defaultTimeoutSeconds: TimeInterval = 600
    private static let defaultTerminationGraceSeconds: TimeInterval = 2
    private static let defaultOutputLimitBytes = 131_072
    private static let maximumInputCharacters = 6_000

    private let profile: TextImprovementProfile
    private let runtime: LlamaCompletionRuntime
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
        self.profile = profile
        self.runtime = LlamaCompletionRuntime(
            timeoutSeconds: timeoutSeconds,
            terminationGraceSeconds: terminationGraceSeconds,
            outputLimitBytes: outputLimitBytes
        )
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
        LlamaCompletionRuntime.findRuntimePath(in: bundle)
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
                validationFallbackReason: nil,
                retryTriggerReason: nil,
                initialRawOutput: nil,
                initialCleanedOutput: nil,
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

        let initialRun: TextImprovementModelRun
        switch runtime.run(prompt: prompt, modelPath: modelPath, runtimePath: llamaCli, tokenBasis: input) {
        case .success(let run):
            initialRun = run
        case .failure(let error):
            return .failure(error)
        }

        let initialValidation = TextImprovementOutputValidator.validateModelOutput(
            rawOutput: initialRun.rawOutput,
            outputWasTruncated: initialRun.outputWasTruncated,
            source: preparedInput
        )

        if let reason = initialValidation.validationFallbackReason,
           TextImprovementOutputValidator.shouldRetryAfterValidationFallback(reason) {
            let retryPrompt = profile.retryPrompt(
                for: preparedInput,
                rejectedOutput: initialValidation.cleanedCandidateOutput,
                validationReason: reason
            )

            if case .success(let retryRun) = runtime.run(
                prompt: retryPrompt,
                modelPath: modelPath,
                runtimePath: llamaCli,
                tokenBasis: input
            ) {
                let retryValidation = TextImprovementOutputValidator.validateModelOutput(
                    rawOutput: retryRun.rawOutput,
                    outputWasTruncated: retryRun.outputWasTruncated,
                    source: preparedInput
                )

                if !retryValidation.finalOutput.isEmpty {
                    let trace = TextImprovementTrace(
                        input: input,
                        preparedInput: preparedInput,
                        prompt: retryRun.prompt,
                        rawOutput: retryRun.rawOutput,
                        cleanedOutput: retryValidation.cleanedOutput,
                        finalOutput: retryValidation.finalOutput,
                        validationFallbackReason: retryValidation.validationFallbackReason,
                        retryTriggerReason: reason,
                        initialRawOutput: initialRun.rawOutput,
                        initialCleanedOutput: initialValidation.cleanedCandidateOutput,
                        modelPath: modelPath,
                        runtimePath: llamaCli,
                        arguments: retryRun.arguments
                    )
                    return .success(TextImprovementOutput(text: retryValidation.finalOutput, trace: trace))
                }
            }
        }

        guard !initialValidation.finalOutput.isEmpty else {
            return .failure(.outputMissing)
        }

        let trace = TextImprovementTrace(
            input: input,
            preparedInput: preparedInput,
            prompt: initialRun.prompt,
            rawOutput: initialRun.rawOutput,
            cleanedOutput: initialValidation.cleanedOutput,
            finalOutput: initialValidation.finalOutput,
            validationFallbackReason: initialValidation.validationFallbackReason,
            retryTriggerReason: nil,
            initialRawOutput: nil,
            initialCleanedOutput: nil,
            modelPath: modelPath,
            runtimePath: llamaCli,
            arguments: initialRun.arguments
        )
        return .success(TextImprovementOutput(text: initialValidation.finalOutput, trace: trace))
    }

    static func cleanModelOutput(_ output: String) -> String {
        TextImprovementOutputCleaner.cleanModelOutput(output)
    }

    static func stripDecorativeMarkdownIfSourceWasPlain(_ output: String, source: String) -> String {
        TextImprovementOutputCleaner.stripDecorativeMarkdownIfSourceWasPlain(output, source: source)
    }

    static func fallbackToSourceIfOutputLooksLikeEditorialCommentary(_ output: String, source: String) -> String {
        TextImprovementOutputValidator.fallbackToSourceIfOutputLooksLikeEditorialCommentary(output, source: source)
    }

    static func fallbackToSourceIfOutputIsNotConservativeCorrection(_ output: String, source: String) -> String {
        TextImprovementOutputValidator.fallbackToSourceIfOutputIsNotConservativeCorrection(output, source: source)
    }
}
