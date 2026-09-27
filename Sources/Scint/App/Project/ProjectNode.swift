import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct NodeDivider: View {
    var body: some View {
        Style.Border.hairline.frame(height: 1)
    }
}


struct NodeRow: View {
    let ref: Reference
    var model: any Model

    var body: some View {
        Button { model.open(ref) } label: {
            HStack(spacing: 8) {
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
        .help(Card.text(for: ref).name)
    }
}


struct NodeHeader: View {
    let ref: Reference
    var model: any Model

    var name: String { ref.descriptor.name }
    var description: String { ref.descriptor.description }

    var intent: Intent? {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
        else { return nil }
        return intent
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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
    var model: any Model

    var documents: [Reference] { Space.with(ref, { $0.documents }) ?? [] }

    var body: some View {
        if !documents.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                NodeDivider()

                ForEach(documents) { ref in
                    NodeRow(ref: ref, model: model)
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

struct CanvasNode: View {
    var ref: Reference
    var model: any Model

    var selected: Bool { model.session.selection.selected(ref) }
    var focused: Bool { model.session.focus == .structure(ref) }
    var documents: [Reference] { Space.with(ref, { $0.documents }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }

    var border: Color {
        guard selected else { return Style.Border.hairline }
        return focused ? intent : intent.opacity(Style.Opacity.outline)
    }

    var intent: Color {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
        else { return Iconography.accent(for: ref) }
        return Iconography.icon(for: intent).tint
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Style.Spacing.heading) {
                NodeHeader(ref: ref, model: model)
                NodeSection(ref: ref, model: model)
                TranscriptMenu(ref: ref, model: model)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(12)
            .background { Style.Shape.surface.fill(Style.Background.surface) }
            .clipShape(Style.Shape.surface)
            .overlay { Style.Shape.surface.strokeBorder(border, lineWidth: 1) }
            .contentShape(Style.Shape.surface)
            .onTapGesture { model.select(ref) }
        }
    }
}



