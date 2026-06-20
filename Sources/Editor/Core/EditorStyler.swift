import AppKit
import SwiftUI


private struct InlinePattern {
    let regex: NSRegularExpression
    let attrs: [NSAttributedString.Key: Any]
    let delimLength: Int
}

struct Style: @unchecked Sendable {
    var textColor: NSColor
    var baseFont: NSFont
    var h1Font: NSFont
    var h2Font: NSFont
    var h3Font: NSFont
    var codeFont: NSFont
    var codeBgColor: NSColor
    var codeFenceColor: NSColor
    var bulletColor: NSColor
    var checkboxCheckedColor: NSColor
    var checkboxUncheckedColor: NSColor
    var syntaxHiddenColor: NSColor
    var listIndent: CGFloat

    static let dark = Style(
        textColor: .white,
        baseFont: .systemFont(ofSize: 15, weight: .light),
        h1Font: .systemFont(ofSize: 24, weight: .bold),
        h2Font: .systemFont(ofSize: 20, weight: .semibold),
        h3Font: .systemFont(ofSize: 18, weight: .semibold),
        codeFont: .monospacedSystemFont(ofSize: 14, weight: .regular),
        codeBgColor: NSColor.black.withAlphaComponent(0.2),
        codeFenceColor: NSColor.black.withAlphaComponent(0.3),
        bulletColor: NSColor.white.withAlphaComponent(0.4),
        checkboxCheckedColor: .systemGray,
        checkboxUncheckedColor: NSColor.white.withAlphaComponent(0.3),
        syntaxHiddenColor: .clear,
        listIndent: 24
    )
}

final class EditorStyler: NSObject {
    var style: Style = .dark

    func attributedString(for text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        applyFullStyle(to: attributed)
        return attributed
    }

    var typingAttributes: [NSAttributedString.Key: Any] {
        baseAttributes
    }

    private func applyFullStyle(to textStorage: NSMutableAttributedString) {
        textStorage.beginEditing()

        let fullString = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)

        guard !fullString.isEmpty else {
            textStorage.endEditing()
            return
        }

        let nsString = fullString as NSString
        textStorage.setAttributes(baseAttributes, range: fullRange)

        var insideFence = false
        var lineStart = 0

        while lineStart < nsString.length {
            var lineEnd = 0
            var contentsEnd = 0
            nsString.getLineStart(nil, end: &lineEnd, contentsEnd: &contentsEnd, for: NSRange(location: lineStart, length: 0))
            let lineRange = NSRange(location: lineStart, length: contentsEnd - lineStart)
            let kind = classify(nsString.substring(with: lineRange))

            switch kind {
            case .codeFence:
                styleFenceLine(textStorage, range: lineRange)
                insideFence.toggle()
            default:
                if insideFence {
                    textStorage.addAttributes([
                        .font: style.codeFont,
                        .foregroundColor: style.textColor.withAlphaComponent(0.85),
                    ], range: lineRange)
                } else {
                    styleLine(textStorage, kind: kind, lineRange: lineRange)
                    styleInline(textStorage, in: lineRange)
                }
            }

            lineStart = lineEnd
        }

