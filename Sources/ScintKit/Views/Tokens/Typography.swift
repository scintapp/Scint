import AppKit
import SwiftUI


enum Typography {
    enum Scale {
        static let body: CGFloat = 14
        static let code: CGFloat = 13
        static let hiddenSyntax: CGFloat = 0.1
        static let chip: CGFloat = 14
        static let inline: CGFloat = 13
        static let bodyWeight: Weight = .regular

        static func heading(_ level: Int) -> CGFloat {
            switch level {
                case 1: 24
                case 2: 18
                default: 16
            }
        }

        static func headingWeight(_ level: Int) -> Weight {
            switch level {
                case 1: .bold
                case 2: .semibold
                default: .medium
            }
        }

        enum Weight {
            case light
            case regular
            case medium
            case semibold
            case bold

            var swiftUI: Font.Weight {
                switch self {
                    case .light: .light
                    case .regular: .regular
                    case .medium: .medium
                    case .semibold: .semibold
                    case .bold: .bold
                }
            }

            var appKit: NSFont.Weight {
                switch self {
                    case .light: .light
                    case .regular: .regular
                    case .medium: .medium
                    case .semibold: .semibold
                    case .bold: .bold
                }
            }
        }
    }

    static let display = Font.system(size: Scale.heading(1), weight: Scale.headingWeight(1).swiftUI)
    static let title = Font.system(size: Scale.heading(2), weight: Scale.headingWeight(2).swiftUI)
    static let subtitle = Font.system(size: Scale.heading(3), weight: Scale.headingWeight(3).swiftUI)
    static let prose = Font.system(size: Scale.body, weight: Scale.bodyWeight.swiftUI)
    static let proseCode = Font.system(size: Scale.code, design: .monospaced)
    static let quote = Font.system(size: Scale.body, weight: Scale.bodyWeight.swiftUI)
    static let chip = Font.system(size: Scale.chip, weight: .regular)
    static let cardHeading = Font.system(size: 15, weight: .regular)
    static let cardRow = Font.system(size: 14, weight: .regular)
    static let cardTitle = Font.system(size: 13, weight: .medium)
    static let row = Font.system(size: 13)
    static let caption = Font.system(size: 13, weight: .light)
    static let label = Font.system(size: 11)
    static let badge = Font.system(size: 12)

    static func cardDetail(_ design: Font.Design = .default) -> Font {
        .system(
            size: 13,
            weight: design == .monospaced ? .medium : .regular,
            design: design
        )
    }

    static func heading(_ level: Int) -> Font {
        switch level {
            case 1: display
            case 2: title
            default: subtitle
        }
    }

    static var appKitRow: NSFont { .systemFont(ofSize: 14) }

    enum Prose {
        static var syntaxHidden: Font { .system(size: Scale.hiddenSyntax) }
        static var appKitText: NSFont { .systemFont(ofSize: Scale.body, weight: Scale.bodyWeight.appKit) }
        static var appKitCode: NSFont { .monospacedSystemFont(ofSize: Scale.code, weight: .regular) }
        static var appKitTableHeader: NSFont { .systemFont(ofSize: Scale.body, weight: .semibold) }
        static var appKitSyntaxHidden: NSFont { .systemFont(ofSize: Scale.hiddenSyntax) }

        static func appKitHeading(_ level: Int) -> NSFont {
            .systemFont(ofSize: Scale.heading(level), weight: Scale.headingWeight(level).appKit)
        }

        static var appKitLineHeight: CGFloat {
            let font = appKitText
            return ceil(font.ascender - font.descender + font.leading)
        }

        static var paragraphStyle: NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
            return paragraph
        }

        static func headingParagraphStyle(_ level: Int) -> NSParagraphStyle {
            paragraphStyle
        }

        static func listParagraphStyle(indent: CGFloat, hanging: CGFloat) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = indent
            paragraph.headIndent = indent + hanging
            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: indent + hanging)]
            return paragraph
        }

        static var quoteParagraphStyle: NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = Style.Spacing.lg
            paragraph.firstLineHeadIndent = Style.Spacing.lg
            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
            return paragraph
        }
    }
}

