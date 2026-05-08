import Foundation

enum TextImprovementFormatter {
    private static let commonTerminologyReplacements: [(from: String, to: String)] = [
        ("Adobe Premier Pro", "Adobe Premiere Pro"),
        ("премьер про", "Adobe Premiere Pro"),
        ("давинчи резолв", "DaVinci Resolve"),
        ("файн кат про", "Final Cut Pro"),
        ("Syntax AI", "Syntx AI"),
        ("SyntaxAI", "Syntx AI"),
        ("Синтакс AI", "Syntx AI"),
        ("синтакс ай", "Syntx AI"),
        ("Chat GPT", "ChatGPT"),
        ("ChagPT", "ChatGPT"),
        ("ChagGPT", "ChatGPT"),
        ("ChagJPT", "ChatGPT"),
        ("Chag GPT", "ChatGPT"),
        ("Chag JPT", "ChatGPT"),
        ("ChaiJPT", "ChatGPT"),
        ("ChaiGPT", "ChatGPT"),
        ("Chai JPT", "ChatGPT"),
        ("Chai GPT", "ChatGPT"),
        ("Chai-GPT", "ChatGPT"),
        ("Чай и GPT", "ChatGPT"),
        ("чай gpt", "ChatGPT"),
        ("чай джипити", "ChatGPT"),
        ("чайджипити", "ChatGPT"),
        ("чат джипити", "ChatGPT"),
        ("чат джпт", "ChatGPT"),
        ("чат gpt", "ChatGPT"),
        ("Cloud от Anthropic", "Claude от Anthropic"),
        ("Cloud Anthropic", "Claude Anthropic"),
        ("Клод от Anthropic", "Claude от Anthropic"),
        ("Клод Anthropic", "Claude Anthropic"),
        ("контент план", "контент-план"),
        ("миджорни", "Midjourney"),
        ("капкат", "CapCut"),
        ("фигма", "Figma"),
        ("ебитда", "EBITDA"),
        ("qwen", "Qwen"),
        ("ebitda", "EBITDA")
    ]

    private static let orderedMarkers: [(pattern: String, canonicalIndex: Int)] = [
        ("во[-\\s]?первых", 1),
        ("во[-\\s]?вторых", 2),
        ("в[-\\s]?третьих", 3),
        ("в[-\\s]?четвертых", 4),
        ("в[-\\s]?четвёртых", 4),
        ("первое", 1),
        ("второе", 2),
        ("третье", 3),
        ("четвертое", 4),
        ("четвёртое", 4)
    ]

    static func normalize(_ text: String) -> String {
        formatObviousOrderedEnumeration(normalizeCommonTerminology(text))
    }

    static func formatObviousOrderedEnumeration(_ text: String) -> String {
        let trimmed = normalizeCommonTerminology(text).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return text }

        let matches = orderedMarkerMatches(in: trimmed)
        guard matches.count >= 2,
              let firstMatch = matches.first else {
            return text
        }

        let intro = String(trimmed[..<firstMatch.range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        var items: [String] = []

        for index in matches.indices {
            let contentStart = matches[index].range.upperBound
            let contentEnd = index + 1 < matches.count
                ? matches[index + 1].range.lowerBound
                : trimmed.endIndex
            let item = String(trimmed[contentStart..<contentEnd])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !item.isEmpty {
                items.append(sentenceCasedWithPeriod(item))
            }
        }

        guard items.count >= 2 else {
            return text
        }

        var sections = introSections(for: intro)

        let list = items.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        sections.append(list)

        return sections.joined(separator: "\n\n")
    }

    private static func orderedMarkerMatches(in text: String) -> [(range: Range<String.Index>, canonicalIndex: Int)] {
        orderedMarkers.flatMap { marker -> [(range: Range<String.Index>, canonicalIndex: Int)] in
            guard let regex = try? NSRegularExpression(
                pattern: "(?i)(^|[\\s,.;:])((?:ну,?\\s+а\\s+|а\\s+|и\\s+)?\(marker.pattern))(?=[\\s,.;:])",
                options: []
            ) else {
                return []
            }

            let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
            return regex.matches(in: text, options: [], range: nsRange).compactMap { match in
                guard match.numberOfRanges >= 3,
                      let range = Range(match.range(at: 2), in: text) else {
                    return nil
                }
                return (range: range, canonicalIndex: marker.canonicalIndex)
            }
        }
        .sorted {
            if $0.range.lowerBound == $1.range.lowerBound {
                return $0.canonicalIndex < $1.canonicalIndex
            }
            return $0.range.lowerBound < $1.range.lowerBound
        }
    }

    private static func normalizeCommonTerminology(_ text: String) -> String {
        commonTerminologyReplacements.reduce(text) { result, replacement in
            result.replacingOccurrences(
                of: replacement.from,
                with: replacement.to,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil
            )
        }
    }

    private static func introSections(for intro: String) -> [String] {
        let cleaned = intro.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return [] }

        if let headingSplit = splitTrailingListHeading(cleaned) {
            var sections: [String] = []
            if !headingSplit.lead.isEmpty {
                sections.append(sentenceCasedWithPeriod(headingSplit.lead))
            }
            sections.append(sentenceCasedWithColon(headingSplit.heading))
            return sections
        }

        return [sentenceCasedWithPeriod(cleaned)]
    }

    private static func splitTrailingListHeading(_ text: String) -> (lead: String, heading: String)? {
        let boundary = lastSentenceBoundary(in: text)
        let lead: String
        let headingCandidate: String

        if let boundary {
            lead = String(text[..<boundary]).trimmingCharacters(in: .whitespacesAndNewlines)
            headingCandidate = String(text[boundary...]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            lead = ""
            headingCandidate = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let normalizedHeading = headingCandidate
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?…"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard isListHeadingCue(normalizedHeading) else {
            return nil
        }

        return (lead, normalizedHeading)
    }

    private static func lastSentenceBoundary(in text: String) -> String.Index? {
        var lastBoundary: String.Index?
        var index = text.startIndex

        while index < text.endIndex {
            if ".!?…".contains(text[index]) {
                let next = text.index(after: index)
                if next < text.endIndex, text[next].isWhitespace {
                    lastBoundary = text.index(after: next)
                }
            }
            index = text.index(after: index)
        }

        return lastBoundary
    }

    private static func isListHeadingCue(_ text: String) -> Bool {
        let normalized = text
            .lowercased()
            .replacingOccurrences(of: "ё", with: "е")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return [
            "вот к чему пришли",
            "и вот к чему пришли",
            "вот что мы достигли",
            "и вот что мы достигли",
            "вот чего мы достигли",
            "и вот чего мы достигли",
            "вот чего достигли",
            "и вот чего достигли",
            "вот что получилось",
            "и вот что получилось",
            "вот что сделали",
            "и вот что сделали",
            "вот что мы сделали",
            "и вот что мы сделали"
        ].contains(normalized)
    }

    private static func sentenceCasedWithPeriod(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!?…–—-"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = cleaned.first, first.isLowercase {
            cleaned.replaceSubrange(cleaned.startIndex...cleaned.startIndex, with: String(first).uppercased())
        }

        guard let last = cleaned.last else { return cleaned }
        if ".!?…".contains(last) {
            return cleaned
        }
        return cleaned + "."
    }

    private static func sentenceCasedWithColon(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".!?…:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let first = cleaned.first, first.isLowercase {
            cleaned.replaceSubrange(cleaned.startIndex...cleaned.startIndex, with: String(first).uppercased())
        }

        return cleaned + ":"
    }
}
