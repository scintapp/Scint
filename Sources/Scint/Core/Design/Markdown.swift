import Foundation


/// # Markdown
///
/// `Markdown.scan` is the only place that decides what a piece of text *is*. Renderers —
/// `Attribute.text` for SwiftUI transcripts, `EditorThemer` for the AppKit editor — consume
/// its output and decide only what each kind *looks like*. Neither one classifies text.

struct Markdown {
    struct Document: Equatable {
        let blocks: [Block]
        let spans: [Span]
        let links: [Link]

        static let empty = Document(blocks: [], spans: [], links: [])
    }

    struct Link: Equatable {
        let range: NSRange
        let label: NSRange
        let url: NSRange
    }

    struct Block: Equatable {
        let kind: BlockKind
        let range: NSRange
        let indent: NSRange
        let marker: NSRange
        let content: NSRange
        let depth: Int
        var prefix: NSRange {
            NSRange(location: range.location, length: indent.length + marker.length)
        }
    }

    enum BlockKind: Equatable {
        case paragraph
        case heading(level: Int)
        case quote
        case bullet
        case numbered
        case checklist(checked: Bool)
        case codeFence
        case codeBlock

        var isList: Bool {
            switch self {
                case .bullet, .numbered, .checklist: return true
                default: return false
            }
        }
    }

    struct Span: Equatable {
        let range: NSRange
        let kind: Kind
    }

    enum Kind: Equatable {
        case heading(level: Int)
        case quote
        case quoteMarker
        case listMarker
        case checkbox(checked: Bool)
        case completed
        case codeBlock
        case codeFence
        case strong
        case emphasis
        case inlineCode
        case strikethrough
        case linkLabel
        case linkURL
        case syntax

        var rank: Int {
            switch self {
                case .heading, .quote, .codeBlock, .codeFence:
                    return 0
                case .quoteMarker, .listMarker, .checkbox, .completed:
                    return 1
                case .strong, .emphasis, .inlineCode, .strikethrough, .linkLabel, .linkURL:
                    return 2
                case .syntax:
                    return 3
            }
        }
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

    private static let linkPattern = try! NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#)

    private static let numberedPattern = try! NSRegularExpression(pattern: #"^\d+\.[ \t]"#)

    private static let indentWidth = 2

    static func scan(_ text: String) -> Document {
        guard !text.isEmpty else { return .empty }

        let string = text as NSString
        var blocks: [Block] = []
        var spans: [Span] = []
        var links: [Link] = []
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
            let kind = insideFence ? fenceKind(line) : classify(line)
            let block = block(kind: kind, line: line, in: lineRange)

            blocks.append(block)
            append(block, line: line, to: &spans, links: &links)

            if case .codeFence = kind { insideFence.toggle() }
            lineStart = lineEnd
        }

        spans.sort { $0.kind.rank < $1.kind.rank }
        return Document(blocks: blocks, spans: spans, links: links)
    }

    private static func fenceKind(_ line: String) -> BlockKind {
        line.hasPrefix("```") ? .codeFence : .codeBlock
    }

    private static func indentLength(of line: String) -> Int {
        let source = line as NSString
        var index = 0
        while index < source.length {
            let character = source.substring(with: NSRange(location: index, length: 1))
            guard character == " " || character == "\t" else { break }
            index += 1
        }
        return index
    }

    private static func depth(ofIndent indent: String) -> Int {
        var level = 0
        var spaces = 0
        for character in indent {
            if character == "\t" { level += 1; spaces = 0 }
            else { spaces += 1 }
        }
        return level + spaces / indentWidth
    }

    private static func classify(_ line: String) -> BlockKind {
        let line = (line as NSString).substring(from: indentLength(of: line))
        if line.hasPrefix("```") { return .codeFence }
        if line.hasPrefix("- [ ] ") { return .checklist(checked: false) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return .checklist(checked: true) }
        if line.hasPrefix("### ") { return .heading(level: 3) }
        if line.hasPrefix("## ") { return .heading(level: 2) }
        if line.hasPrefix("# ") { return .heading(level: 1) }
        if line.hasPrefix("> ") { return .quote }
        if line.hasPrefix("- ") { return .bullet }
        if numberedPattern.firstMatch(
            in: line,
            range: NSRange(location: 0, length: (line as NSString).length)
        ) != nil { return .numbered }
        return .paragraph
    }

