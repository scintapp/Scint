import AppKit
import SwiftUI


struct Theme: @unchecked Sendable {
    var textColor: NSColor
    var caretColor: NSColor
    var caretWidth: CGFloat
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
    var linkLabelColor: NSColor
    var linkURLColor: NSColor
    var completedColor: NSColor
    var syntaxHiddenColor: NSColor

    static let dark = Theme(
        textColor: NSColor(Style.Foreground.primary),
        caretColor: NSColor(Color.accentColor),
        caretWidth: 2,
        baseFont: Typography.Prose.appKitText,
        h1Font: Typography.Prose.appKitHeading(1),
        h2Font: Typography.Prose.appKitHeading(2),
        h3Font: Typography.Prose.appKitHeading(3),
        codeFont: Typography.Prose.appKitCode,
        codeBgColor: NSColor(Style.Background.overlay),
        codeFenceColor: NSColor.white.withAlphaComponent(Style.Opacity.washed),
        bulletColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        checkboxCheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.muted),
        checkboxUncheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        linkLabelColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.strong),
        linkURLColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.faint),
        completedColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.faint),
        syntaxHiddenColor: .clear
    )
}

@MainActor final class EditorThemer: NSObject {
    var theme: Theme = .dark
    var typingAttributes: [NSAttributedString.Key: Any] { baseAttributes }

    private var baseAttributes: [NSAttributedString.Key: Any] {
        [
            .font: theme.baseFont,
            .foregroundColor: theme.textColor,
            .paragraphStyle: Typography.Prose.paragraphStyle,
        ]
    }

    func attributedString(for text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        attributed.beginEditing()
        applyStyle(to: attributed)
        attributed.endEditing()
        substituteTables(in: attributed)
        substituteReferences(in: attributed)
        return attributed
    }

    private func substituteTables(in storage: NSMutableAttributedString) {
        let source = storage.string as NSString
        for range in Markdown.tableRanges(storage.string).reversed() {
            let attachment = MarkdownTableAttachment(source: source.substring(with: range))
            let replacement = NSMutableAttributedString(attachment: attachment)
            replacement.addAttributes(baseAttributes, range: NSRange(location: 0, length: replacement.length))
            storage.replaceCharacters(in: range, with: replacement)
        }
    }

    func applyStyle(to storage: NSMutableAttributedString, in scope: NSRange? = nil) {
        let text = storage.string
        let full = NSRange(location: 0, length: storage.length)
        let source = text as NSString

        let scoped: NSRange = {
            guard let scope, !Markdown.holdsMultipleLines(text), full.length > 0 else { return full }
            let location = min(max(scope.location, 0), full.length)
            let length = min(max(scope.length, 0), full.length - location)
            return source.lineRange(for: NSRange(location: location, length: length))
        }()

        var attachments: [(NSRange, NSTextAttachment)] = []
        storage.enumerateAttribute(.attachment, in: scoped) { value, range, _ in
            if let attachment = value as? NSTextAttachment { attachments.append((range, attachment)) }
        }

        storage.setAttributes(baseAttributes, range: scoped)
        for (range, attachment) in attachments {
            storage.addAttribute(.attachment, value: attachment, range: range)
        }
        guard !text.isEmpty, scoped.length > 0 else { return }

        let document = Markdown.scan(text)

        for block in document.blocks {
            let range = NSIntersectionRange(block.range, scoped)
            guard range.length > 0 else { continue }
            storage.addAttributes([.paragraphStyle: paragraphStyle(for: block, in: source)], range: range)
        }

        for span in document.spans {
            let range = NSIntersectionRange(clamp(span.range, within: full), scoped)
            guard range.length > 0 else { continue }
            storage.addAttributes(attributes(for: span.kind, in: source, at: range), range: range)
        }

        for link in document.links {
            let range = NSIntersectionRange(link.label, scoped)
            guard range.length > 0, let url = URL(string: source.substring(with: link.url)) else { continue }
            storage.addAttribute(.link, value: url, range: range)
        }

        for span in document.spans where span.kind == .inlineCode {
            let codeRange = NSIntersectionRange(span.range, scoped)
            if codeRange.length > 0 { storage.addAttribute(.font, value: theme.codeFont, range: codeRange) }
            for location in [span.range.location - 1, NSMaxRange(span.range)] where location >= 0 && location < storage.length {
                let range = NSIntersectionRange(NSRange(location: location, length: 1), scoped)
                if range.length > 0 { storage.addAttribute(.kern, value: Style.Spacing.sm, range: range) }
            }
        }
    }

