import AppKit
import SwiftUI


enum Typography {
    /// The one prose scale.
    ///
    /// SwiftUI prose (`Typography.prose`, transcripts and cards) and AppKit prose
    /// (`Typography.Prose.appKit*`, the editor) both derive from this, so one document renders at
    /// one size wherever it appears. The two used to carry independent numbers — 13pt body and
    /// 24/20/17 headings on the SwiftUI side against 16pt body and 36/24/20 headings in the
    /// editor — so the same text changed size when it moved between surfaces.
    enum Scale {
        static let body: CGFloat = 14
        static let code: CGFloat = 14
        static let hiddenSyntax: CGFloat = 0.1
        /// Inline reference chips, a step down from the prose they sit in so a chip reads as a
        /// token within the sentence rather than an interruption of it.
        static let chip: CGFloat = 12
        static let inline: CGFloat = 11
        static let bodyWeight: Weight = .light

        static func heading(_ level: Int) -> CGFloat {
            switch level {
                case 1: 24
                case 2: 20
                default: 17
            }
        }

        static func headingWeight(_ level: Int) -> Weight {
            switch level {
                case 1: .bold
                case 2: .semibold
                default: .medium
            }
        }

        /// Bridges one weight onto both font APIs so the scale can name a single value.
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
    static let cardHeading = Font.system(size: 14, weight: .regular)
    static let cardRow = Font.system(size: 13, weight: .regular)
    static let cardTitle = Font.system(size: 12, weight: .medium)
    static let row = Font.system(size: 12)
    static let caption = Font.system(size: 12, weight: .light)
    static let label = Font.system(size: 10)
    static let badge = Font.system(size: 11, weight: .medium)

    static func cardDetail(_ design: Font.Design = .default) -> Font {
        .system(
            size: 12,
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

    static var appKitRow: NSFont { .systemFont(ofSize: 13) }

    enum Prose {
        static var syntaxHidden: Font { .system(size: Scale.hiddenSyntax) }
        static var appKitText: NSFont { .systemFont(ofSize: Scale.body, weight: Scale.bodyWeight.appKit) }
        static var appKitCode: NSFont { .monospacedSystemFont(ofSize: Scale.code, weight: .regular) }
        static var appKitSyntaxHidden: NSFont { .systemFont(ofSize: Scale.hiddenSyntax) }

        static func appKitHeading(_ level: Int) -> NSFont {
            .systemFont(ofSize: Scale.heading(level), weight: Scale.headingWeight(level).appKit)
        }

        /// Line height of the body font, for anything that has to match a line of prose —
        /// the caret, and the minimum height of an empty block.
        static var appKitLineHeight: CGFloat {
            let font = appKitText
            return ceil(font.ascender - font.descender + font.leading)
        }

        static var paragraphStyle: NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = Style.Spacing.sm
            paragraph.paragraphSpacing = .zero
            return paragraph
        }

        static func headingParagraphStyle(_ level: Int) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            switch level {
                case 1:
                    paragraph.lineSpacing = .zero
                    paragraph.paragraphSpacingBefore = .zero
                    paragraph.paragraphSpacing = Style.Spacing.xl
                case 2:
                    paragraph.lineSpacing = Style.Spacing.xs
                    paragraph.paragraphSpacingBefore = Style.Spacing.xxl
                    paragraph.paragraphSpacing = Style.Spacing.lg
                default:
                    paragraph.lineSpacing = Style.Spacing.sm
                    paragraph.paragraphSpacingBefore = Style.Spacing.xl
                    paragraph.paragraphSpacing = Style.Spacing.md
            }
            return paragraph
        }

        /// - Parameters:
        ///   - indent: how far the whole item sits in, from its nesting depth.
        ///   - hanging: the width of this item's own marker, so wrapped lines align under the
        ///     content instead of under a single constant guessed for one marker.
        static func listParagraphStyle(indent: CGFloat, hanging: CGFloat) -> NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.firstLineHeadIndent = indent
            paragraph.headIndent = indent + hanging
            paragraph.lineSpacing = Style.Spacing.sm
            paragraph.paragraphSpacing = Style.Spacing.sm
            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: indent + hanging)]
            return paragraph
        }

        static var quoteParagraphStyle: NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = .zero
            paragraph.firstLineHeadIndent = .zero
            paragraph.lineSpacing = Style.Spacing.sm
            paragraph.paragraphSpacing = Style.Spacing.lg
            return paragraph
        }
    }
}
