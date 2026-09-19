//import AppKit
//import SwiftUI
//
//
//enum Typography {
//    enum Scale {
//        static let body: CGFloat = 14
//        static let code: CGFloat = 13
//        static let hiddenSyntax: CGFloat = 0.1
//        static let chip: CGFloat = 14
//        static let inline: CGFloat = 13
//        static let bodyWeight: Weight = .regular
//
//        static func heading(_ level: Int) -> CGFloat {
//            switch level {
//                case 1: 21
//                case 2: 18
//                default: 16
//            }
//        }
//
//        static func headingWeight(_ level: Int) -> Weight {
//            switch level {
//                case 1: .bold
//                case 2: .bold
//                default: .semibold
//            }
//        }
//
//        enum Weight {
//            case light
//            case regular
//            case medium
//            case semibold
//            case bold
//
//            var swiftUI: Font.Weight {
//                switch self {
//                    case .light: .light
//                    case .regular: .regular
//                    case .medium: .medium
//                    case .semibold: .semibold
//                    case .bold: .bold
//                }
//            }
//
//            var appKit: NSFont.Weight {
//                switch self {
//                    case .light: .light
//                    case .regular: .regular
//                    case .medium: .medium
//                    case .semibold: .semibold
//                    case .bold: .bold
//                }
//            }
//        }
//    }
//
//    static let display = Font.system(size: Scale.heading(1), weight: Scale.headingWeight(1).swiftUI)
//    static let title = Font.system(size: Scale.heading(2), weight: Scale.headingWeight(2).swiftUI)
//    static let subtitle = Font.system(size: Scale.heading(3), weight: Scale.headingWeight(3).swiftUI)
//    static let prose = Font.system(size: Scale.body, weight: Scale.bodyWeight.swiftUI)
//    static let proseCode = Font.system(size: Scale.code, design: .monospaced)
//    static let quote = Font.system(size: Scale.body, weight: Scale.bodyWeight.swiftUI)
//    static let chip = Font.system(size: Scale.chip, weight: .regular)
//    static let cardHeading = Font.system(size: 15, weight: .regular)
//    static let cardRow = Font.system(size: 14, weight: .regular)
//    static let cardTitle = Font.system(size: 13, weight: .medium)
//    static let row = Font.system(size: 13)
//    static let caption = Font.system(size: 13, weight: .light)
//    static let label = Font.system(size: 11)
//    static let badge = Font.system(size: 12)
//
//    static func cardDetail(_ design: Font.Design = .default) -> Font {
//        .system(
//            size: 13,
//            weight: design == .monospaced ? .medium : .regular,
//            design: design
//        )
//    }
//
//    static func heading(_ level: Int) -> Font {
//        switch level {
//            case 1: display
//            case 2: title
//            default: subtitle
//        }
//    }
//
//    static var appKitRow: NSFont { .systemFont(ofSize: 14) }
//
//    enum Prose {
//        static var syntaxHidden: Font { .system(size: Scale.hiddenSyntax) }
//        static var appKitText: NSFont { .systemFont(ofSize: Scale.body, weight: Scale.bodyWeight.appKit) }
//        static var appKitCode: NSFont { .monospacedSystemFont(ofSize: Scale.code, weight: .regular) }
//        static var appKitTableHeader: NSFont { .systemFont(ofSize: Scale.body, weight: .semibold) }
//        static var appKitSyntaxHidden: NSFont { .systemFont(ofSize: Scale.hiddenSyntax) }
//
//        static func appKitHeading(_ level: Int) -> NSFont {
//            .systemFont(ofSize: Scale.heading(level), weight: Scale.headingWeight(level).appKit)
//        }
//
//        static var appKitLineHeight: CGFloat {
//            let font = appKitText
//            return ceil(font.ascender - font.descender + font.leading)
//        }
//
//        static var paragraphStyle: NSParagraphStyle {
//            let paragraph = NSMutableParagraphStyle()
//            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
//            return paragraph
//        }
//
//        static func headingParagraphStyle(_ level: Int) -> NSParagraphStyle {
//            paragraphStyle
//        }
//
//        static func listParagraphStyle(indent: CGFloat, hanging: CGFloat) -> NSParagraphStyle {
//            let paragraph = NSMutableParagraphStyle()
//            paragraph.firstLineHeadIndent = indent
//            paragraph.headIndent = indent + hanging
//            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
//            paragraph.tabStops = [NSTextTab(textAlignment: .left, location: indent + hanging)]
//            return paragraph
//        }
//
//        static var quoteParagraphStyle: NSParagraphStyle {
//            let paragraph = NSMutableParagraphStyle()
//            paragraph.headIndent = Style.Spacing.lg
//            paragraph.firstLineHeadIndent = Style.Spacing.lg
//            paragraph.lineSpacing = Style.Spacing.markdownLineSpacing
//            return paragraph
//        }
//    }
//}
//
//enum Attribute {
//    static func text(_ text: String, reasoning: Bool = false) -> AttributedString {
//        let base = reasoning ? Style.Foreground.faint : Style.Foreground.primary
//        var attributed = AttributedString(text)
//        attributed.font = reasoning ? Typography.prose.italic() : Typography.prose
//        attributed.foregroundColor = base
//
//        for span in Markdown.scan(text).spans {
//            guard let range = range(span.range, source: text, attributed: attributed) else {
//                continue
//            }
//
//            switch span.kind {
//                case .heading(let level):
//                    attributed[range].font = Typography.heading(level)
//
//                case .quote:
//                    attributed[range].font = Typography.quote
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)
//
//                case .quoteMarker, .listMarker:
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
//
//                case .checkbox(let checked):
//                    attributed[range].font = Typography.proseCode
//                    attributed[range].foregroundColor = base.opacity(
//                        checked ? Style.Opacity.muted : Style.Opacity.faint
//                    )
//
//                case .completed:
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
//                    attributed[range].strikethroughStyle = .single
//
//                case .codeBlock:
//                    attributed[range].font = Typography.prose
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)
//
//                case .codeFence:
//                    attributed[range].font = Typography.prose
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.washed)
//
//                case .strong:
//                    attributed[range].font = Typography.prose.weight(.semibold)
//
//                case .emphasis:
//                    attributed[range].font = Typography.prose.italic()
//
//                case .inlineCode:
//                    attributed[range].font = Typography.proseCode
//                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.washed)
//
//                case .strikethrough:
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
//                    attributed[range].strikethroughStyle = .single
//
//                case .linkLabel:
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.strong)
//                    attributed[range].underlineStyle = .single
//
//                case .linkURL:
//                    attributed[range].font = Typography.proseCode
//                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
//
//                case .syntax:
//                    attributed[range].font = Typography.Prose.syntaxHidden
//                    attributed[range].foregroundColor = .clear
//            }
//        }
//
//        return attributed
//    }
//
//    static func range(_ range: NSRange, source: String, attributed: AttributedString) -> Range<AttributedString.Index>? {
//        guard let sourceRange = Range(range, in: source) else { return nil }
//
//        let lowerOffset = source.distance(from: source.startIndex, to: sourceRange.lowerBound)
//        let upperOffset = source.distance(from: source.startIndex, to: sourceRange.upperBound)
//        let characters = attributed.characters
//        let lowerBound = characters.index(characters.startIndex, offsetBy: lowerOffset)
//        let upperBound = characters.index(characters.startIndex, offsetBy: upperOffset)
//        return lowerBound..<upperBound
//    }
//}
