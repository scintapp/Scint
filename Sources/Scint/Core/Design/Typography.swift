import AppKit
import SwiftUI


enum Typography {
    static let display = Font.system(size: 32, weight: .bold)
    static let title = Font.system(size: 20, weight: .semibold)
    static let subtitle = Font.system(size: 17, weight: .medium)
    static let prose = Font.system(size: 14, weight: .light)
    static let proseCode = Font.system(size: 14, design: .monospaced)
    static let quote = Font.system(size: 14, weight: .light)
    static let cardHeading = Font.system(size: 15, weight: .regular)
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
        private static let hiddenSyntaxSize: CGFloat = 0.1

        static var syntaxHidden: Font { .system(size: hiddenSyntaxSize) }
        static var appKitText: NSFont { .systemFont(ofSize: 16) }
        static var appKitCode: NSFont { .monospacedSystemFont(ofSize: 16, weight: .regular) }
        static var appKitSyntaxHidden: NSFont { .systemFont(ofSize: hiddenSyntaxSize) }

        static func appKitHeading(_ level: Int) -> NSFont {
            switch level {
                case 1: .systemFont(ofSize: 36, weight: .bold)
                case 2: .systemFont(ofSize: 24, weight: .bold)
                default: .systemFont(ofSize: 20, weight: .semibold)
            }
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

        static var listParagraphStyle: NSParagraphStyle {
            let paragraph = NSMutableParagraphStyle()
            paragraph.headIndent = Style.Spacing.listIndent
            paragraph.firstLineHeadIndent = .zero
            paragraph.lineSpacing = Style.Spacing.sm
            paragraph.paragraphSpacing = Style.Spacing.sm
            paragraph.tabStops = [
                NSTextTab(textAlignment: .left, location: Style.Spacing.listIndent)
            ]
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
