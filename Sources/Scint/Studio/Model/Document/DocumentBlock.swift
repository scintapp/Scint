import AppKit
import SwiftUI
import ScintRuntime
import ScintComponents

internal typealias Block = ScintRuntime.Document.Block

struct TaskCompletionIndicator: View {
    var completed: Bool

    var body: some View {
        Iconography.Icon(
            symbol: completed ? "checkmark.app" : "app",
            tint: completed ? Style.Foreground.secondary : Style.Foreground.secondary,
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
    let shape = Style.Shape.panel

    var body: some View {
        HStack(alignment: .top, spacing: Style.Spacing.icon) {
            TaskCompletionIndicator(completed: completed)
                .padding(.top, 4)

            Text(content)
                .font(Typography.body)
                .foregroundStyle(completed ? Style.Foreground.secondary : Style.Foreground.primary)
                .strikethrough(completed, color: Style.Foreground.secondary)
                .lineSpacing(Typography.Prose.lineSpacing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TextBlock: View {
    @Environment(\.lineLimit) private var lineLimit
    let content: String
    var reasoning = false
    var hugs = false

    var line: CGFloat { ceil(Typography.Prose.text.ascender - Typography.Prose.text.descender + Typography.Prose.text.leading) }

    var body: some View {
        let elements = Markdown.elements(content)
        if let lineLimit {
            ViewThatFits(in: .vertical) {
                ForEach((1...max(1, min(elements.count, lineLimit))).reversed(), id: \.self) { count in
                    render(Array(elements.prefix(count)))
                }
            }
            .frame(maxHeight: CGFloat(lineLimit) * (Typography.Prose.lineHeight + Typography.Prose.lineSpacing) + Typography.Prose.textInset * 2, alignment: .top)
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

    private func spacing(between above: Markdown.Element, and below: Markdown.Element) -> CGFloat {
        if case .text(let lower, _, _, _) = below, case .heading = lower { return Typography.Prose.headingSpacing }
        guard case .text(let upper, _, _, _) = above, case .text(let lower, _, _, _) = below,
              upper.isList, lower.isList else { return Typography.Prose.blockSpacing }
        return Typography.Prose.listSpacing
    }

    @ViewBuilder private func block(_ element: Markdown.Element) -> some View {
        switch element {
            case .text(let kind, let text, let depth, let marker):
                HStack(alignment: .top, spacing: Typography.Prose.markerGap) {
                    switch kind {
                        case .bullet:
                            Circle()
                                .fill(Color(nsColor: Theme.dark.bulletColor))
                                .frame(width: Typography.Prose.bulletSize, height: Typography.Prose.bulletSize)
                                .frame(width: Typography.Prose.markerWidth, height: line + Typography.Prose.textInset * 2)
                        case .numbered:
                            Text(marker.trimmingCharacters(in: .whitespaces))
                                .font(Font(Typography.Prose.text))
                                .monospacedDigit()
                                .foregroundStyle(Color(nsColor: Theme.dark.bulletColor))
                                .fixedSize()
                                .frame(width: Typography.Prose.markerWidth, alignment: .leading)
                        case .checklist(let checked):
                            TaskCompletionIndicator(completed: checked)
                        default: EmptyView()
                    }
                    MarkdownText(content: text, font: font(kind), reasoning: reasoning, completed: kind == .checklist(checked: true), hugs: hugs)
                }
                .padding(.leading, kind.isList ? Typography.Prose.listInset + CGFloat(depth) * Typography.Prose.listIndent : .zero)

            case .quote(let text):
                HStack(spacing: Typography.Prose.markerGap) {
                    Rectangle()
                        .fill(Style.Foreground.secondary)
                        .frame(width: Typography.Prose.quoteBarWidth)
                        .frame(width: Typography.Prose.markerWidth)
                    MarkdownText(content: text, reasoning: true, hugs: hugs)
                        .padding(.vertical, 4)
                }
                .padding(.leading, Typography.Prose.listInset)
                .fixedSize(horizontal: false, vertical: true)

            case .code(let code, let language):
                VStack(alignment: .leading, spacing: 8) {
                    if !language.isEmpty {
                        Text(language)
                            .font(Typography.footnote)
                            .foregroundStyle(Style.Foreground.secondary)
                    }
                    ScrollView(.horizontal) {
                        Text(code)
                            .font(Typography.code)
                            .foregroundStyle(Style.Foreground.primary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Style.Shape.card.fill(Style.Background.surface))
                .overlay(Style.Shape.card.strokeBorder(Style.Border.hairline))

            case .table(let rows, let alignments):
                MarkdownTable(rows: rows, alignments: alignments, reasoning: reasoning)
        }
    }

    private func font(_ kind: Markdown.BlockKind) -> NSFont {
        if case .heading(let level) = kind { return Typography.Prose.heading(level) }
        return Typography.Prose.text
    }
}

struct DocumentBlock: View {
    let block: Block
    var isSelected = false
    var scale: CGFloat? = 1.0

    var body: some View {
        switch block {
            case .artifact(let ref), .command(let ref), .document(let ref):
                Card(ref: ref, style: .group, isSelected: isSelected)
                    .scaleEffect(scale ?? 1.0)

            case .data, .frame(_, _):
                EmptyView()

            case .task(_, let content, let completed, _):
                TaskBlock(content: content, completed: completed)
                    .background(Style.Shape.card.fill(isSelected ? Style.Background.selection : .clear))
                    .scaleEffect(scale ?? 1.0)

            case .text(_, let content):
                TextBlock(content: content)
                    .background(Style.Shape.card.fill(isSelected ? Style.Background.selection : .clear))
                    .scaleEffect(scale ?? 1.0)
        }
    }
}

struct DocumentBlockRow: View {
    var blocks: [Block] = []
    var isSelected = false
    var scale: CGFloat? = 1.0

    var body: some View {
        VStack {
            ForEach(blocks) { block in
                DocumentBlock(block: block)
            }
        }
    }
}