    private func substituteReferences(in storage: NSMutableAttributedString) {
        let source = storage.string as NSString

        for link in Markdown.scan(storage.string).links.reversed() {
            guard let ref = Reference.Link.reference(in: source.substring(with: link.url)) else { continue }

            let attachment = ReferenceAttachment(
                ref: ref,
                label: source.substring(with: link.label),
                source: source.substring(with: link.range),
                standalone: ReferenceAttachment.isStandalone(in: source, range: link.range)
            )
            let replacement = NSMutableAttributedString(attachment: attachment)
            replacement.addAttributes(
                baseAttributes,
                range: NSRange(location: 0, length: replacement.length)
            )
            storage.replaceCharacters(in: link.range, with: replacement)
        }
    }

    private func paragraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        switch block.kind {
            case .heading(let level): return Typography.Prose.headingParagraphStyle(level)
            case .bullet, .numbered, .checklist: return listParagraphStyle(for: block, in: text)
            case .quote: return Typography.Prose.quoteParagraphStyle
            case .codeFence:
                let paragraph = NSMutableParagraphStyle()
                paragraph.maximumLineHeight = Typography.Scale.hiddenSyntax
                return paragraph
            case .codeBlock:
                let paragraph = Typography.Prose.paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
                paragraph.headIndent = Style.Spacing.lg
                paragraph.firstLineHeadIndent = Style.Spacing.lg
                paragraph.tailIndent = -Style.Spacing.lg
                return paragraph
            case .paragraph: return Typography.Prose.paragraphStyle
        }
    }

    private func listParagraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        let prefix = text.substring(with: block.prefix)
        let hanging = (prefix as NSString).size(withAttributes: [.font: theme.baseFont]).width
        return Typography.Prose.listParagraphStyle(
            indent: Style.Spacing.markdownListInset + CGFloat(block.depth) * Style.Spacing.listIndent,
            hanging: hanging
        )
    }

    private func attributes(
        for kind: Markdown.Kind,
        in text: NSString,
        at range: NSRange
    ) -> [NSAttributedString.Key: Any] {
        switch kind {
            case .heading(let level):
                return [.font: headingFont(level)]

            case .quote:
                return [.foregroundColor: theme.textColor.withAlphaComponent(Style.Opacity.muted)]

            case .quoteMarker:
                return [.foregroundColor: theme.syntaxHiddenColor, .font: Typography.Prose.appKitSyntaxHidden]

            case .listMarker:
                let ordered = text.substring(with: range).first?.isNumber == true
                return [.foregroundColor: ordered ? theme.bulletColor : theme.syntaxHiddenColor]

            case .checkbox(let checked):
                return [
                    .foregroundColor: checked ? theme.checkboxCheckedColor : theme.checkboxUncheckedColor,
                    .font: NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .medium),
                ]

            case .completed:
                return [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: theme.completedColor,
                ]

            case .codeBlock:
                return [
                    .font: theme.codeFont,
                    .foregroundColor: theme.textColor,
                ]

            case .codeFence:
                return [.font: Typography.Prose.appKitSyntaxHidden, .foregroundColor: theme.syntaxHiddenColor]

            case .strong:
                return [.font: NSFont.systemFont(ofSize: theme.baseFont.pointSize, weight: .semibold)]

            case .emphasis:
                return [.font: NSFontManager.shared.convert(theme.baseFont, toHaveTrait: .italicFontMask)]

            case .inlineCode:
                return [.font: theme.codeFont]

            case .strikethrough:
                return [
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .foregroundColor: theme.completedColor,
                ]

            case .linkLabel:
                return [
                    .foregroundColor: theme.linkLabelColor,
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                ]

            case .linkURL:
                return [.foregroundColor: theme.syntaxHiddenColor, .font: Typography.Prose.appKitSyntaxHidden]

            case .syntax:
                return [
                    .foregroundColor: theme.syntaxHiddenColor,
                    .font: Typography.Prose.appKitSyntaxHidden,
                ]
        }
    }

    private func headingFont(_ level: Int) -> NSFont {
        switch level {
            case 1: return theme.h1Font
            case 2: return theme.h2Font
            default: return theme.h3Font
        }
    }

    private func clamp(_ range: NSRange, within bounds: NSRange) -> NSRange {
        let location = min(max(range.location, bounds.location), NSMaxRange(bounds))
        return NSRange(location: location, length: min(range.length, NSMaxRange(bounds) - location))
    }
}
