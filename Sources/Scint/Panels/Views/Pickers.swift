import SwiftUI


struct TranscriptPicker: View {
    @State private var hovered = false

    var model: any Model

    var body: some View {
        if let root = model.session.transcripts.first, let selected = model.session.transcript {
            let transcripts = [root] + (Transcript.with(root) { transcript in
                transcript.entries.compactMap { entry in
                    guard case .transcript(let ref, _) = entry else { return nil }
                    return ref
                }
            } ?? [])

            HStack(spacing: hovered ? Style.Spacing.md : 0) {
                ForEach(hovered ? transcripts : [selected]) { transcript in
                    Button { model.select(transcript) } label: {
                        Text(
                            transcript == root
                            ? "Overview"
                            : transcript.descriptor.name.replacingOccurrences(of: " Transcript", with: "")
                        )
                        .font(Typography.row.weight(transcript == selected ? .medium : .regular))
                        .foregroundStyle(
                            transcript == selected
                            ? Style.Foreground.subtle
                            : Style.Foreground.faint
                        )
                        .lineLimit(1)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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
