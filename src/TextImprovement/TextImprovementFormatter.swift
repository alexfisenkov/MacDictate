import Foundation

enum TextImprovementFormatter {
    private static let commonTerminologyReplacements: [(from: String, to: String)] = [
        ("Adobe Premier Pro", "Adobe Premiere Pro"),
        ("премьер про", "Adobe Premiere Pro"),
        ("давинчи резолв", "DaVinci Resolve"),
        ("файн кат про", "Final Cut Pro"),
        ("чат джипити", "ChatGPT"),
        ("чат джпт", "ChatGPT"),
        ("чат gpt", "ChatGPT"),
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

        var sections: [String] = []
        if !intro.isEmpty {
            sections.append(sentenceCasedWithPeriod(intro))
        }

        let list = items.enumerated()
            .map { "\($0.offset + 1). \($0.element)" }
            .joined(separator: "\n")
        sections.append(list)

        return sections.joined(separator: "\n\n")
    }

    private static func orderedMarkerMatches(in text: String) -> [(range: Range<String.Index>, canonicalIndex: Int)] {
        orderedMarkers.flatMap { marker -> [(range: Range<String.Index>, canonicalIndex: Int)] in
            guard let regex = try? NSRegularExpression(
                pattern: "(?i)(^|[\\s,.;:])(\(marker.pattern))(?=\\s)",
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

    private static func sentenceCasedWithPeriod(_ text: String) -> String {
        var cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ",;:"))
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
}
