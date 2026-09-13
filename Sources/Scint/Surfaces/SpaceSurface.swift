import SwiftUI
import Foundation


struct TranscriptMenu: View {
    var ref: Reference
    var model: any Model

    var materials: [Reference] { Space.with(ref, { $0.materials }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }
    var selected: Bool { model.session.selection.selected(ref) }

    @State private var selection: Reference?

    private var transcript: Reference? {
        if let selection, transcripts.contains(selection) { return selection }
        return transcripts.max { $0.descriptor.created < $1.descriptor.created }
    }

    var body: some View {
        SwiftUI.Menu {
            ForEach(transcripts) { transcript in
                Button {
                    selection = transcript
                    if model.session.origin != ref { model.select(ref) }
                    model.select(transcript)
                } label: {
                    if transcript == self.transcript {
                        Label(transcript.descriptor.name, systemImage: "checkmark")
                    } else {
                        Text(transcript.descriptor.name)
                    }
                }
            }
        } label: {
            HStack(spacing: Style.Spacing.md) {
                Iconography.Icon(symbol: "text.bubble", tint: Style.Foreground.subtle, sizing: 16)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Style.Spacing.sm) {
                        Text(transcript?.descriptor.name ?? "None")
                        if let transcript = transcript {
                            let count = Transcript.with(transcript, { $0.records.count }) ?? 0
                            Text("· \(count) \(count == 1 ? "message" : "messages")")
                                .foregroundStyle(Style.Foreground.muted)
                        }
                    }
                    .fixedSize()
                    Text(transcript?.descriptor.name ?? "None")
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .medium))
            }
            .font(Typography.row)
            .foregroundStyle(Style.Foreground.primary)
            .padding(.horizontal, Style.Spacing.md)
            .frame(maxWidth: .infinity, minHeight: 32)
            .background(Style.Shape.tiny.fill(Style.Background.field))
            .overlay(Style.Shape.tiny.strokeBorder(Style.Border.node, lineWidth: 1))
            .contentShape(Style.Shape.tiny)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .disabled(transcripts.isEmpty)
    }
}
struct SpaceDivider: View {
    var body: some View {
        Style.Border.node.frame(height: Style.Dimension.border)
    }
}

struct SpaceButtonStyle: ViewModifier {
    func body(content: Self.Content) -> some View {
        content
            .font(.system(size: 24))
            .foregroundStyle(Style.Foreground.primary)
            .frame(width: 24, height: 24, alignment: .center)
            .controlSize(.extraLarge)
            .buttonBorderShape(.circle)
            .buttonStyle(.glass)
    }
}

struct SpaceHeader: View {
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

    func icon(for ref: Reference, size: CGFloat = Style.Dimension.canvasIcon) -> Iconography.Icon {
        guard let intent = intent else { return Iconography.icon(for: ref, size: size) }
        return Iconography.icon(for: intent, size: size)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Style.Spacing.md) {
            HStack {
                icon(for: ref, size: 24)
                    .frame(width: 36, height: 36)

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

                Spacer(minLength: Style.Spacing.md)

                VStack(alignment: .trailing) {
                    SettingsPicker(panel: panel, model: model)
                        .simultaneousGesture(TapGesture().onEnded { model.focus(ref) })
                        .frame(alignment: .topTrailing)
                        .modifier(SpaceButtonStyle())
                    Spacer()
                }
                .frame(height: 36)
            }
            .frame(maxHeight: 36, alignment: .topLeading)

            Text(description.isEmpty ? "Add a description..." : description)
                .frame(alignment: .topLeading)
                .padding(.vertical, 4)
                .font(Typography.badge)
                .foregroundStyle(description.isEmpty ? Style.Foreground.faint : Style.Foreground.subtle)
                .lineLimit(Style.Limit.doubleLine)

        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SpaceSurface: Surface {
    var ref: Reference
    var panel: any Panel
    var model: any Model

    var spaces: [Reference] {
        guard let spaces = Space.with(ref, { $0 })?.spaces
        else { return [] }
        return Array(spaces)
    }

    var materials: [Reference] { Space.with(ref, { $0.materials }) ?? [] }
    var transcripts: [Reference] { Space.with(ref, { $0.transcripts }) ?? [] }
    var selected: Bool { model.session.selection.selected(ref) }
    var focused: Bool { model.session.focus == .structure(ref) }

    var intent: Color {
        guard let harness = Space.with(ref, { $0 })?.harness, let intent = Harness.with(harness, { $0 })?.intent
        else { return Iconography.accent(for: ref) }
        return Iconography.icon(for: intent).tint
    }

    var border: Color {
        guard selected else { return Style.Border.node }
        return focused ? intent : intent.opacity(Style.Opacity.faint)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: Style.Spacing.lg) {
                SpaceHeader(ref: ref, panel: panel, model: model)

                TranscriptMenu(ref: ref, model: model)

                SpaceDivider()

                VStack(alignment: .leading, spacing: Style.Spacing.sm) {
                    ForEach(materials) { material in
                        Button {
                            if model.session.origin != ref { model.select(ref) }
                            model.open(material)
                        } label: {
                            HStack(spacing: Style.Spacing.md) {
                                Iconography.icon(for: material)
                                    .frame(width: 18)
                                Text(Card.text(for: material).name)
                                    .lineLimit(1)
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
                }

                SpaceDivider()

                HStack {
                    Badges(model: model, ref: ref)

                    Spacer()

                    StateBadge(composition: model.compose(ref))
                }
                .frame(maxWidth: .infinity, maxHeight: 28, alignment: .center)
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



