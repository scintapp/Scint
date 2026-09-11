import AppKit
import SwiftUI


/// Shared by text blocks and the editor's source-preserving table attachment.
struct MarkdownTable: View {
    let rows: [[String]]
    let alignments: [Markdown.ColumnAlignment]
    var reasoning = false

    var body: some View {
        // Fills the width it's given, or scrolls once that's narrower than every column's minimum. Both are
        // measured at the width they're drawn at. The container-relative frame this replaces measured at the
        // minimum whatever the width, so a table with wrapping cells reported more height than it drew.
        ViewThatFits(in: .horizontal) {
            grid

            ScrollView(.horizontal) {
                grid.frame(width: CGFloat(alignments.count) * Style.Dimension.markdownColumnWidth)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Style.Background.base)
        .clipShape(Style.Shape.small)
        .overlay(Style.Shape.small.strokeBorder(Style.Border.raised, lineWidth: Style.Dimension.hairline))
    }

    private var grid: some View {
        MarkdownTableLayout(columns: alignments.count) {
            ForEach(Array(rows.enumerated()), id: \.offset) { row, cells in
                ForEach(Array(cells.enumerated()), id: \.offset) { column, cell in
                    MarkdownText(
                        content: cell,
                        font: row == 0 ? Typography.Prose.appKitTableHeader : Typography.Prose.appKitText,
                        reasoning: reasoning,
                        alignment: alignment(alignments[column])
                    )
                    .padding(.horizontal, Style.Spacing.markdownTableHorizontal)
                    .padding(.vertical, Style.Spacing.markdownTableVertical)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(row == 0 ? Style.Background.overlay : Style.Background.card)
                    .overlay(Rectangle().strokeBorder(Style.Border.raised, lineWidth: Style.Dimension.hairline))
                }
            }
        }
        .padding(.bottom, Style.Dimension.border)
    }

    private func alignment(_ alignment: Markdown.ColumnAlignment) -> NSTextAlignment {
        switch alignment {
            case .leading: .left
            case .center: .center
            case .trailing: .right
        }
    }
}

/// Measure each row at its final column width, then allocate the tallest cell's
/// height to that row only. Flexible cells must not stretch unrelated rows.
struct MarkdownTableLayout: SwiftUI.Layout {
    let columns: Int

    private func dimensions(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (width: CGFloat, heights: [CGFloat]) {
        let count = max(1, columns)
        let width = proposal.width ?? CGFloat(count) * Style.Dimension.markdownColumnWidth
        var heights: [CGFloat] = []
        for index in stride(from: 0, to: subviews.count, by: count) {
            let height = subviews[index..<min(index + count, subviews.count)].map {
                $0.sizeThatFits(ProposedViewSize(width: width / CGFloat(count), height: nil)).height
            }.max() ?? .zero
            heights.append(ceil(height))
        }
        return (width, heights)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = dimensions(proposal, subviews)
        return CGSize(width: size.width, height: size.heights.reduce(.zero, +))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let size = dimensions(ProposedViewSize(width: bounds.width, height: nil), subviews)
        let count = max(1, columns)
        let width = bounds.width / CGFloat(count)
        var y = bounds.minY
        for (row, height) in size.heights.enumerated() {
            for column in 0..<count {
                let index = row * count + column
                guard index < subviews.count else { break }
                subviews[index].place(at: CGPoint(x: bounds.minX + CGFloat(column) * width, y: y), anchor: .topLeading, proposal: ProposedViewSize(width: width, height: height))
            }
            y += height
        }
    }
}
