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
        textColor: NSColor(Style.Foreground.base),
        caretColor: NSColor(Color.accentColor),
        caretWidth: 2,
        baseFont: Typography.Prose.appKitText,
        h1Font: Typography.Prose.appKitHeading(1),
        h2Font: Typography.Prose.appKitHeading(2),
        h3Font: Typography.Prose.appKitHeading(3),
        codeFont: Typography.Prose.appKitCode,
        codeBgColor: NSColor.white.withAlphaComponent(Style.Opacity.muted),
        codeFenceColor: NSColor.white.withAlphaComponent(Style.Opacity.washed),
        bulletColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        checkboxCheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.muted),
        checkboxUncheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        linkLabelColor: NSColor(Style.Foreground.base).withAlphaComponent(Style.Opacity.strong),
        linkURLColor: NSColor(Style.Foreground.base).withAlphaComponent(Style.Opacity.faint),
        completedColor: NSColor(Style.Foreground.base).withAlphaComponent(Style.Opacity.faint),
        syntaxHiddenColor: .clear
    )
}

/// The AppKit half of the markdown pipeline. `Markdown.scan` decides what each range *is*;
/// this decides what it looks like. The SwiftUI half is `Attribute.text`, which maps the same
/// spans onto `AttributedString` — the two stay in step because neither one classifies text.
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

    /// Builds a fresh attributed string. Used only when the editor first takes on a value —
    /// every subsequent restyle goes through `applyStyle(to:)`, which never touches characters.
    func attributedString(for text: String) -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text, attributes: baseAttributes)
        attributed.beginEditing()
        applyStyle(to: attributed)
        attributed.endEditing()
        substituteReferences(in: attributed)
        return attributed
    }

    /// Restyles `storage` in place, setting attributes only.
    ///
    /// This never replaces characters, which is what keeps marked text (IME composition, dead-key
    /// accents), the undo stack, and the selection anchor intact across a keystroke.
    ///
    /// It also does not open an edit transaction: the caller decides, because the main caller is
    /// `NSTextStorageDelegate.textStorage(_:didProcessEditing:…)`, which already runs inside one.
    /// Nesting `beginEditing`/`endEditing` there re-enters `processEditing`.
    /// Styles the storage, writing only where `scope` reaches.
    ///
    /// This runs from `didProcessEditing`, once per character, and a run holds the whole document —
    /// so re-attributing all of it per keystroke is what made typing unusable.
    ///
    /// The scan stays whole and the ranges stay absolute. An earlier version scanned just the
    /// edited lines and shifted the results back by the fragment's offset, which was faster still
    /// and silently produced no styling at all. Deciding from the whole document and *writing* to
    /// one line is the version with nothing to get wrong: what gets computed is identical to
    /// styling whole, and only the attribute writes and the layout they invalidate are narrowed.
    ///
    /// A fenced code block is the one construct spanning lines, so an edit anywhere in a document
    /// containing one restyles whole rather than leave following lines stale.
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

        // Each inline reference is one attachment character standing in for a whole link, and a
        // blanket `setAttributes` would strip it. Lift them out and put them back.
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
    }

    /// Replaces each `scint://` link with an attachment carrying the reference.
    ///
    /// Works back to front so the ranges ahead of each replacement stay valid. The attachment
    /// keeps the original markdown, which is what goes back to the document — the stored text is
    /// still exactly what was typed.
    private func substituteReferences(in storage: NSMutableAttributedString) {
        let source = storage.string as NSString

        for link in Markdown.scan(storage.string).links.reversed() {
            guard let ref = ReferenceURL.reference(in: source.substring(with: link.url)) else { continue }

            let attachment = ReferenceAttachment(
                ref: ref,
                label: source.substring(with: link.label),
                source: source.substring(with: link.range)
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
            case .paragraph, .codeFence, .codeBlock: return Typography.Prose.paragraphStyle
        }
    }

    /// Measures this item's own marker for the hanging indent, and adds one nesting step per level.
    private func listParagraphStyle(for block: Markdown.Block, in text: NSString) -> NSParagraphStyle {
        let prefix = text.substring(with: block.prefix)
        let hanging = (prefix as NSString).size(withAttributes: [.font: theme.baseFont]).width
        return Typography.Prose.listParagraphStyle(
            indent: CGFloat(block.depth) * Style.Spacing.listIndent,
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

            case .quoteMarker, .listMarker:
                return [.foregroundColor: theme.bulletColor]

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
                    .foregroundColor: theme.textColor.withAlphaComponent(Style.Opacity.disabled),
                ]

            case .codeFence:
                return [.font: theme.codeFont, .foregroundColor: theme.codeFenceColor]

            case .strong:
                return [.font: NSFont.systemFont(ofSize: theme.baseFont.pointSize, weight: .semibold)]

            case .emphasis:
                return [.font: NSFontManager.shared.convert(theme.baseFont, toHaveTrait: .italicFontMask)]

            case .inlineCode:
                return [.font: theme.codeFont, .backgroundColor: theme.codeBgColor]

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
                // An internal reference has no URL worth showing — the label is the whole point.
                // An external link keeps its address visible.
                guard !ReferenceURL.isReference(text.substring(with: range)) else {
                    return [
                        .foregroundColor: theme.syntaxHiddenColor,
                        .font: Typography.Prose.appKitSyntaxHidden,
                    ]
                }
                return [.font: theme.codeFont, .foregroundColor: theme.linkURLColor]

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
