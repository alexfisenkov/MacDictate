import Foundation

enum TextImprovementOutputCleaner {
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

        cleaned = extractOutputFromLeakedPromptScaffold(cleaned)
        cleaned = removeStandaloneMarkdownRuleLines(cleaned)

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
}
