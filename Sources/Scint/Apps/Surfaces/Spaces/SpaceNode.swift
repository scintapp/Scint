import ScintComponents
import SwiftUI
import Foundation


struct NodeDivider: View {
    var body: some View {
        Style.Border.hairline.frame(height: 1)
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
        VStack(alignment: .leading, spacing: Style.Spacing.label) {
            HStack(spacing: 16) {
                if let intent { Iconography.icon(for: intent, size: 24) }

                VStack(alignment: .leading) {
                    Text(name)
                        .frame(alignment: .topLeading)
                        .font(Typography.lead.weight(.semibold))
                        .foregroundStyle(Style.Foreground.primary)
                        .lineLimit(1)

                    Text(intent?.rawValue.capitalized ?? "No Harness")
                        .frame(alignment: .topLeading)
                        .font(Typography.detail)
                        .foregroundStyle(Style.Foreground.secondary)
                        .lineLimit(1)
                }
                .frame(height: 36)
            }
            .frame(maxHeight: 36, alignment: .topLeading)

            Text(description.isEmpty ? "Add a description..." : description)
                .frame(alignment: .topLeading)
                .padding(.vertical, 4)
                .font(Typography.detail)
                .foregroundStyle(description.isEmpty ? Style.Foreground.secondary : Style.Foreground.secondary)
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
            VStack(alignment: .leading, spacing: Style.Spacing.detail) {
                NodeDivider()

                ForEach(materials) { material in
                    MaterialRow(ref: material, panel: panel, model: model)
                        .font(Typography.body)
                        .foregroundStyle(Style.Foreground.primary)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                }

                NodeDivider()
            }
        }
    }
}

struct CanvasNode: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var selected: Bool { model.session.selection.selected(ref) }
    var focused: Bool { model.session.focus == .structure(ref) }
    var materials: [Reference] { Space.with(ref, { $0.materials }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }

    var border: Color {
        guard selected else { return Style.Border.hairline }
        return focused ? intent : intent.opacity(Style.Opacity.outline)
    }

    var intent: Color {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
                else { return Iconography.accent(for: ref) }
        return Iconography.icon(for: intent).tint.bright
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Style.Spacing.heading) {
                NodeHeader(ref: ref, panel: panel, model: model)
                NodeSection(ref: ref, panel: panel, model: model)
                TranscriptMenu(ref: ref, model: model)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(12)
            .background { Style.Shape.panel.fill(Style.Background.surface) }
            .overlay { Style.Shape.panel.stroke(border, lineWidth: 1, antialiased: true) }
            .clipShape(Style.Shape.panel)
            .contentShape(Style.Shape.panel)
            .onTapGesture { model.select(ref) }
        }
    }
}



