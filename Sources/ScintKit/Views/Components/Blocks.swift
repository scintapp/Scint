import AppKit
import SwiftUI


struct TaskCompletionIndicator: View {
    var completed: Bool

    var body: some View {
        Iconography.Icon(
            symbol: completed ? "checkmark.app" : "app",
            tint: completed ? Style.Foreground.subtle : Style.Foreground.faint,
            sizing: 18
        )
        .frame(width: 14, height: 14)
        .fontWeight(.light)
        .accessibilityHidden(true)
    }
}

struct TaskBlock: View {
    let content: String
    let completed: Bool
    let shape = Style.Shape.large

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.lg) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, Style.Spacing.xs)

            Text(content)
                .font(Typography.prose)
                .foregroundStyle(completed ? Style.Foreground.faint : Style.Foreground.primary)
                .strikethrough(completed, color: Style.Foreground.faint)
                .lineSpacing(Style.Spacing.markdownLineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, Style.Spacing.lg)
        .padding(.vertical, Style.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TextBlock: View {
    let content: String
    var reasoning = false
    @Environment(\.lineLimit) private var lineLimit

    var body: some View {
        let elements = Markdown.elements(content)
        if let lineLimit {
            ViewThatFits(in: .vertical) {
                ForEach((1...max(1, min(elements.count, lineLimit))).reversed(), id: \.self) { count in
                    render(Array(elements.prefix(count)))
                }
            }
            .frame(maxHeight: CGFloat(lineLimit) * (Typography.Prose.appKitLineHeight + Style.Spacing.markdownLineSpacing) + Style.Spacing.markdownTextInset * 2, alignment: .top)
            .clipped()
        } else {
            render(elements)
        }
    }

    private func render(_ elements: [Markdown.Element]) -> some View {
        VStack(alignment: .leading, spacing: .zero) {
            ForEach(Array(elements.enumerated()), id: \.offset) { index, element in
                block(element)
                    .padding(.top, index == 0 ? .zero : spacing(between: elements[index - 1], and: element))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Every list line is its own element, so a run of them is spaced as one list rather than as separate blocks.
    private func spacing(between above: Markdown.Element, and below: Markdown.Element) -> CGFloat {
        guard case .text(let upper, _, _, _) = above, case .text(let lower, _, _, _) = below,
              upper.isList, lower.isList else { return Style.Spacing.markdownBlockSpacing }
        return Style.Spacing.markdownListSpacing
    }

    @ViewBuilder private func block(_ element: Markdown.Element) -> some View {
        switch element {
            case .text(let kind, let text, let depth, let marker):
                HStack(alignment: .top, spacing: Style.Spacing.md) {
                    switch kind {
                        case .bullet:
                            Circle()
                                .fill(Style.Foreground.subtle)
                                .frame(width: Style.Dimension.markdownBullet, height: Style.Dimension.markdownBullet)
                                // Centred on the first line, which starts `markdownTextInset` down in the text beside it.
                                .frame(width: Style.Spacing.lg, height: Typography.Prose.appKitLineHeight + Style.Spacing.markdownTextInset * 2)
                        case .numbered:
                            Text(marker.trimmingCharacters(in: .whitespaces))
                                .font(Typography.prose)
                                .foregroundStyle(Style.Foreground.subtle)
                        case .checklist(let checked):
                            TaskCompletionIndicator(completed: checked)
                        default: EmptyView()
                    }
                    MarkdownText(content: text, font: font(kind), reasoning: reasoning, completed: kind == .checklist(checked: true))
                }
                .padding(.leading, kind.isList ? Style.Spacing.markdownListInset + CGFloat(depth) * Style.Spacing.listIndent : .zero)

            case .quote(let text):
                HStack(spacing: Style.Spacing.lg) {
                    Rectangle()
                        .fill(Style.Foreground.faint)
                        .frame(width: Style.Dimension.markdownQuoteBar)
                    MarkdownText(content: text, reasoning: true)
                        .padding(.vertical, Style.Spacing.sm)
                }
                .fixedSize(horizontal: false, vertical: true)

            case .code(let code, let language):
                VStack(alignment: .leading, spacing: Style.Spacing.md) {
                    if !language.isEmpty {
                        Text(language)
                            .font(Typography.label)
                            .foregroundStyle(Style.Foreground.muted)
                    }
                    ScrollView(.horizontal) {
                        Text(code)
                            .font(Typography.proseCode)
                            .foregroundStyle(Style.Foreground.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: true, vertical: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Style.Spacing.lg)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Style.Shape.small.fill(Style.Background.overlay))
                .overlay(Style.Shape.small.strokeBorder(Style.Border.raised, lineWidth: Style.Dimension.hairline))

            case .table(let rows, let alignments):
                MarkdownTable(rows: rows, alignments: alignments, reasoning: reasoning)
        }
    }

    private func font(_ kind: Markdown.BlockKind) -> NSFont {
        if case .heading(let level) = kind { return Typography.Prose.appKitHeading(level) }
        return Typography.Prose.appKitText
    }


}

struct MaterialBlock: View {
    let block: Material.Block
    var isSelected = false

    var body: some View {
        switch block {
            case .artifact(let ref), .command(let ref), .material(let ref):
                Card(ref: ref, style: .group, isSelected: isSelected)
            case .text(_, let content):
                TextBlock(content: content)
                    .background(Style.Shape.medium.fill(isSelected ? Style.Background.control : .clear))
            case .task(_, let content, let completed):
                TaskBlock(content: content, completed: completed)
                    .background(Style.Shape.medium.fill(isSelected ? Style.Background.control : .clear))
        }
    }
}