enum Attribute {
    static func text(_ text: String, reasoning: Bool = false) -> AttributedString {
        let base = reasoning ? Style.Foreground.faint : Style.Foreground.primary
        var attributed = AttributedString(text)
        attributed.font = reasoning ? Typography.prose.italic() : Typography.prose
        attributed.foregroundColor = base

        for span in Markdown.scan(text).spans {
            guard let range = range(span.range, source: text, attributed: attributed) else {
                continue
            }

            switch span.kind {
                case .heading(let level):
                    attributed[range].font = Typography.heading(level)

                case .quote:
                    attributed[range].font = Typography.quote
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .quoteMarker, .listMarker:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .checkbox(let checked):
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(
                        checked ? Style.Opacity.muted : Style.Opacity.faint
                    )

                case .completed:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .codeBlock:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .codeFence:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.washed)

                case .strong:
                    attributed[range].font = Typography.prose.weight(.semibold)

                case .emphasis:
                    attributed[range].font = Typography.prose.italic()

                case .inlineCode:
                    attributed[range].font = Typography.proseCode
                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.washed)

                case .strikethrough:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .linkLabel:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.strong)
                    attributed[range].underlineStyle = .single

                case .linkURL:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .syntax:
                    attributed[range].font = Typography.Prose.syntaxHidden
                    attributed[range].foregroundColor = .clear
            }
        }

        return attributed
    }

    static func range(_ range: NSRange, source: String, attributed: AttributedString) -> Range<AttributedString.Index>? {
        guard let sourceRange = Range(range, in: source) else { return nil }

        let lowerOffset = source.distance(from: source.startIndex, to: sourceRange.lowerBound)
        let upperOffset = source.distance(from: source.startIndex, to: sourceRange.upperBound)
        let characters = attributed.characters
        let lowerBound = characters.index(characters.startIndex, offsetBy: lowerOffset)
        let upperBound = characters.index(characters.startIndex, offsetBy: upperOffset)
        return lowerBound..<upperBound
    }
}

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
        var fence: (character: Character, count: Int)?
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
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let marker = trimmed.first
            let fenceCount = trimmed.prefix { $0 == marker }.count
            let kind: BlockKind
            if let opened = fence {
                let closing = marker == opened.character && fenceCount >= opened.count
                    && trimmed.dropFirst(fenceCount).trimmingCharacters(in: .whitespaces).isEmpty
                kind = closing ? .codeFence : .codeBlock
                if closing { fence = nil }
            } else {
                kind = classify(line)
                if kind == .codeFence, let marker { fence = (marker, fenceCount) }
            }
            let block = block(kind: kind, line: line, in: lineRange)

            blocks.append(block)
            append(block, line: line, to: &spans, links: &links)

            lineStart = lineEnd
        }

        spans.sort { $0.kind.rank < $1.kind.rank }
        return Document(blocks: blocks, spans: spans, links: links)
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
        if line.hasPrefix("```") || line.hasPrefix("~~~") { return .codeFence }
        if line.hasPrefix("- [ ] ") { return .checklist(checked: false) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return .checklist(checked: true) }
        if line.hasPrefix("### ") { return .heading(level: 3) }
        if line.hasPrefix("## ") { return .heading(level: 2) }
        if line.hasPrefix("# ") { return .heading(level: 1) }
        if line == ">" || line.hasPrefix("> ") { return .quote }
        if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") { return .bullet }
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
        let code = codeRanges(text)
        for (full, content) in code {
            append(NSRange(location: offset + content.location, length: content.length), as: .inlineCode, to: &spans)
            append(NSRange(location: offset + full.location, length: content.location - full.location), as: .syntax, to: &spans)
            append(NSRange(location: offset + NSMaxRange(content), length: NSMaxRange(full) - NSMaxRange(content)), as: .syntax, to: &spans)
        }
        for pattern in inlinePatterns where pattern.kind != .inlineCode {
            for match in pattern.regex.matches(in: text, range: range) {
                let delimiterLength = pattern.delimiterLength
                guard match.range.length > delimiterLength * 2 else { continue }
                let opening = NSRange(location: match.range.location, length: delimiterLength)
                let closing = NSRange(location: NSMaxRange(match.range) - delimiterLength, length: delimiterLength)
                guard !code.contains(where: {
                    NSIntersectionRange($0.0, opening).length > 0 || NSIntersectionRange($0.0, closing).length > 0
                }) else { continue }
                let full = NSRange(location: offset + match.range.location, length: match.range.length)
                append(NSRange(location: full.location + delimiterLength, length: full.length - delimiterLength * 2), as: pattern.kind, to: &spans)
                append(NSRange(location: full.location, length: delimiterLength), as: .syntax, to: &spans)
                append(NSRange(location: NSMaxRange(full) - delimiterLength, length: delimiterLength), as: .syntax, to: &spans)
            }
        }
    }

    private static func codeRanges(_ text: String) -> [(NSRange, NSRange)] {
        let source = text as NSString
        var result: [(NSRange, NSRange)] = []
        var index = 0
        while index < source.length {
            guard source.character(at: index) == 96 else { index += 1; continue }
            let start = index
            while index < source.length, source.character(at: index) == 96 { index += 1 }
            let count = index - start
            let contentStart = index
            var search = index
            var found = false
            while search < source.length {
                guard source.character(at: search) == 96 else { search += 1; continue }
                let endStart = search
                while search < source.length, source.character(at: search) == 96 { search += 1 }
                if search - endStart == count {
                    result.append((NSRange(location: start, length: search - start), NSRange(location: contentStart, length: endStart - contentStart)))
                    index = search; found = true; break
                }
            }
            if !found { index = contentStart }
        }
        return result
    }

    private static func appendLinks(in text: String, offset: Int, to spans: inout [Span], links: inout [Link]) {
        let source = text as NSString
        let code = codeRanges(text)
        var index = 0
        while index < source.length {
            guard source.character(at: index) == 91,
                  !code.contains(where: { NSLocationInRange(index, $0.0) }),
                  index == 0 || source.character(at: index - 1) != 92 else { index += 1; continue }
            let start = index
            var cursor = index + 1
            var brackets = 1
            while cursor < source.length, brackets > 0 {
                let char = source.character(at: cursor)
                if char == 92 { cursor += 2; continue }
                if char == 91 { brackets += 1 }
                if char == 93 { brackets -= 1 }
                cursor += 1
            }
            guard brackets == 0, cursor < source.length, source.character(at: cursor) == 40 else { index += 1; continue }
            let label = NSRange(location: start + 1, length: cursor - start - 2)
            let urlStart = cursor + 1
            cursor = urlStart
            var parentheses = 1
            while cursor < source.length, parentheses > 0 {
                let char = source.character(at: cursor)
                if char == 92 { cursor += 2; continue }
                if char == 40 { parentheses += 1 }
                if char == 41 { parentheses -= 1 }
                cursor += 1
            }
            guard parentheses == 0, cursor <= source.length else { index += 1; continue }
            var destinationStart = urlStart
            let destinationEnd = cursor - 1
            while destinationStart < destinationEnd, let scalar = UnicodeScalar(source.character(at: destinationStart)), CharacterSet.whitespaces.contains(scalar) { destinationStart += 1 }
            var urlEnd = destinationStart
            if destinationStart < destinationEnd, source.character(at: destinationStart) == 60 {
                destinationStart += 1
                urlEnd = destinationStart
                while urlEnd < destinationEnd, source.character(at: urlEnd) != 62 { urlEnd += 1 }
            } else {
                while urlEnd < destinationEnd {
                    if source.character(at: urlEnd) == 92, urlEnd + 1 < destinationEnd { urlEnd += 2; continue }
                    if let scalar = UnicodeScalar(source.character(at: urlEnd)), CharacterSet.whitespaces.contains(scalar) { break }
                    urlEnd += 1
                }
            }
            let destination = NSRange(location: destinationStart, length: urlEnd - destinationStart)
            let full = NSRange(location: start, length: cursor - start)
            let shifted = Link(
                range: NSRange(location: offset + full.location, length: full.length),
                label: NSRange(location: offset + label.location, length: label.length),
                url: NSRange(location: offset + destination.location, length: destination.length)
            )
            links.append(shifted)
            append(shifted.label, as: .linkLabel, to: &spans)
            append(shifted.url, as: .linkURL, to: &spans)
            append(NSRange(location: offset + start, length: 1), as: .syntax, to: &spans)
            append(NSRange(location: NSMaxRange(shifted.label), length: shifted.url.location - NSMaxRange(shifted.label)), as: .syntax, to: &spans)
            append(NSRange(location: NSMaxRange(shifted.url), length: offset + cursor - NSMaxRange(shifted.url)), as: .syntax, to: &spans)
            index = cursor
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

    static func holdsMultipleLines(_ text: String) -> Bool { text.contains("```") || text.contains("~~~") }

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
