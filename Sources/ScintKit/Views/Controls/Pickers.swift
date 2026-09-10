import SwiftUI


struct ItemPicker: View {
    let value: String
    let items: [ItemParams]
    let onChange: (ItemParams) -> Void

    var body: some View {
        let selected = items.first { ($0.value ?? "") == value }!

        SwiftUI.Menu {
            ForEach(items) { item in
                Button { onChange(item) } label: {
                    Text(item.name)
                    if item == selected { Image(systemName: "checkmark") }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selected.name)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(.quaternary, in: Circle())
            }
            .font(.system(size: 12))
            .frame(width: 132, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
    }
}

struct ItemDatePicker: View {
    let value: String
    let onChange: (String) -> Void

    private var selection: Binding<Date> {
        Binding(
            get: { Value.formatter.date(from: value) ?? .now },
            set: { onChange(Value.formatter.string(from: $0)) }
        )
    }

    var body: some View {
        DatePicker("", selection: selection, displayedComponents: [.date, .hourAndMinute])
            .datePickerStyle(.compact)
            .labelsHidden()
    }
}

struct AssistantSurfacePicker: View {
    let panel: AssistantPanel

    private func selection(for surface: AssistantPanel.PanelSurface) -> Binding<Bool> {
        Binding(
            get: { panel.surface == surface },
            set: { selected in
                if selected {
                    panel.surface = surface
                } else if panel.surface == surface {
                    panel.surface = .space
                }
            }
        )
    }

    var body: some View {
        ControlGroup {
            ForEach(AssistantPanel.PanelSurface.viewModes) { surface in
                Toggle(isOn: selection(for: surface)) {
                    Image(systemName: surface.symbol)
                }
                .toggleStyle(.button)
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.base, Style.Foreground.base, Style.Foreground.base)
        .tint(Style.Background.control)
    }
}

struct ContentSurfacePicker: View {
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

struct SettingsPicker: View {
    var panel: any Panel
    var model: any Model

    var surface: AnySurface { .init(panel: panel, model: model) }
    var controls: Controls { SpaceSettings.controls(model) }
    var parameters: Params { SpaceSettings.parameters(model) }

    @State private var presented = false

    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "gearshape")
        }
        .popover(isPresented: $presented) {
            surface.render(surface, parameters, controls)
                .frame(maxWidth: 340, maxHeight: .infinity)
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

struct TranscriptPicker: View {
    var model: any Model

    @State private var hovered = false

    var body: some View {
        if let context = model.session.transcripts.first,
           let selected = model.session.transcript,
           let composition = Runtime.shared.resolve(model.session.origin) {
            let branches: [(ref: Reference, intent: Intent)] = Transcript.with(context, { record in
                record.entries.compactMap { entry in
                    guard case .transcript(let ref, let intent, _) = entry else { return nil }
                    return (ref, intent)
                }
            }) ?? []

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

                ForEach(Array(Intent.allCases).enumerated(), id: \.offset) { _, intent in
                    let label = intent.rawValue.capitalized
                    let transcript = branches.first { $0.intent == intent }?.ref

                    let enabled = composition.harnesses.contains { harness in
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
