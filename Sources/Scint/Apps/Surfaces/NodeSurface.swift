import SwiftUI
import Foundation


struct NodeDivider: View {
    var body: some View {
        Style.Border.node.frame(height: Style.Dimension.border)
    }
}

struct NodeHeader: View {
    let ref: Reference
    var panel: any Panel
    var model: any Model

    var name: String { ref.descriptor.name }
    var description: String { ref.descriptor.description }

    var intent: Intent? {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
        else { return nil }
        return intent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            HStack(spacing: 16) {
                if let intent { Iconography.icon(for: intent, size: 24) }

                VStack(alignment: .leading) {
                    Text(name)
                        .frame(alignment: .topLeading)
                        .font(Typography.cardHeading.weight(.semibold))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(Style.Limit.singleLine)

                    Text(intent?.rawValue.capitalized ?? "No Harness")
                        .frame(alignment: .topLeading)
                        .font(Typography.badge)
                        .foregroundStyle(Style.Foreground.muted)
                        .lineLimit(Style.Limit.singleLine)
                }
                .frame(height: 36)
            }
            .frame(maxHeight: 36, alignment: .topLeading)

            Text(description.isEmpty ? "Add a description..." : description)
                .frame(alignment: .topLeading)
                .padding(.vertical, 4)
                .font(Typography.badge)
                .foregroundStyle(description.isEmpty ? Style.Foreground.faint : Style.Foreground.subtle)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct NodeSection: View {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var materials: [Reference] { Space.with(ref, { $0.materials }) ?? [] }

    var body: some View {
        if !materials.isEmpty {
            VStack(alignment: .leading, spacing: Style.Spacing.sm) {
                NodeDivider()

                ForEach(materials) { material in
                    Button { if model.session.space != ref { model.open(material) } } label: {
                        HStack(spacing: Style.Spacing.md) {
                            Iconography.icon(for: material).frame(width: 18)
                            Text(Card.text(for: material).name).lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .font(Typography.row)
                        .foregroundStyle(Style.Foreground.primary)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help(Card.text(for: material).name)
                }

                NodeDivider()
            }
        }
    }
}

struct NodeSurface: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var selected: Bool { model.session.selection.selected(ref) }
    var focused: Bool { model.session.focus == .structure(ref) }
    var materials: [Reference] { Space.with(ref, { $0.materials }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }

    var border: Color {
        guard selected else { return Style.Border.node }
        return focused ? intent : intent.opacity(Style.Opacity.faint)
    }

    var intent: Color {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
        else { return Iconography.accent(for: ref) }
        return Iconography.icon(for: intent).tint
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Style.Spacing.lg) {
                NodeHeader(ref: ref, panel: panel, model: model)
                NodeSection(ref: ref, panel: panel, model: model)
                TranscriptMenu(ref: ref, model: model)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(12)
            .background { Style.Shape.large.fill(Style.Background.node) }
            .overlay { Style.Shape.large.stroke(border, lineWidth: 1, antialiased: true) }
            .clipShape(Style.Shape.large)
            .contentShape(Style.Shape.large)
            .onTapGesture { model.select(ref) }
        }
    }
}



