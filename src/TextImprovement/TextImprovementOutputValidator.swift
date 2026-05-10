import Foundation

struct TextImprovementValidatedOutput {
    let cleanedCandidateOutput: String
    let cleanedOutput: String
    let finalOutput: String
    let validationFallbackReason: String?
}

enum TextImprovementOutputValidator {
    static func validateModelOutput(
        rawOutput: String,
        outputWasTruncated: Bool,
        source: String
    ) -> TextImprovementValidatedOutput {
        if outputWasTruncated {
            let finalOutput = TextImprovementFormatter.normalize(source)
            return TextImprovementValidatedOutput(
                cleanedCandidateOutput: source,
                cleanedOutput: source,
                finalOutput: finalOutput,
                validationFallbackReason: "output_truncated"
            )
        }

        let cleanedOutput = TextImprovementOutputCleaner.cleanModelOutput(rawOutput)
        let markdownAdjustedOutput = TextImprovementOutputCleaner.stripDecorativeMarkdownIfSourceWasPlain(
            cleanedOutput,
            source: source
        )
        var validationFallbackReason: String?
        let guardedOutput = fallbackToSourceIfOutputLooksLikeEditorialCommentary(
            markdownAdjustedOutput,
            source: source
        )
        if sameTrimmedText(guardedOutput, source),
           !sameTrimmedText(markdownAdjustedOutput, source) {
            validationFallbackReason = "editorial_commentary"
        }

        let contentPreservingOutput: String
        if let reason = nonConservativeCorrectionReason(guardedOutput, source: source) {
            validationFallbackReason = reason
            contentPreservingOutput = source.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            contentPreservingOutput = guardedOutput
        }

        return TextImprovementValidatedOutput(
            cleanedCandidateOutput: markdownAdjustedOutput,
            cleanedOutput: contentPreservingOutput,
            finalOutput: TextImprovementFormatter.normalize(contentPreservingOutput),
            validationFallbackReason: validationFallbackReason
        )
    }

    static func shouldRetryAfterValidationFallback(_ reason: String) -> Bool {
        let retryableReasons: Set<String> = [
            "editorial_commentary",
            "unexpected_list_format",
            "extra_ordered_list_item",
            "critical_tokens_missing",
            "source_content_dropped",
            "source_tokens_not_preserved",
            "new_content_added",
            "short_answer_expansion",
            "appended_new_content"
        ]
        return retryableReasons.contains(reason)
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
            "для дальнейшей работы",
            "я считаю",
            "я думаю",
            "я отношусь",
            "важно помнить",
            "рекомендую",
            "советую",
            "вы можете",
            "давайте рассмотрим",
            "ответ на ваш вопрос"
        ]

        let hasAddedEditorialCommentary = editorialMarkers.contains { marker in
            normalizedOutput.contains(marker) && !normalizedSource.contains(marker)
        }

