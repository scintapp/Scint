import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryContent: Surface {
    var host: any Host
    var model: any Model

    var documents: [Reference] {
        if model.session.selection.structure == model.session.library { return model.session.documents }
        else { return model.session.folder }
    }

    var body: some View {
        if let doc = model.session.opened.document, (Document.with(doc, { $0 })?.task == nil) {
            DocumentContent(host: host, model: model)
        } else {
            ScrollView {
                LibraryColumns(minimum: 230, maximum: 230, spacing: 20) {
                    ForEach(Array(documents.enumerated()), id: \.element) { index, ref in
                        LibraryCard(
                            ref: ref,
                            model: model,
                            weight: index.isMultiple(of: 2) ? 0.25 : 0.33 + 0.33 * CGFloat(ref.id.uuid.0) / 255,
                            hovered: false
                        )
                        .onTapGesture { model.select(ref) }
                        .onTapGesture(count: 2) { model.open(ref) }
                        .contextMenu { ContextMenu(ref: ref, model: model) }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .scrollIndicators(.hidden)
                .contentShape(Rectangle())
                .padding(.horizontal, Style.Spacing.entry)
                .padding(.top, Style.Spacing.entry)
            }
            .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .background(Style.Background.canvas)
            .scrollEdgeEffectStyle(.hard, for: .vertical)
            .safeAreaBar(edge: .top) { LibraryHeader(model: model) }
        }
    }
}

struct LibraryColumns: SwiftUI.Layout {
    let minimum: CGFloat
    let maximum: CGFloat
    let spacing: CGFloat

    private func arrange(_ width: CGFloat, _ subviews: Subviews) -> (column: CGFloat, origins: [CGPoint], height: CGFloat) {
        let count = max(Int((width + spacing) / (minimum + spacing)), 1)
        let column = min(maximum, (width - spacing * CGFloat(count - 1)) / CGFloat(count))
        var bottoms = Array(repeating: CGFloat.zero, count: count)
        let origins = subviews.map { subview in
            let shortest = bottoms.indices.min { bottoms[$0] < bottoms[$1] } ?? 0
            let origin = CGPoint(x: CGFloat(shortest) * (column + spacing), y: bottoms[shortest])
            bottoms[shortest] += subview.sizeThatFits(.init(width: column, height: nil)).height + spacing
            return origin
        }
        return (column, origins, max((bottoms.max() ?? 0) - spacing, 0))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? maximum
        return CGSize(width: width, height: arrange(width, subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let arranged = arrange(bounds.width, subviews)
        for (subview, origin) in zip(subviews, arranged.origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .init(width: arranged.column, height: nil))
        }
    }
}
