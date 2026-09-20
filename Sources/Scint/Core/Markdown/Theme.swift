import AppKit
import ScintComponents


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
    var bulletColor: NSColor
    var checkboxCheckedColor: NSColor
    var checkboxUncheckedColor: NSColor
    var linkLabelColor: NSColor
    var completedColor: NSColor
    var syntaxHiddenColor: NSColor

    static let dark = Theme(
        textColor: NSColor(Style.Foreground.primary),
        caretColor: NSColor(Style.Tint.accent.bright),
        caretWidth: 4,
        baseFont: Typography.Prose.text,
        h1Font: Typography.Prose.heading(1),
        h2Font: Typography.Prose.heading(2),
        h3Font: Typography.Prose.heading(3),
        codeFont: Typography.Prose.code,
        codeBgColor: NSColor(Style.Background.surface),
        bulletColor: NSColor.white.withAlphaComponent(Style.Opacity.outline),
        checkboxCheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.inactive),
        checkboxUncheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.outline),
        linkLabelColor: NSColor(Style.Foreground.primary).withAlphaComponent(1),
        completedColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.outline),
        syntaxHiddenColor: .clear
    )
}