        textStorage.endEditing()
    }

    private lazy var inlinePatterns: [InlinePattern] = {
        func regex(_ pattern: String) -> NSRegularExpression {
            try! NSRegularExpression(pattern: pattern)
        }

        return [
            InlinePattern(
                regex: regex(#"(\*\*|__)(?!\s)(.+?)(?<!\s)(\*\*|__)"#),
                attrs: [.font: NSFont.systemFont(ofSize: style.baseFont.pointSize, weight: .bold)],
                delimLength: 2
            ),
            InlinePattern(
                regex: regex(#"(?<!\*)\*(?!\*)(?!\s)(.+?)(?<!\s)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(?!\s)(.+?)(?<!\s)(?<!_)_(?!_)"#),
                attrs: [.font: NSFontManager.shared.convert(style.baseFont, toHaveTrait: .italicFontMask)],
                delimLength: 1
            ),
            InlinePattern(
                regex: regex(#"`([^`\n]+)`"#),
                attrs: [.font: style.codeFont, .backgroundColor: style.codeBgColor],
                delimLength: 1
            ),
            InlinePattern(
                regex: regex(#"~~(?!\s)(.+?)(?<!\s)~~"#),
                attrs: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: style.textColor.withAlphaComponent(0.45),
                ],
                delimLength: 2
            ),
        ]
    }()

    private func styleInline(_ textStorage: NSMutableAttributedString, in range: NSRange) {
        let string = (textStorage.string as NSString).substring(with: range)
        let hideAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.syntaxHiddenColor,
            .font: NSFont.systemFont(ofSize: 0.1),
        ]

        for pattern in inlinePatterns {
            let matches = pattern.regex.matches(in: string, range: NSRange(string.startIndex..., in: string))
            for match in matches {
                let full = NSRange(location: range.location + match.range.location, length: match.range.length)
                guard full.length > pattern.delimLength * 2 else { continue }
                let open = NSRange(location: full.location, length: pattern.delimLength)
                let close = NSRange(location: full.location + full.length - pattern.delimLength, length: pattern.delimLength)
                let inner = NSRange(location: open.location + open.length, length: full.length - pattern.delimLength * 2)
                textStorage.addAttributes(pattern.attrs, range: inner)
                textStorage.addAttributes(hideAttrs, range: open)
                textStorage.addAttributes(hideAttrs, range: close)
            }
        }

        styleLinks(textStorage, string: string, offset: range.location, hideAttrs: hideAttrs)
    }

    private func styleLinks(_ textStorage: NSMutableAttributedString, string: String, offset: Int, hideAttrs: [NSAttributedString.Key: Any]) {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#) else { return }

        for match in regex.matches(in: string, range: NSRange(string.startIndex..., in: string)) {
            guard match.numberOfRanges == 3 else { continue }
            let labelRange = NSRange(
                location: offset + match.range(at: 1).location,
                length: match.range(at: 1).length
            )
            let urlRange = NSRange(
                location: offset + match.range(at: 2).location,
                length: match.range(at: 2).length
            )

            textStorage.addAttributes(hideAttrs, range: NSRange(location: offset + match.range.location, length: 1))
            textStorage.addAttributes([.foregroundColor: style.textColor.withAlphaComponent(0.75)], range: labelRange)
            textStorage.addAttributes(hideAttrs, range: NSRange(location: labelRange.location + labelRange.length, length: 2))
            textStorage.addAttributes([
                .font: style.codeFont,
                .foregroundColor: style.textColor.withAlphaComponent(0.3),
            ], range: urlRange)
            textStorage.addAttributes(hideAttrs, range: NSRange(location: urlRange.location + urlRange.length, length: 1))
        }
    }

    private enum LineKind {
        case heading(level: Int, contentStart: Int)
        case bulletList(contentStart: Int)
        case numberedList(contentStart: Int)
        case checklistUnchecked(contentStart: Int)
        case checklistChecked(contentStart: Int)
        case codeFence(language: String?)
        case quote(contentStart: Int)
        case plain
    }

    private func classify(_ line: String) -> LineKind {
        if line.hasPrefix("- [ ] ") { return .checklistUnchecked(contentStart: 6) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return .checklistChecked(contentStart: 6) }
        if line.hasPrefix("```") {
            return .codeFence(language: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces))
        }
        if line.hasPrefix("### ") { return .heading(level: 3, contentStart: 4) }
        if line.hasPrefix("## ") { return .heading(level: 2, contentStart: 3) }
        if line.hasPrefix("# ") { return .heading(level: 1, contentStart: 2) }
        if line.hasPrefix("> ") { return .quote(contentStart: 2) }
        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            return .numberedList(contentStart: line.distance(from: line.startIndex, to: match.upperBound))
        }
        if line.hasPrefix("- ") { return .bulletList(contentStart: 2) }
        return .plain
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        return [
            .font: style.baseFont,
            .foregroundColor: style.textColor,
            .paragraphStyle: paragraph,
        ]
    }

    private func styleLine(_ textStorage: NSMutableAttributedString, kind: LineKind, lineRange: NSRange) {
        switch kind {
        case .heading(let level, let contentStart):
            styleHeading(textStorage, level: level, contentStart: contentStart, lineRange: lineRange)
        case .bulletList(let contentStart):
            styleBulletList(textStorage, contentStart: contentStart, lineRange: lineRange)
        case .numberedList(let contentStart):
            styleNumberedList(textStorage, contentStart: contentStart, lineRange: lineRange)
        case .checklistUnchecked(let contentStart):
            styleChecklist(textStorage, checked: false, contentStart: contentStart, lineRange: lineRange)
        case .checklistChecked(let contentStart):
            styleChecklist(textStorage, checked: true, contentStart: contentStart, lineRange: lineRange)
        case .quote(let contentStart):
            styleQuote(textStorage, contentStart: contentStart, lineRange: lineRange)
        case .plain, .codeFence:
            break
        }
    }

    private func styleHeading(_ textStorage: NSMutableAttributedString, level: Int, contentStart: Int, lineRange: NSRange) {
        let font: NSFont
        let spacing: CGFloat

        switch level {
        case 1:
            font = style.h1Font
            spacing = 12
        case 2:
            font = style.h2Font
            spacing = 8
        default:
            font = style.h3Font
            spacing = 6
        }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacingBefore = spacing
        paragraph.paragraphSpacing = 4
        textStorage.addAttributes([.paragraphStyle: paragraph], range: lineRange)

        let contentRange = NSRange(
            location: lineRange.location + contentStart,
            length: max(0, lineRange.length - contentStart)
        )

        if contentRange.length > 0 {
            textStorage.addAttributes([.font: font], range: contentRange)
        }

        textStorage.addAttributes(
            [.foregroundColor: style.syntaxHiddenColor, .font: NSFont.systemFont(ofSize: 0.1)],
            range: NSRange(location: lineRange.location, length: min(contentStart, lineRange.length))
        )
    }

    private func styleBulletList(_ textStorage: NSMutableAttributedString, contentStart: Int, lineRange: NSRange) {
        textStorage.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        guard lineRange.length >= contentStart else { return }
        textStorage.addAttributes(
            [.foregroundColor: style.bulletColor],
            range: NSRange(location: lineRange.location, length: contentStart)
        )
    }

    private func styleNumberedList(_ textStorage: NSMutableAttributedString, contentStart: Int, lineRange: NSRange) {
        textStorage.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        textStorage.addAttributes(
            [.foregroundColor: style.bulletColor],
            range: NSRange(location: lineRange.location, length: min(contentStart, lineRange.length))
        )
    }

    private func styleChecklist(_ textStorage: NSMutableAttributedString, checked: Bool, contentStart: Int, lineRange: NSRange) {
        textStorage.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        guard lineRange.length >= contentStart else { return }
        textStorage.addAttributes(
            [.foregroundColor: style.syntaxHiddenColor, .font: NSFont.systemFont(ofSize: 0.1)],
            range: NSRange(location: lineRange.location, length: 2)
        )
        textStorage.addAttributes([
            .foregroundColor: checked ? style.checkboxCheckedColor : style.checkboxUncheckedColor,
            .font: NSFont.monospacedSystemFont(ofSize: style.baseFont.pointSize, weight: .medium),
        ], range: NSRange(location: lineRange.location + 2, length: 3))
        textStorage.addAttributes(
            [.foregroundColor: style.textColor],
            range: NSRange(location: lineRange.location + 5, length: 1)
        )

        if checked && lineRange.length > contentStart {
            textStorage.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: style.textColor.withAlphaComponent(0.4),
            ], range: NSRange(location: lineRange.location + contentStart, length: lineRange.length - contentStart))
        }
    }

    private func styleQuote(_ textStorage: NSMutableAttributedString, contentStart: Int, lineRange: NSRange) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.headIndent = 14
        paragraph.firstLineHeadIndent = 0
        paragraph.lineSpacing = 4
        textStorage.addAttributes([
            .paragraphStyle: paragraph,
            .foregroundColor: style.textColor.withAlphaComponent(0.75),
        ], range: lineRange)
        textStorage.addAttributes(
            [.foregroundColor: style.bulletColor],
            range: NSRange(location: lineRange.location, length: min(contentStart, lineRange.length))
        )
    }

    private func styleFenceLine(_ textStorage: NSMutableAttributedString, range: NSRange) {
        textStorage.addAttributes([.foregroundColor: style.codeFenceColor, .font: style.codeFont], range: range)
    }

    private func listParagraphStyle() -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.headIndent = style.listIndent
        paragraph.firstLineHeadIndent = 8
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 2
        paragraph.tabStops = [NSTextTab(textAlignment: .left, location: style.listIndent)]
        return paragraph
    }
}
