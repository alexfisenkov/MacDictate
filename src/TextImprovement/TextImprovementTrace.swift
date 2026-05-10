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
    let validationFallbackReason: String?
    let retryTriggerReason: String?
    let initialRawOutput: String?
    let initialCleanedOutput: String?
    let modelPath: String
    let runtimePath: String
    let arguments: [String]
}
