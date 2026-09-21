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
        .onDrag { ReferenceTransfer.provider(for: ref) ?? NSItemProvider() }
        .contextMenu { ContextActionMenu(ref: ref, model: model) }
        .help(Card.text(for: ref).name)
    }
}

struct DocumentCard: View {
    let ref: Reference
    let model: any Model
    let sizing: CGFloat = 240.0
    let scale = 0.6

    @State var selected: Bool
    @State var isHovered: Bool

    var blocks: [ScintRuntime.Document.Block] { Document.with(ref, { $0.blocks }) ?? [] }

    var updated: String {
        let relative = ref.descriptor.updated.formatted(.relative(presentation: .named))
        return relative == "now" ? "Updated Just Now" : "Updated \(relative)"
    }

    var body: some View {

        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            VStack(alignment: .leading, spacing: Style.Spacing.inset) {
                Text(updated)
                    .font(Typography.detail)
                    .foregroundStyle(Style.Foreground.secondary)
                    .lineLimit(1)

                ForEach(blocks.prefix(6)) {
                    DocumentBlock(block: $0)
                        .textSelection(.disabled)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            }
            .allowsHitTesting(false)
            .frame(width: (sizing - Style.Spacing.tile * 2) / scale, alignment: .topLeading)
            .scaleEffect(scale, anchor: .top)
        }
        .padding(Style.Spacing.tile)
        .frame(minWidth: sizing, maxWidth: sizing, maxHeight: sizing * 1.2, alignment: .top)
        .clipShape(Style.Shape.card)
        .background(Style.Shape.card.fill(Style.Background.surface))
        .overlay(Style.Shape.card.strokeBorder(Style.Border.card, lineWidth: 0.5))
        .contentShape(Style.Shape.card)
        .shadow(color: .black.opacity(0.2), radius: isHovered ? 3 : 1.5, y: isHovered ? 2 : 1)
        .offset(y: isHovered ? -2 : 0)
        .onHover { hovered in
            withAnimation(Style.Motion.disclosure) {
                isHovered = hovered
            }
        }
        .onDrag { ReferenceTransfer.provider(for: ref) ?? NSItemProvider() }
        .contextMenu { ContextActionMenu(ref: ref, model: model) }
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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: Style.Spacing.entry)], spacing: Style.Spacing.entry) {
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
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .scrollIndicators(.hidden)
            .contentShape(Rectangle())
            .padding(.horizontal, Style.Spacing.entry)
            .padding(.top, Style.Spacing.section)
        }
        .onTapGesture { if let ref = model.session.selection.content { model.session.close(ref) } }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .background(Style.Background.canvas)
    }
}