    private static func markerLength(of kind: BlockKind, in line: String) -> Int {
        switch kind {
            case .heading(let level): return level + 1
            case .quote: return 2
            case .bullet: return 2
            case .checklist: return 6
            case .numbered:
                let range = NSRange(location: 0, length: (line as NSString).length)
                return numberedPattern.firstMatch(in: line, range: range)?.range.length ?? 0
            case .paragraph, .codeFence, .codeBlock: return 0
        }
    }

    private static func block(kind: BlockKind, line: String, in lineRange: NSRange) -> Block {
        let source = line as NSString
        let indent = min(indentLength(of: line), lineRange.length)
        let body = source.substring(from: indent)
        let marker = min(markerLength(of: kind, in: body), lineRange.length - indent)

        return Block(
            kind: kind,
            range: lineRange,
            indent: NSRange(location: lineRange.location, length: indent),
            marker: NSRange(location: lineRange.location + indent, length: marker),
            content: NSRange(
                location: lineRange.location + indent + marker,
                length: lineRange.length - indent - marker
            ),
            depth: kind.isList ? depth(ofIndent: source.substring(to: indent)) : 0
        )
    }

    private static func append(_ block: Block, line: String, to spans: inout [Span], links: inout [Link]) {
        switch block.kind {
            case .codeFence:
                append(block.range, as: .codeFence, to: &spans)
                return

            case .codeBlock:
                append(block.range, as: .codeBlock, to: &spans)
                return

            case .heading(let level):
                append(block.content, as: .heading(level: level), to: &spans)
                append(block.marker, as: .syntax, to: &spans)

            case .quote:
                append(block.range, as: .quote, to: &spans)
                append(block.marker, as: .quoteMarker, to: &spans)

            case .bullet, .numbered:
                append(block.marker, as: .listMarker, to: &spans)

            case .checklist(let checked):
                append(NSRange(location: block.marker.location, length: 2), as: .syntax, to: &spans)
                append(
                    NSRange(location: block.marker.location + 2, length: 3),
                    as: .checkbox(checked: checked),
                    to: &spans
                )
                if checked { append(block.content, as: .completed, to: &spans) }

            case .paragraph:
                break
        }

        let source = line as NSString
        let content = source.substring(
            from: min(block.indent.length + block.marker.length, source.length)
        )
        appendInline(in: content, offset: block.content.location, to: &spans)
        appendLinks(in: content, offset: block.content.location, to: &spans, links: &links)
    }

    private static func appendInline(in text: String, offset: Int, to spans: inout [Span]) {
        let range = NSRange(location: 0, length: (text as NSString).length)

        for pattern in inlinePatterns {
            for match in pattern.regex.matches(in: text, range: range) {
                let delimiterLength = pattern.delimiterLength
                guard match.range.length > delimiterLength * 2 else { continue }

                let full = NSRange(location: offset + match.range.location, length: match.range.length)
                append(
                    NSRange(
                        location: full.location + delimiterLength,
                        length: full.length - delimiterLength * 2
                    ),
                    as: pattern.kind,
                    to: &spans
                )
                append(
                    NSRange(location: full.location, length: delimiterLength),
                    as: .syntax,
                    to: &spans
                )
                append(
                    NSRange(location: NSMaxRange(full) - delimiterLength, length: delimiterLength),
                    as: .syntax,
                    to: &spans
                )
            }
        }
    }

    private static func appendLinks(in text: String, offset: Int, to spans: inout [Span], links: inout [Link]) {
        let range = NSRange(location: 0, length: (text as NSString).length)

        for match in linkPattern.matches(in: text, range: range) {
            guard match.numberOfRanges == 3 else { continue }

            let label = NSRange(
                location: offset + match.range(at: 1).location,
                length: match.range(at: 1).length
            )
            let url = NSRange(
                location: offset + match.range(at: 2).location,
                length: match.range(at: 2).length
            )

            links.append(
                Link(
                    range: NSRange(location: offset + match.range.location, length: match.range.length),
                    label: label,
                    url: url
                )
            )
            append(label, as: .linkLabel, to: &spans)
            append(url, as: .linkURL, to: &spans)
            append(NSRange(location: offset + match.range.location, length: 1), as: .syntax, to: &spans)
            append(NSRange(location: NSMaxRange(label), length: 2), as: .syntax, to: &spans)
            append(NSRange(location: NSMaxRange(url), length: 1), as: .syntax, to: &spans)
        }
    }

