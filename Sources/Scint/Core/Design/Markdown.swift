import Foundation


struct Markdown {
    struct Inline: Equatable {
        let range: NSRange
        let kind: Kind
    }

    enum Kind: Equatable {
        case heading(level: Int)
        case quote
        case quoteMarker
        case codeBlock
        case codeFence
        case strong
        case emphasis
        case inlineCode
        case strikethrough
        case syntax
    }

    private enum LineKind {
        case heading(level: Int, contentStart: Int)
        case quote(contentStart: Int)
        case codeFence
        case plain
    }

    private static let inlinePatterns: [(
        regex: NSRegularExpression,
        kind: Kind,
        delimiterLength: Int
    )] = [
        (
            try! NSRegularExpression(pattern: #"(\*\*|__)(?!\s)(.+?)(?<!\s)(\*\*|__)"#),
            .strong,
            2
        ),
        (
            try! NSRegularExpression(
                pattern: #"(?<!\*)\*(?!\*)(?!\s)(.+?)(?<!\s)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(?!\s)(.+?)(?<!\s)(?<!_)_(?!_)"#
            ),
            .emphasis,
            1
        ),
        (
            try! NSRegularExpression(pattern: #"`([^`\n]+)`"#),
            .inlineCode,
            1
        ),
        (
            try! NSRegularExpression(pattern: #"~~(?!\s)(.+?)(?<!\s)~~"#),
            .strikethrough,
            2
        ),
    ]

    static func parse(_ text: String) -> [Inline] {
        guard !text.isEmpty else { return [] }

        let string = text as NSString
        var result: [Inline] = []
        var insideFence = false
        var lineStart = 0

        while lineStart < string.length {
            var lineEnd = 0
            var contentsEnd = 0
            string.getLineStart(
                nil,
                end: &lineEnd,
                contentsEnd: &contentsEnd,
                for: NSRange(location: lineStart, length: 0)
            )

            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let line = string.substring(with: lineRange)
            let kind = classify(line)

            switch kind {
                case .codeFence:
                    append(lineRange, as: .codeFence, to: &result)
                    insideFence.toggle()

                case .heading(let level, let contentStart) where !insideFence:
                    appendContent(
                        in: lineRange,
                        after: contentStart,
                        as: .heading(level: level),
                        to: &result
                    )
                    appendPrefix(in: lineRange, length: contentStart, as: .syntax, to: &result)
                    appendInline(in: line, offset: lineRange.location, to: &result)

                case .quote(let contentStart) where !insideFence:
                    append(lineRange, as: .quote, to: &result)
                    appendPrefix(in: lineRange, length: contentStart, as: .quoteMarker, to: &result)
                    appendInline(in: line, offset: lineRange.location, to: &result)

                default:
                    if insideFence {
                        append(lineRange, as: .codeBlock, to: &result)
                    } else {
                        appendInline(in: line, offset: lineRange.location, to: &result)
                    }
            }

            lineStart = lineEnd
        }

        return result
    }

    private static func classify(_ line: String) -> LineKind {
        if line.hasPrefix("```") { return .codeFence }
        if line.hasPrefix("### ") { return .heading(level: 3, contentStart: 4) }
        if line.hasPrefix("## ") { return .heading(level: 2, contentStart: 3) }
        if line.hasPrefix("# ") { return .heading(level: 1, contentStart: 2) }
        if line.hasPrefix("> ") { return .quote(contentStart: 2) }
        return .plain
    }

    private static func appendInline(in line: String, offset: Int, to result: inout [Inline]) {
        let lineRange = NSRange(location: 0, length: (line as NSString).length)

        for pattern in inlinePatterns {
            for match in pattern.regex.matches(in: line, range: lineRange) {
                let delimiterLength = pattern.delimiterLength
                guard match.range.length > delimiterLength * 2 else { continue }

                let fullRange = NSRange(
                    location: offset + match.range.location,
                    length: match.range.length
                )
                let contentRange = NSRange(
                    location: fullRange.location + delimiterLength,
                    length: fullRange.length - delimiterLength * 2
                )
                let closingRange = NSRange(
                    location: NSMaxRange(fullRange) - delimiterLength,
                    length: delimiterLength
                )

                append(contentRange, as: pattern.kind, to: &result)
                append(
                    NSRange(location: fullRange.location, length: delimiterLength),
                    as: .syntax,
                    to: &result
                )
                append(closingRange, as: .syntax, to: &result)
            }
        }
    }

    private static func appendContent(
        in lineRange: NSRange,
        after prefixLength: Int,
        as kind: Kind,
        to result: inout [Inline]
    ) {
        let length = max(0, lineRange.length - prefixLength)
        append(
            NSRange(location: lineRange.location + min(prefixLength, lineRange.length), length: length),
            as: kind,
            to: &result
        )
    }

    private static func appendPrefix(
        in lineRange: NSRange,
        length: Int,
        as kind: Kind,
        to result: inout [Inline]
    ) {
        append(
            NSRange(location: lineRange.location, length: min(length, lineRange.length)),
            as: kind,
            to: &result
        )
    }

    private static func append(_ range: NSRange, as kind: Kind, to result: inout [Inline]) {
        guard range.length > 0 else { return }
        result.append(Inline(range: range, kind: kind))
    }
}
