import AppKit
import SwiftUI
import ScintComponents


public struct MarkdownTable: View {
    let rows: [[String]]
    let alignments: [Markdown.ColumnAlignment]
    var reasoning = false

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            grid

            ScrollView(.horizontal) {
                grid.frame(width: CGFloat(alignments.count) * Style.Prose.tableColumnWidth)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .background(Style.Background.canvas)
        .clipShape(Style.Shape.card)
        .overlay(Style.Shape.card.strokeBorder(Style.Border.hairline))
    }

    private var grid: some View {
        MarkdownTableLayout(columns: alignments.count) {
            ForEach(Array(rows.enumerated()), id: \.offset) { row, cells in
                ForEach(Array(cells.enumerated()), id: \.offset) { column, cell in
                    MarkdownText(
                        content: cell,
                        font: row == 0 ? Typography.Prose.tableHeader : Typography.Prose.text,
                        reasoning: reasoning,
                        alignment: alignment(alignments[column])
                    )
                    .padding(.horizontal, Style.Prose.tableCellPadding.leading)
                    .padding(.vertical, Style.Prose.tableCellPadding.top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(row == 0 ? Style.Background.surface : Style.Background.surface)
                    .overlay(Rectangle().strokeBorder(Style.Border.hairline))
                }
            }
        }
        .padding(.bottom, 1)
    }

    private func alignment(_ alignment: Markdown.ColumnAlignment) -> NSTextAlignment {
        switch alignment {
            case .leading: .left
            case .center: .center
            case .trailing: .right
        }
    }
}

public struct MarkdownTableLayout: SwiftUI.Layout {
    let columns: Int

    private func dimensions(_ proposal: ProposedViewSize, _ subviews: Subviews) -> (width: CGFloat, heights: [CGFloat]) {
        let count = max(1, columns)
        let width = proposal.width ?? CGFloat(count) * Style.Prose.tableColumnWidth
        var heights: [CGFloat] = []
        for index in stride(from: 0, to: subviews.count, by: count) {
            let height = subviews[index..<min(index + count, subviews.count)].map {
                $0.sizeThatFits(ProposedViewSize(width: width / CGFloat(count), height: nil)).height
            }.max() ?? .zero
            heights.append(ceil(height))
        }
        return (width, heights)
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = dimensions(proposal, subviews)
        return CGSize(width: size.width, height: size.heights.reduce(.zero, +))
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
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