    private static func append(_ range: NSRange, as kind: Kind, to spans: inout [Span]) {
        guard range.length > 0 else { return }
        spans.append(Span(range: range, kind: kind))
    }
}

extension Markdown {
    struct ListContext: Equatable {
        let depth: Int
        let ordinal: Int
        let isOrdered: Bool
    }

    static func continuation(for line: String) -> String? {
        let kind = classify(line)
        guard kind.isList else { return nil }

        let source = line as NSString
        let indentLength = indentLength(of: line)
        let indent = source.substring(to: indentLength)
        let body = source.substring(from: indentLength)
        let marker = (body as NSString).substring(to: markerLength(of: kind, in: body))

        switch kind {
            case .numbered:
                let digits = marker.prefix { $0.isNumber }
                guard let value = Int(digits) else { return indent + marker }
                return indent + "\(value + 1)" + marker.dropFirst(digits.count)
            case .checklist:
                return indent + "- [ ] "
            default:
                return indent + marker
        }
    }

    static func isEmptyItem(_ line: String) -> Bool {
        let kind = classify(line)
        guard kind.isList else { return false }
        let source = line as NSString
        let length = min(prefixLength(of: line), source.length)
        return source.substring(from: length).trimmingCharacters(in: .whitespaces).isEmpty
    }

    static func prefixLength(of line: String) -> Int {
        let indent = indentLength(of: line)
        let body = (line as NSString).substring(from: indent)
        return indent + markerLength(of: classify(line), in: body)
    }

    static func editBoundary(_ offset: Int, in text: String) -> Int {
        for link in scan(text).links {
            guard offset > link.range.location, offset < NSMaxRange(link.range) else { continue }
            let toStart = offset - link.range.location
            let toEnd = NSMaxRange(link.range) - offset
            return toStart <= toEnd ? link.range.location : NSMaxRange(link.range)
        }
        return offset
    }

    static func holdsMultipleLines(_ text: String) -> Bool { text.contains("```") }

    static func depth(of line: String) -> Int {
        depth(ofIndent: (line as NSString).substring(to: indentLength(of: line)))
    }

    static func indented(_ line: String, by levels: Int) -> String {
        let kind = classify(line)
        guard kind.isList, levels != 0 else { return line }

        let source = line as NSString
        let current = depth(of: line)
        let target = max(0, current + levels)
        guard target != current else { return line }

        return String(repeating: " ", count: target * indentWidth)
            + source.substring(from: indentLength(of: line))
    }

    static func listContexts(for lines: [String]) -> [ListContext?] {
        var counters: [Int: Int] = [:]
        var previousDepth: Int?

        return lines.map { line -> ListContext? in
            let kind = classify(line)
            guard kind.isList else {
                counters.removeAll()
                previousDepth = nil
                return nil
            }

            let depth = depth(of: line)

            if let previousDepth, depth < previousDepth {
                for level in counters.keys where level > depth { counters[level] = nil }
            }

            let ordinal = (counters[depth] ?? 0) + 1
            counters[depth] = ordinal
            previousDepth = depth

            return ListContext(depth: depth, ordinal: ordinal, isOrdered: kind == .numbered)
        }
    }

    static func renumbered(_ lines: [String]) -> [String] {
        let contexts = listContexts(for: lines)

        return zip(lines, contexts).map { line, context in
            guard let context, context.isOrdered else { return line }

            let source = line as NSString
            let indent = indentLength(of: line)
            let marker = markerLength(of: .numbered, in: source.substring(from: indent))
            guard marker > 1 else { return line }

            let separator = source.substring(with: NSRange(location: indent + marker - 1, length: 1))
            return source.substring(to: indent)
                + "\(context.ordinal)."
                + separator
                + source.substring(from: indent + marker)
        }
    }
}