        return hasAddedEditorialCommentary ? trimmedSource : output
    }

    static func fallbackToSourceIfOutputIsNotConservativeCorrection(_ output: String, source: String) -> String {
        if nonConservativeCorrectionReason(output, source: source) != nil {
            return source.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return output
    }

    private static func nonConservativeCorrectionReason(_ output: String, source: String) -> String? {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty, !trimmedSource.isEmpty else {
            return nil
        }

        let sourceTokens = significantTokens(in: trimmedSource)
        let sourceTokenCount = sourceTokens.count
        guard sourceTokenCount >= 3 else {
            return nil
        }

        if outputIntroducesUnexpectedList(output: trimmedOutput, source: trimmedSource) {
            return "unexpected_list_format"
        }

        if outputAddsUnexpectedOrderedListItem(output: trimmedOutput, source: trimmedSource) {
            return "extra_ordered_list_item"
        }

        let sourceCriticalTokens = criticalTokens(in: trimmedSource)
        if !sourceCriticalTokens.isEmpty {
            let outputCriticalTokens = Set(criticalTokens(in: trimmedOutput))
            let missingCriticalTokens = sourceCriticalTokens.filter { !outputCriticalTokens.contains($0) }
            if !missingCriticalTokens.isEmpty {
                return "critical_tokens_missing"
            }
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

        let extraCount = outputTokenCounts.values.reduce(0, +)
        let missingRatio = Double(missingCount) / Double(sourceTokenCount)
        let extraRatio = Double(extraCount) / Double(sourceTokenCount)
        let lengthRatio = Double(trimmedOutput.count) / Double(trimmedSource.count)
        let likelyContentDropped = sourceTokenCount >= 12 && missingCount >= 6 && missingRatio >= 0.10 && lengthRatio < 0.95
        if likelyContentDropped {
            return "source_content_dropped"
        }

        let likelyAnsweredOrRewritten = sourceTokenCount >= 4 && missingCount >= 4 && missingRatio >= 0.30
        if likelyAnsweredOrRewritten {
            return "source_tokens_not_preserved"
        }

        let likelyExpandedWithNewContent = sourceTokenCount >= 4
            && extraCount >= max(6, Int((Double(sourceTokenCount) * 0.40).rounded(.up)))
            && extraRatio >= 0.35
            && lengthRatio >= 1.35
        if likelyExpandedWithNewContent {
            return "new_content_added"
        }

        let likelyShortAnswerExpansion = sourceTokenCount < 12
            && extraCount >= max(6, sourceTokenCount)
            && lengthRatio >= 1.75
        if likelyShortAnswerExpansion {
            return "short_answer_expansion"
        }

        let likelyAppendedAnswer = missingCount <= max(1, Int((Double(sourceTokenCount) * 0.05).rounded(.up)))
            && extraCount >= max(8, Int((Double(sourceTokenCount) * 0.50).rounded(.up)))
            && lengthRatio >= 1.50
        if likelyAppendedAnswer {
            return "appended_new_content"
        }

        return nil
    }

    private static func normalizeForCommentaryDetection(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
            .lowercased()
    }

    private static func sameTrimmedText(_ lhs: String, _ rhs: String) -> Bool {
        lhs.trimmingCharacters(in: .whitespacesAndNewlines) == rhs.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func criticalTokens(in text: String) -> Set<String> {
        let pattern = #"https?://\S+|[\w.%+-]+@[\w.-]+\.[A-Za-z]{2,}|[A-Za-zА-Яа-яЁё]*\d[\w.%/:+-]*"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return Set(regex.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "ru_RU"))
                .lowercased()
                .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?()[]{}\"'"))
        }.filter { !$0.isEmpty })
    }

    private static func outputIntroducesUnexpectedList(output: String, source: String) -> Bool {
        guard hasListMarkers(output) else { return false }
        return !hasListMarkers(source) && !hasListCue(source)
    }

    private static func outputAddsUnexpectedOrderedListItem(output: String, source: String) -> Bool {
        let outputMaxIndex = orderedListIndexes(in: output).max() ?? 0
        guard outputMaxIndex > 0 else { return false }

        let sourceMaxIndex = max(orderedListIndexes(in: source).max() ?? 0, expectedOrderedListCount(from: source))
        guard sourceMaxIndex > 0 else { return false }

        return outputMaxIndex > sourceMaxIndex
    }

    private static func orderedListIndexes(in text: String) -> [Int] {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^\s*(\d+)[\.)]\s+"#) else {
            return []
        }

        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, range: nsRange).compactMap { match in
            guard match.numberOfRanges >= 2,
                  let range = Range(match.range(at: 1), in: text) else {
                return nil
            }
            return Int(text[range])
        }
    }

    private static func expectedOrderedListCount(from text: String) -> Int {
        let normalized = normalizeForCommentaryDetection(text).replacingOccurrences(of: "ё", with: "е")
        let markers: [(patterns: [String], count: Int)] = [
            (["десятое", "в-десятых", "в десятых"], 10),
            (["девятое", "в-девятых", "в девятых"], 9),
            (["восьмое", "в-восьмых", "в восьмых"], 8),
            (["седьмое", "в-седьмых", "в седьмых"], 7),
            (["шестое", "в-шестых", "в шестых"], 6),
            (["пятое", "в-пятых", "в пятых"], 5),
            (["четвертое", "в-четвертых", "в четвертых"], 4),
            (["третье", "в-третьих", "в третьих", "есть три"], 3),
            (["второе", "во-вторых", "во вторых"], 2),
            (["первое", "во-первых", "во первых"], 1)
        ]

        return markers.first { marker in
            marker.patterns.contains { normalized.contains($0) }
        }?.count ?? 0
    }

    private static func hasListMarkers(_ text: String) -> Bool {
        text.range(
            of: #"(?m)^\s*(?:[-*•]\s+|\d+[\.)]\s+)"#,
            options: .regularExpression
        ) != nil
    }

    private static func hasListCue(_ text: String) -> Bool {
        let normalized = normalizeForCommentaryDetection(text).replacingOccurrences(of: "ё", with: "е")
        let cues = [
            "во-первых", "во первых", "во-вторых", "во вторых", "в-третьих", "в третьих",
            "первое", "второе", "третье", "пункт первый", "пункт второй",
            "раз, два", "есть три", "есть несколько", "несколько вариантов",
            "несколько причин", "несколько вещей", "перечислю", "список",
            "сюда входит", "нам нужно", "важно сделать"
        ]
        return cues.contains { normalized.contains($0) }
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
}
