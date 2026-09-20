import AppKit
import ScintRuntime
import ScintComponents


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

            for (index, block) in document.blocks.enumerated() {
                let affected = NSIntersectionRange(block.range, range)
                guard affected.length > 0 else { continue }
                let next = document.blocks.indices.contains(index + 1) ? document.blocks[index + 1] : nil
                let paragraph = paragraphStyle(for: block, followedBy: next, in: source)
                storage.addAttribute(.paragraphStyle, value: paragraph, range: affected)
                if block.kind.isList, NSIntersectionRange(block.indent, range).length > 0 {
                    storage.addAttributes([.font: Typography.Prose.hiddenSyntax, .foregroundColor: NSColor.clear], range: NSIntersectionRange(block.indent, range))
                }
            }

            for span in document.spans where span.kind == .inlineCode {
                for offset in [span.range.location - 1, NSMaxRange(span.range)] where offset >= 0 && offset < storage.length {
                    let padding = NSIntersectionRange(NSRange(location: offset, length: 1), range)
                    if padding.length > 0 { storage.addAttribute(.kern, value: Style.Spacing.detail, range: padding) }
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
                    [.font: Typography.Prose.hiddenSyntax,
                     .foregroundColor: NSColor.clear] :
                    attributes(for: span.kind, in: source, at: affected)
                storage.addAttributes(attributes, range: affected)
            }
        }
    }

    /// Every gap belongs to the block above it, so no two styles can both claim one.
    func paragraphStyle(for block: Markdown.Block, followedBy next: Markdown.Block?, in text: NSString) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.setParagraphStyle(indents(for: block, in: text))
        paragraph.paragraphSpacing = spacing(after: block, before: next)
        return paragraph
    }

    /// The room between a block and whatever follows it. Lines of one quote or one
    /// fenced block are a single thing to the reader, and so are items of one list.
    private func spacing(after block: Markdown.Block, before next: Markdown.Block?) -> CGFloat {
        guard let next else { return 0 }
        if case .heading = next.kind { return Typography.Prose.headingSpacing }
        if block.kind.isList, next.kind.isList { return Typography.Prose.listSpacing }
        // A fence and the lines it wraps are one block, though they are three kinds.
        if isCode(block.kind), isCode(next.kind) { return 0 }
        if block.kind == next.kind, !isBreaking(block.kind) { return 0 }
        return Typography.Prose.blockSpacing
    }

    private func isCode(_ kind: Markdown.BlockKind) -> Bool {
        kind == .codeFence || kind == .codeBlock
    }

    /// Kinds whose consecutive lines really are separate blocks, because the author
    /// wrote them as separate paragraphs rather than as one wrapped construct.
    private func isBreaking(_ kind: Markdown.BlockKind) -> Bool {
        if case .paragraph = kind { return true }
        if case .heading = kind { return true }
        return false
    }

    private func indents(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        switch block.kind {
            case .heading:
                return Typography.Prose.paragraphStyle

            case .bullet, .numbered, .checklist:
                return listParagraphStyle(for: block, in: text)

            case .codeBlock:
                return Typography.Prose.paragraphStyle

            case .codeFence:
                let paragraph = NSMutableParagraphStyle()
                paragraph.maximumLineHeight = Typography.Prose.hiddenSyntax.pointSize
                return paragraph

            case .quote:
                return Typography.Prose.quoteParagraphStyle

            case .paragraph:
                return Typography.Prose.paragraphStyle
        }
    }

    func listParagraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        guard case .checklist = block.kind else {
            return Typography.Prose.listParagraphStyle(indent: listIndent(for: block) + Typography.Prose.markerWidth + Typography.Prose.markerGap, hanging: 0)
        }
        let box = ("[ ] " as NSString).size(withAttributes: [.font: NSFont.monospacedSystemFont(ofSize: theme.baseFont.pointSize, weight: .medium)]).width
        return Typography.Prose.listParagraphStyle(indent: listIndent(for: block), hanging: box)
    }

    func listIndent(for block: Markdown.Block) -> CGFloat {
        Typography.Prose.listInset + CGFloat(block.depth) * Typography.Prose.listIndent
    }

    func gutter(for block: Markdown.Block, in text: NSString) -> CGFloat {
        (text.substring(with: block.marker) as NSString).size(withAttributes: [.font: theme.baseFont]).width
    }

    func attributes(for kind: Markdown.Kind, in text: NSString, at range: NSRange) -> [NSAttributedString.Key: Any] {
        switch kind {
            case .heading(let level):
                return [.font: headingFont(level)]

            case .quote:
                return [.foregroundColor: theme.textColor.withAlphaComponent(Style.Opacity.inactive)]

            case .quoteMarker:
                return [.foregroundColor: theme.syntaxHiddenColor, .font: Typography.Prose.hiddenSyntax]

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
                return [.font: Typography.Prose.hiddenSyntax, .foregroundColor: theme.syntaxHiddenColor]

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
                return [.foregroundColor: theme.syntaxHiddenColor, .font: Typography.Prose.hiddenSyntax]

            case .syntax:
                return [
                    .foregroundColor: theme.syntaxHiddenColor,
                    .font: Typography.Prose.hiddenSyntax,
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
