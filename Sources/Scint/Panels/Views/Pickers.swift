import SwiftUI


struct TranscriptPicker: View {
    @State private var hovered = false

    var model: any Model

    var body: some View {
        if let root = model.session.transcripts.first, let selected = model.session.transcript {
            let branches: [Reference] = Transcript.with(root) { transcript in
                transcript.entries.compactMap { entry in
                    guard case .transcript(_, let ref, _) = entry else { return nil }
                    return ref
                }
            } ?? []
            let harnesses = Runtime.shared.context(for: model.session.origin)?.harnesses ?? []

            HStack(spacing: hovered ? Style.Spacing.md : 0) {
                if hovered || selected == root {
                    Button { model.select(root) } label: {
                        Text("Overview")
                            .font(Typography.row.weight(selected == root ? .medium : .regular))
                            .foregroundStyle(selected == root ? Style.Foreground.subtle : Style.Foreground.faint)
                            .lineLimit(Style.Limit.singleLine)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(Harness.Intent.allCases.enumerated()), id: \.offset) { _, intent in
                    let label = String(describing: intent).capitalized
                    let transcript = branches.first { $0.descriptor.name == label }
                    let enabled = harnesses.contains { harness in
                        Harness.with(harness) { $0.intent == intent } == true
                    }

                    if hovered || transcript == selected {
                        Button {
                            if let transcript { model.select(transcript) }
                        } label: {
                            Text(label)
                                .font(Typography.row.weight(transcript == selected ? .medium : .regular))
                                .foregroundStyle(
                                    enabled
                                    ? transcript == selected
                                    ? Style.Foreground.subtle
                                    : Style.Foreground.faint
                                    : Style.Foreground.disabled
                                )
                                .lineLimit(Style.Limit.singleLine)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                        .help(
                            !enabled
                            ? "No \(label.lowercased()) harness"
                            : transcript == nil
                            ? "No \(label.lowercased()) transcript yet"
                            : "Show \(label.lowercased()) transcript"
                        )
                    }
                }
            }
            .padding(.horizontal, Style.Spacing.md)
            .frame(height: 30)
            .fixedSize(horizontal: true, vertical: false)
            .background(
                Style.Shape.panel
                    .fill(Style.Background.group)
            )
            .overlay(
                Style.Shape.panel
                    .stroke(Style.Border.base, lineWidth: 1)
            )
            .contentShape(Style.Shape.panel)
            .onHover { isHovered in
                withAnimation(.smooth(duration: 0.18)) { hovered = isHovered }
            }
            .animation(.smooth(duration: 0.18), value: hovered)
        }
    }
}

struct ContentPicker: View {
    let panel: ContentPanel

    private func selection(for surface: ContentPanel.PanelSurface) -> Binding<Bool> {
        Binding(
            get: { panel.state.presented && panel.surface == surface },
            set: { selected in
                if selected {
                    panel.surface = surface
                    panel.state.presented = true
                } else if panel.surface == surface {
                    panel.state.presented = false
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(ContentPanel.PanelSurface.allCases) { surface in
                Toggle(isOn: selection(for: surface)) {
                    Image(systemName: surface.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.base, Style.Foreground.base, Style.Foreground.base)
        .tint(Style.Background.group)
    }
}
