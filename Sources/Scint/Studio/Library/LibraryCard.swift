import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct LibraryCard: View {
    let ref: Reference
    let sizing: CGFloat = 224
    let scale = 0.6

    @State var selected: Bool
    @State var isHovered: Bool

    var blocks: [ScintRuntime.Document.Block] { Document.with(ref, { $0.blocks }) ?? [] }

    var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(updated)
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(1)

                ForEach(blocks.prefix(6)) {
                    DocumentBlock(block: $0)
                        .allowsHitTesting(false)
                        .textSelection(.disabled)
                        .padding(.horizontal, 14)
                        .padding(.top, 10)
                }
            }
            .frame(width: (sizing - 16 * 2) / scale, alignment: .topLeading)
            .textSelection(.disabled)
            .scaleEffect(scale, anchor: .top)
        }
        .padding(Style.Spacing.tile)
        .frame(minWidth: sizing, maxWidth: sizing, maxHeight: sizing * 1.2, alignment: .top)
        .clipShape(Style.Shape.card)
        .background(Style.Shape.card.fill(Style.Background.surface.opacity(0.7)))
        .overlay(Style.Shape.card.strokeBorder(selected ? Style.Tint.document.dull : Style.Border.card, lineWidth: 0.5))
        .contentShape(Style.Shape.card)
        .shadow(color: .black.opacity(0.2), radius: isHovered ? 3 : 1.5, y: isHovered ? 2 : 1)
        .offset(y: isHovered ? -2 : 0)
        .onHover { hovered in
            withAnimation(Style.Motion.disclosure) {
                isHovered = hovered
            }
        }
        .onDrag { ReferenceTransfer.provider(for: ref) ?? NSItemProvider() }
    }
}
