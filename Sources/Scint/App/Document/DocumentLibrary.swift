import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct DocumentRow: Surface {
    let ref: Reference
    var panel: any Panel
    var model: any Model

    var body: some View {
        Button { model.open(ref) } label: {
            HStack(spacing: Style.Spacing.label) {
                Iconography.icon(for: ref).frame(width: 18)
                Text(Card.text(for: ref).name).lineLimit(1)
                Spacer(minLength: 0)
            }
            .font(Typography.body)
            .foregroundStyle(Style.Foreground.primary)
            .frame(minHeight: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Card.text(for: ref).name)
    }
}

struct DocumentCard: View {
    let ref: Reference
    let model: any Model

    @State var selected: Bool
    @State var isHovered: Bool

    private let width: CGFloat = 240
    private let previewScale: CGFloat = 0.66

    var blocks: [ScintRuntime.Document.Block] { Document.with(ref, { $0.blocks }) ?? [] }

    var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            VStack(alignment: .leading, spacing: Style.Spacing.inset) {
                Text(updated)
                    .font(Typography.sectionTitle)
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(1)

                ForEach(blocks.prefix(6)) {
                    DocumentBlock(block: $0)
                        .textSelection(.disabled)
                }
            }
            .frame(width: (width - Style.Spacing.tile * 1.66) / previewScale, alignment: .topLeading)
            .scaleEffect(previewScale, anchor: .topLeading)
        }
        .padding(Style.Spacing.tile)
        .frame(minWidth: width, maxWidth: width, minHeight: 250, maxHeight: 300, alignment: .topLeading)
        .clipShape(Style.Shape.card)
        .background(Style.Shape.card.fill(Style.Background.panel))
        .contentShape(Style.Shape.card)
        .background {
            selected ? Style.Shape.card.fill(Style.Background.surface)
            : Style.Shape.card.fill(Style.Background.surface)
        }
        .overlay {
            Style.Shape.card.strokeBorder(
                selected || isHovered
                ? Style.Border.card
                : Style.Border.card,
                lineWidth: selected ? 1 : 0.5
            )
        }
        .contentShape(Style.Shape.card)
        .offset(y: isHovered ? -1 : 0)
        .onHover { hovered in
            withAnimation(Style.Motion.disclosure) {
                isHovered = hovered
            }
        }
    }
}

struct DocumentLibrary: Surface {
    var panel: any Panel
    var model: any Model

    var space: Reference? { model.session.selection.structure }
    var document: Reference? { model.session.opened.document }
    var documents: [Reference] {
        guard let space, let documents = Space.with(space, { $0 })?.documents
        else { return [] }
        return documents
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Style.Spacing.section)], spacing: Style.Spacing.section) {
                if !documents.isEmpty {
                    ForEach(documents) { document in
                        DocumentCard(
                            ref: document,
                            model: model,
                            selected: model.session.selection.selected(document),
                            isHovered: false
                        )
                        .onTapGesture { model.focus(document) }
                        .onTapGesture(count: 2) { model.open(document) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
        }
        .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Style.Background.canvas)
    }
}


