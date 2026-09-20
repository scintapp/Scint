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

    let selected: Bool

    var blocks: [Document.Block] { Document.with(ref, { $0.blocks }) ?? [] }

    var body: some View {
        VStack(spacing: Style.Spacing.detail) {
            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                ForEach(blocks.prefix(6)) {
                    DocumentBlock(block: $0)
                        .textSelection(.disabled)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                }
            }
            .padding(Style.Spacing.inset)
            .frame(maxWidth: .infinity, minHeight: 240, maxHeight: 260, alignment: .top)
            .clipShape(Style.Shape.card)
            .background(Style.Shape.card.fill(Style.Background.surface))
            .overlay(Style.Shape.card.stroke(selected ? Style.Tint.accent.bright : Style.Border.hairline, lineWidth: selected ? 2 : 1))
            .contentShape(Rectangle())
        }
    }
}

struct DocumentContent: Surface {
    var panel: any Panel
    var model: any Model

    var ref: Reference? { model.session.opened.document }
    var library: Reference { model.session.library }

    var body: some View {
        ScrollView {
            if let ref {
                ScintEdit(ref: ref, onFocus: { model.open(ref) })
                .id(ref)
                .frame(maxWidth: Style.Prose.readableWidth, maxHeight: .infinity, alignment: .center)
                .padding(.horizontal, Style.Spacing.page)
                .padding(.top, Style.Spacing.page)
                .padding(.bottom, Style.Spacing.page)
                .background {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
                }
            }
        }
        .scrollTargetBehavior(.paging)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .background(Style.Background.canvas)
    }
}
