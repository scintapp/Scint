import SwiftUI


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

struct DetailPicker: View {
    let panel: ContentPanel

    private func selection(for detail: ContentPanel.PanelDetail) -> Binding<Bool> {
        Binding(
            get: { panel.state.presented && panel.detail == detail },
            set: { selected in
                if selected {
                    panel.detail = detail
                    panel.state.presented = true
                } else if panel.detail == detail {
                    panel.state.presented = false
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(ContentPanel.PanelDetail.allCases) { detail in
                Toggle(isOn: selection(for: detail)) {
                    Image(systemName: detail.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.base, Style.Foreground.base, Style.Foreground.base)
        .tint(Style.Background.group)
    }
}

struct HarnessPicker: View {
    var panel: any Panel
    var model: any Model

    var body: some View {
        Button { panel.state.presented.toggle() } label: {
            Image(systemName: "gearshape")
        }
        .popover(isPresented: panel.state.bindable.presented) {
            let surface = AnySurface(panel: panel, model: model)
            surface.render(surface, HarnessGroup.parameters(model), HarnessGroup.controls(model))
        }
    }
}

struct TranscriptPicker: View {
    @State private var hovered = false

    var model: any Model

    var body: some View {
        if let context = model.session.transcripts.first, let selected = model.session.transcript {
            let branches: [Reference] = Transcript.with(context, { $0.branches }) ?? []
            let harnesses = Runtime.shared.context(for: model.session.origin)?.harnesses ?? []

            HStack(spacing: hovered ? Style.Spacing.md : 0) {
                if hovered || selected == context {
                    Button { model.select(context) } label: {
                        Text("Overview")
                            .font(Typography.row.weight(selected == context ? .medium : .regular))
                            .foregroundStyle(selected == context ? Style.Foreground.subtle : Style.Foreground.faint)
                            .lineLimit(Style.Limit.singleLine)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                ForEach(Array(Harness.Intent.allCases).enumerated(), id: \.offset) { _, intent in
                    let label = String(describing: intent).capitalized
                    let transcript = branches.first { $0.descriptor.name == label }
                    let enabled = harnesses.contains { harness in
                        Harness.with(harness) { $0.intent == intent } == true
                    }

                    if hovered || transcript == selected {
                        Button { if let transcript { model.select(transcript) } } label: {
                            Text(label)
                                .padding(.horizontal, 2)
                                .font(Typography.row.weight(transcript == selected ? .medium : .regular))
                                .foregroundStyle(
                                    enabled
                                    ? transcript == selected
                                    ? Style.Foreground.subtle
                                    : Style.Foreground.faint
                                    : Style.Foreground.faint
                                )
                                .lineLimit(Style.Limit.singleLine)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                    }
                }
            }
            .padding(.horizontal, Style.Spacing.md)
            .frame(height: 30)
            .fixedSize(horizontal: true, vertical: false)
            .background(Style.Shape.panel.fill(Style.Background.group))
            .overlay(Style.Shape.panel.stroke(Style.Border.base, lineWidth: 1))
            .contentShape(Style.Shape.panel)
            .onHover { isHovered in withAnimation(.smooth(duration: 0.2)) { hovered = isHovered } }
            .animation(.smooth(duration: 0.2), value: hovered)
        }
    }
}
