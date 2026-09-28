import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryCard: View {
    let ref: Reference
    let model: any Model
    let sizing: CGFloat = 230
    let scale = 0.33

    @State var hovered: Bool

    var selected: Bool { model.session.selection.selected(ref) }
    var title: String { Card.text(for: ref).name }

    var blocks: [ScintRuntime.Document.Block] {
        let blocks = Document.with(ref, { $0.blocks }) ?? []
        guard case .text(_, let first)? = blocks.first, first.hasPrefix("# ") else { return blocks }
        return Array(blocks.dropFirst())
    }

    var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(2)

                Text(updated)
                    .font(.system(size: 11))
                    .foregroundStyle(Style.Foreground.muted)
                    .lineLimit(1)
            }

            Rectangle()
                .fill(Style.Border.hairline)
                .frame(height: 0.5)

            GeometryReader { proxy in
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(blocks.prefix(9)) {
                        DocumentBlock(block: $0)
                            .allowsHitTesting(false)
                            .textSelection(.disabled)
                            .opacity(0.8)
                    }
                }
                .frame(width: proxy.size.width / scale, alignment: .topLeading)
                .textSelection(.disabled)
                .scaleEffect(scale, anchor: .topLeading)
            }
        }
        .padding(Style.Spacing.tile)
        .frame(minWidth: sizing, maxWidth: .infinity, minHeight: sizing * 1.2, maxHeight: sizing * 1.2, alignment: .top)
        .clipShape(Style.Shape.card)
        .background(Style.Shape.card.fill(Style.Background.surface.opacity(0.7)))
        .overlay(Style.Shape.card.strokeBorder(selected ? Style.Tint.document.dull : Style.Border.hairline))
        .contentShape(Style.Shape.card)
        .shadow(color: .black.opacity(0.3), radius: hovered ? 5 : 3, y: hovered ? 4 : 2)
        .offset(y: hovered || selected ? -3 : 0)
        .onHover { hover in withAnimation(Style.Motion.disclosure) { hovered = hover } }
        .onDrag { ReferenceTransfer.provider(for: ref) ?? NSItemProvider() }
    }
}
