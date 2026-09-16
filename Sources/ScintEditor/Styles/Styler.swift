import AppKit

@MainActor final class Styler {
    var theme: Theme = .dark
    var baseAttributes: [NSAttributedString.Key: Any] {
        [.font: theme.baseFont, .foregroundColor: theme.textColor, .paragraphStyle: Typography.Prose.paragraphStyle]
    }
    func apply(to storage: NSMutableAttributedString, document: Markdown.Document, scope: [NSRange]) {
        let source = storage.string as NSString
        for requested in scope {
            let range = NSIntersectionRange(requested, NSRange(location: 0, length: storage.length))
            guard range.length > 0 else { continue }
            var attachments: [(NSRange, Any)] = []
            storage.enumerateAttribute(.attachment, in: range) { value, range, _ in if let value { attachments.append((range, value)) } }
            storage.setAttributes(baseAttributes, range: range)
            for (range, attachment) in attachments { storage.addAttribute(.attachment, value: attachment, range: range) }
            for block in document.blocks {
                let affected = NSIntersectionRange(block.range, range)
                guard affected.length > 0 else { continue }
                let paragraph = paragraphStyle(for: block, in: source)
                storage.addAttribute(.paragraphStyle, value: paragraph, range: affected)
                // List depth comes from the paragraph indent, so the source indent is hidden like the marker.
                if block.kind.isList, NSIntersectionRange(block.indent, range).length > 0 {
                    storage.addAttributes([.font: Typography.Prose.appKitSyntaxHidden, .foregroundColor: NSColor.clear], range: NSIntersectionRange(block.indent, range))
                }
            }
            for span in document.spans where span.kind == .inlineCode {
                for offset in [span.range.location - 1, NSMaxRange(span.range)] where offset >= 0 && offset < storage.length {
                    let padding = NSIntersectionRange(NSRange(location: offset, length: 1), range)
                    if padding.length > 0 { storage.addAttribute(.kern, value: Style.Spacing.sm, range: padding) }
                }
            }
            for span in document.spans {
                let affected = NSIntersectionRange(span.range, range)
                guard affected.length > 0 else { continue }
                let syntax: Bool
                switch span.kind {
                case .syntax, .quoteMarker, .listMarker, .codeFence, .linkURL: syntax = true
                default: syntax = false
                }
                let attributes: [NSAttributedString.Key: Any] = syntax ?
                    [.font: Typography.Prose.appKitSyntaxHidden,
                     .foregroundColor: NSColor.clear] :
                    attributes(for: span.kind, in: source, at: affected)
                storage.addAttributes(attributes, range: affected)
            }
        }
    }
    func paragraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        switch block.kind {
            case .heading(let level): return Typography.Prose.headingParagraphStyle(level)
            case .bullet, .numbered, .checklist: return listParagraphStyle(for: block, in: text)
            case .quote: return Typography.Prose.quoteParagraphStyle
            case .codeFence:
                let paragraph = NSMutableParagraphStyle()
                paragraph.maximumLineHeight = Typography.Scale.hiddenSyntax
                return paragraph
            case .codeBlock:
                let paragraph = NSMutableParagraphStyle()
                paragraph.setParagraphStyle(Typography.Prose.paragraphStyle)
                paragraph.headIndent = Style.Spacing.lg
                paragraph.firstLineHeadIndent = Style.Spacing.lg
                paragraph.tailIndent = -Style.Spacing.lg
                return paragraph
            case .paragraph: return Typography.Prose.paragraphStyle
        }
    }

    /// The marker is hidden and drawn in a gutter before the text, so every line of the item starts after it.
    /// A checklist's box stays visible text, so only its wrapped lines are pushed past it.
    func listParagraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        guard case .checklist = block.kind else {
            return Typography.Prose.listParagraphStyle(indent: listIndent(for: block) + gutter(for: block, in: text), hanging: 0)
        }
        let box = ("[ ] " as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .medium)]).width
        return Typography.Prose.listParagraphStyle(indent: listIndent(for: block), hanging: box)
    }

    func listIndent(for block: Markdown.Block) -> CGFloat {
        Style.Spacing.markdownListInset + CGFloat(block.depth) * Style.Spacing.listIndent
    }

    func gutter(for block: Markdown.Block, in text: NSString) -> CGFloat {
        (text.substring(with: block.marker) as NSString).size(withAttributes: [.font: theme.baseFont]).width
    }

    func attributes(
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

    func headingFont(_ level: Int) -> NSFont {
        switch level {
            case 1: return theme.h1Font
            case 2: return theme.h2Font
            default: return theme.h3Font
        }
    }

}
