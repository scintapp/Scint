import AppKit


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
        caretColor: NSColor(Style.Tint.accent),
        caretWidth: 2,
        baseFont: Typography.Prose.appKitText,
        h1Font: Typography.Prose.appKitHeading(1),
        h2Font: Typography.Prose.appKitHeading(2),
        h3Font: Typography.Prose.appKitHeading(3),
        codeFont: Typography.Prose.appKitCode,
        codeBgColor: NSColor(Style.Background.overlay),
        bulletColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        checkboxCheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.muted),
        checkboxUncheckedColor: NSColor.white.withAlphaComponent(Style.Opacity.faint),
        linkLabelColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.strong),
        completedColor: NSColor(Style.Foreground.primary).withAlphaComponent(Style.Opacity.faint),
        syntaxHiddenColor: .clear
    )
}

