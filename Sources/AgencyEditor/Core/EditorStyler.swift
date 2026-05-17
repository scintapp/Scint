import AppKit
import SwiftUI


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
        h1Font: .systemFont(ofSize: 20, weight: .semibold),
        h2Font: .systemFont(ofSize: 18, weight: .medium),
        h3Font: .systemFont(ofSize: 16, weight: .medium),
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

    func attributedString(for text: String, resolveInlineEntry: (UUID) -> Entry?) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        applyFullStyle(to: attributed, resolveInlineEntry: resolveInlineEntry)
        return attributed
    }

    var typingAttributes: [NSAttributedString.Key: Any] {
        baseAttributes
    }

    private func applyFullStyle(to textStorage: NSMutableAttributedString, resolveInlineEntry: (UUID) -> Entry?) {
        textStorage.beginEditing()
        replaceInlineComponents(in: textStorage, resolveInlineEntry: resolveInlineEntry)

        let fullString = textStorage.string
        let fullRange = NSRange(location: 0, length: textStorage.length)
        guard !fullString.isEmpty else {
            textStorage.endEditing()
            return
        }

        let nsString = fullString as NSString
        textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            guard value == nil else { return }
            textStorage.setAttributes(baseAttributes, range: range)
        }

        var insideFence = false
        var lineStart = 0

        while lineStart < nsString.length {
            var lineEnd = 0, contentsEnd = 0
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

    private func replaceInlineComponents(in textStorage: NSMutableAttributedString, resolveInlineEntry: (UUID) -> Entry?) {
        let text = textStorage.string
        let matches = EditorAttachment.matches(in: text)

        guard !matches.isEmpty else { return }

        for match in matches.reversed() {
            guard let id = EditorAttachment.id(in: match, text: text),
                  let entry = resolveInlineEntry(id) else { continue }

            let attachment = EditorAttachment(entry: entry)
            textStorage.replaceCharacters(in: match.range, with: NSAttributedString(attachment: attachment))
        }
    }

    private struct InlinePattern {
        let regex: NSRegularExpression
        let attrs: [NSAttributedString.Key: Any]
        let delimLength: Int
    }

    private lazy var inlinePatterns: [InlinePattern] = {
        func r(_ p: String) -> NSRegularExpression { try! NSRegularExpression(pattern: p) }
        return [
            InlinePattern(
                regex: r(#"(\*\*|__)(?!\s)(.+?)(?<!\s)(\*\*|__)"#),
                attrs: [.font: NSFont.systemFont(ofSize: style.baseFont.pointSize, weight: .bold)],
                delimLength: 2
            ),
            InlinePattern(
                regex: r(#"(?<!\*)\*(?!\*)(?!\s)(.+?)(?<!\s)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(?!\s)(.+?)(?<!\s)(?<!_)_(?!_)"#),
                attrs: [.font: NSFontManager.shared.convert(style.baseFont, toHaveTrait: .italicFontMask)],
                delimLength: 1
            ),
            InlinePattern(
                regex: r(#"`([^`\n]+)`"#),
                attrs: [.font: style.codeFont, .backgroundColor: style.codeBgColor],
                delimLength: 1
            ),
            InlinePattern(
                regex: r(#"~~(?!\s)(.+?)(?<!\s)~~"#),
                attrs: [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: style.textColor.withAlphaComponent(0.45),
                ],
                delimLength: 2
            ),
        ]
    }()

    private func styleInline(_ ts: NSMutableAttributedString, in range: NSRange) {
        let str = (ts.string as NSString).substring(with: range)

        let hideAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: style.syntaxHiddenColor,
            .font: NSFont.systemFont(ofSize: 0.1),
        ]

        for pattern in inlinePatterns {
            let matches = pattern.regex.matches(in: str, range: NSRange(str.startIndex..., in: str))
            for match in matches {
                let full = NSRange(location: range.location + match.range.location,
                                   length: match.range.length)
                guard full.length > pattern.delimLength * 2 else { continue }

                let open  = NSRange(location: full.location, length: pattern.delimLength)
                let close = NSRange(location: full.location + full.length - pattern.delimLength, length: pattern.delimLength)
                let inner = NSRange(location: open.location + open.length,length: full.length - pattern.delimLength * 2)

                ts.addAttributes(pattern.attrs, range: inner)
                ts.addAttributes(hideAttrs, range: open)
                ts.addAttributes(hideAttrs, range: close)
            }
        }

        styleLinks(ts, str: str, offset: range.location, hideAttrs: hideAttrs)
    }

    private func styleLinks(_ ts: NSMutableAttributedString, str: String, offset: Int,
                             hideAttrs: [NSAttributedString.Key: Any]) {
        guard let regex = try? NSRegularExpression(pattern: #"\[([^\]\n]+)\]\(([^)\n]+)\)"#) else { return }
        for match in regex.matches(in: str, range: NSRange(str.startIndex..., in: str)) {
            guard match.numberOfRanges == 3 else { continue }
            let labelRange = NSRange(location: offset + match.range(at: 1).location,
                                     length: match.range(at: 1).length)
            let urlRange   = NSRange(location: offset + match.range(at: 2).location,
                                     length: match.range(at: 2).length)

            ts.addAttributes(hideAttrs, range: NSRange(location: offset + match.range.location, length: 1))
            ts.addAttributes([.foregroundColor: style.textColor.withAlphaComponent(0.75)], range: labelRange)
            ts.addAttributes(hideAttrs, range: NSRange(location: labelRange.location + labelRange.length, length: 2))
            ts.addAttributes([.font: style.codeFont, .foregroundColor: style.textColor.withAlphaComponent(0.3),], range: urlRange)
            ts.addAttributes(hideAttrs, range: NSRange(location: urlRange.location + urlRange.length, length: 1))
        }
    }

    private enum LineKind {
        case heading(level: Int, contentStart: Int)
        case bulletList(contentStart: Int)
        case numberedList(number: String, contentStart: Int)
        case checklistUnchecked(contentStart: Int)
        case checklistChecked(contentStart: Int)
        case codeFence(language: String?)
        case plain
    }

    private func classify(_ line: String) -> LineKind {
        if line.hasPrefix("- [ ] ") { return .checklistUnchecked(contentStart: 6) }
        if line.hasPrefix("- [x] ") || line.hasPrefix("- [X] ") { return .checklistChecked(contentStart: 6) }
        if line.hasPrefix("```") { return .codeFence(language: String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)) }
        if line.hasPrefix("### ") { return .heading(level: 3, contentStart: 4) }
        if line.hasPrefix("## ")  { return .heading(level: 2, contentStart: 3) }
        if line.hasPrefix("# ")   { return .heading(level: 1, contentStart: 2) }
        if let match = line.range(of: #"^\d+\.\s"#, options: .regularExpression) {
            let num = String(line[..<line.index(before: match.upperBound)])
                .trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ".", with: "")
            return .numberedList(number: num, contentStart: line.distance(from: line.startIndex, to: match.upperBound))
        }
        if line.hasPrefix("- ") { return .bulletList(contentStart: 2) }
        return .plain
    }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle(); para.lineSpacing = 4
        return [.font: style.baseFont, .foregroundColor: style.textColor, .paragraphStyle: para]
    }

    private func styleLine(_ ts: NSMutableAttributedString, kind: LineKind, lineRange: NSRange) {
        switch kind {
        case .heading(let l, let cs): styleHeading(ts, level: l, contentStart: cs, lineRange: lineRange)
        case .bulletList(let cs): styleBulletList(ts, contentStart: cs, lineRange: lineRange)
        case .numberedList(_, let cs): styleNumberedList(ts, contentStart: cs, lineRange: lineRange)
        case .checklistUnchecked(let cs): styleChecklist(ts, checked: false, contentStart: cs, lineRange: lineRange)
        case .checklistChecked(let cs): styleChecklist(ts, checked: true,  contentStart: cs, lineRange: lineRange)
        case .plain, .codeFence: break
        }
    }

    private func styleHeading(_ ts: NSMutableAttributedString, level: Int, contentStart: Int, lineRange: NSRange) {
        let (font, spacing): (NSFont, CGFloat) = level == 1 ? (style.h1Font, 12) : level == 2 ? (style.h2Font, 8) : (style.h3Font, 6)
        let para = NSMutableParagraphStyle()
        para.lineSpacing = 2; para.paragraphSpacingBefore = spacing; para.paragraphSpacing = 4
        ts.addAttributes([.paragraphStyle: para], range: lineRange)
        let contentRange = NSRange(location: lineRange.location + contentStart, length: lineRange.length - contentStart)
        if contentRange.length > 0 { ts.addAttributes([.font: font], range: contentRange) }
        ts.addAttributes([.foregroundColor: style.syntaxHiddenColor, .font: NSFont.systemFont(ofSize: 0.1)],
                         range: NSRange(location: lineRange.location, length: contentStart))
    }

    private func styleBulletList(_ ts: NSMutableAttributedString, contentStart: Int, lineRange: NSRange) {
        ts.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        guard lineRange.length >= 2 else { return }
        ts.addAttributes([.foregroundColor: style.bulletColor],
                         range: NSRange(location: lineRange.location, length: 2))
    }

    private func styleNumberedList(_ ts: NSMutableAttributedString, contentStart: Int, lineRange: NSRange) {
        ts.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        ts.addAttributes([.foregroundColor: style.bulletColor],
                         range: NSRange(location: lineRange.location, length: min(contentStart, lineRange.length)))
    }

    private func styleChecklist(_ ts: NSMutableAttributedString, checked: Bool, contentStart: Int, lineRange: NSRange) {
        ts.addAttributes([.paragraphStyle: listParagraphStyle()], range: lineRange)
        guard lineRange.length >= 6 else { return }
        ts.addAttributes([.foregroundColor: style.syntaxHiddenColor, .font: NSFont.systemFont(ofSize: 0.1)],
                         range: NSRange(location: lineRange.location, length: 2))
        ts.addAttributes([
            .foregroundColor: checked ? style.checkboxCheckedColor : style.checkboxUncheckedColor,
            .font: NSFont.monospacedSystemFont(ofSize: style.baseFont.pointSize, weight: .medium),
        ], range: NSRange(location: lineRange.location + 2, length: 3))
        ts.addAttributes([.foregroundColor: style.textColor],
                         range: NSRange(location: lineRange.location + 5, length: 1))
        if checked && lineRange.length > contentStart {
            ts.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .foregroundColor: style.textColor.withAlphaComponent(0.4),
            ], range: NSRange(location: lineRange.location + contentStart, length: lineRange.length - contentStart))
        }
    }

    private func styleFenceLine(_ ts: NSMutableAttributedString, range: NSRange) {
        ts.addAttributes([.foregroundColor: style.codeFenceColor, .font: style.codeFont], range: range)
    }

    private func listParagraphStyle() -> NSParagraphStyle {
        let p = NSMutableParagraphStyle()
        p.headIndent = style.listIndent; p.firstLineHeadIndent = 8; p.lineSpacing = 3; p.paragraphSpacing = 2
        p.tabStops = [NSTextTab(textAlignment: .left, location: style.listIndent)]
        return p
    }
}
