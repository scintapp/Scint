import AppKit
import SwiftUI


enum Attribute {
    static func text(_ text: String, reasoning: Bool = false) -> AttributedString {
        let base = reasoning ? Style.Foreground.faint : Style.Foreground.base
        var attributed = AttributedString(text)
        attributed.font = reasoning ? Typography.prose.italic() : Typography.prose
        attributed.foregroundColor = base

        for span in Markdown.scan(text).spans {
            guard let range = range(span.range, source: text, attributed: attributed) else {
                continue
            }

            switch span.kind {
                case .heading(let level):
                    attributed[range].font = Typography.heading(level)

                case .quote:
                    attributed[range].font = Typography.quote
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .quoteMarker, .listMarker:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .checkbox(let checked):
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(
                        checked ? Style.Opacity.muted : Style.Opacity.faint
                    )

                case .completed:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .codeBlock:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.muted)

                case .codeFence:
                    attributed[range].font = Typography.prose
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.washed)

                case .strong:
                    attributed[range].font = Typography.prose.weight(.semibold)

                case .emphasis:
                    attributed[range].font = Typography.prose.italic()

                case .inlineCode:
                    attributed[range].font = Typography.proseCode
                    attributed[range].backgroundColor = Color.primary.opacity(Style.Opacity.washed)

                case .strikethrough:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)
                    attributed[range].strikethroughStyle = .single

                case .linkLabel:
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.strong)
                    attributed[range].underlineStyle = .single

                case .linkURL:
                    attributed[range].font = Typography.proseCode
                    attributed[range].foregroundColor = base.opacity(Style.Opacity.faint)

                case .syntax:
                    attributed[range].font = Typography.Prose.syntaxHidden
                    attributed[range].foregroundColor = .clear
            }
        }

        return attributed
    }

    static func range(_ range: NSRange, source: String, attributed: AttributedString) -> Range<AttributedString.Index>? {
        guard let sourceRange = Range(range, in: source) else { return nil }

        let lowerOffset = source.distance(from: source.startIndex, to: sourceRange.lowerBound)
        let upperOffset = source.distance(from: source.startIndex, to: sourceRange.upperBound)
        let characters = attributed.characters
        let lowerBound = characters.index(characters.startIndex, offsetBy: lowerOffset)
        let upperBound = characters.index(characters.startIndex, offsetBy: upperOffset)
        return lowerBound..<upperBound
    }
}

