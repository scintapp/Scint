import ScintComponents
import SwiftUI


struct MaterialRow: Surface {
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

struct MaterialCard: View {
    let ref: Reference
    let selected: Bool

    var blocks: [Material.Block] { Material.with(ref, { $0.blocks }) ?? [] }

    var body: some View {
        VStack(spacing: Style.Spacing.detail) {
            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                ForEach(blocks.prefix(6)) { MaterialBlock(block: $0) }
            }
            .padding(Style.Spacing.inset)
            .frame(maxWidth: .infinity, minHeight: 220, maxHeight: 220, alignment: .topLeading)
            .clipShape(Style.Shape.card)
            .background(Style.Shape.card.fill(Style.Background.surface))
            .overlay(Style.Shape.card.stroke(selected ? Style.Tint.accent.bright : Style.Border.hairline, lineWidth: selected ? 2 : 1))

            Text(ref.descriptor.name)
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)

            Text(ref.descriptor.updated.formatted(date: .numeric, time: .omitted))
                .font(.system(size: 11))
                .foregroundStyle(Style.Foreground.primary)
        }
    }
}

struct MaterialContent: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var library: Reference { model.session.library }

    var body: some View {
        ScrollView {
            EditorView(
                ref,
                sizing: .fitsContent,
                autofocus: true,
                onFocus: { model.open(ref) },
            )
            .id(ref)
            .frame(maxWidth: Style.Prose.readableWidth, alignment: .center)
            .padding(.horizontal, Style.Spacing.page)
            .padding(.top, Style.Spacing.page)
            .padding(.bottom, Style.Spacing.page)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { NSApp.keyWindow?.makeFirstResponder(nil) }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollIndicators(.hidden)
        .background(Style.Background.canvas)
    }
}
