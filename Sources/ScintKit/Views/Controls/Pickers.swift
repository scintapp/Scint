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

struct ItemRangePicker: View {
    let value: String
    let items: [ItemParams]
    let onChange: (ItemParams) -> Void

    private static let track: CGFloat = 84
    private static let height: CGFloat = 16
    private static let notch: CGFloat = 3

    private var index: Int {
        let found = items.firstIndex { ($0.value ?? "") == value } ?? 0
        return min(max(found, 0), max(items.count - 1, 0))
    }

    var body: some View {
        HStack(spacing: Style.Spacing.md) {
            Text(items.indices.contains(index) ? items[index].name : "")
                .font(.system(size: 12))
                .foregroundStyle(Style.Foreground.subtle)
                .lineLimit(Style.Limit.singleLine)

            Spacer(minLength: 0)

            let step = step(for: Self.track)

            ZStack(alignment: .leading) {
                Style.Shape.capsule.fill(Style.Background.control)

                ForEach(Array(items.indices), id: \.self) { notch in
                    Circle()
                        .fill(Style.Foreground.faint)
                        .frame(width: Self.notch, height: Self.notch)
                        .offset(x: Self.height / 2 + step * CGFloat(notch) - Self.notch / 2)
                }

                Circle()
                    .fill(Style.Foreground.primary)
                    .frame(width: Self.height, height: Self.height)
                    .offset(x: step * CGFloat(index))
            }
            .frame(width: Self.track, height: Self.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in select(at: drag.location.x) }
            )
            .animation(.smooth(duration: 0.15), value: index)
        }
        .frame(width: 132, alignment: .trailing)
    }

    private func step(for width: CGFloat) -> CGFloat {
        guard items.count > 1 else { return 0 }
        return (width - Self.height) / CGFloat(items.count - 1)
    }

    private func select(at x: CGFloat) {
        let step = step(for: Self.track)
        guard step > 0 else { return }
        let position = (x - Self.height / 2) / step
        let target = min(max(Int(position.rounded()), 0), items.count - 1)
        guard target != index else { return }
        onChange(items[target])
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
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.primary)
        .tint(Style.Background.control)
    }
}

struct ContentSurfacePicker: View {
    let panel: StudioPanel

    private func selection(for surface: StudioPanel.PanelSurface) -> Binding<Bool> {
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
            ForEach(StudioPanel.PanelSurface.allCases) { surface in
                Toggle(isOn: selection(for: surface)) {
                    Image(systemName: surface.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.primary)
        .tint(Style.Background.group)
    }
}

struct DetailPicker: View {
    let panel: StudioPanel

    private func selection(for detail: StudioPanel.PanelDetail) -> Binding<Bool> {
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
            ForEach(StudioPanel.PanelDetail.allCases) { detail in
                Toggle(isOn: selection(for: detail)) {
                    Image(systemName: detail.symbol)
                }
            }
        }
        .controlGroupStyle(.navigation)
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.primary)
        .tint(Style.Background.group)
    }
}

struct SettingsPicker: View {
    var panel: any Panel
    var model: any Model

    var surface: AnySurface { .init(panel: panel, model: model) }

    @State private var presented = false

    var body: some View {
        Button { presented.toggle() } label: {
            Image(systemName: "gearshape")
        }
        .popover(isPresented: $presented) {
            surface.render(surface, SpaceSettings.parameters(model), SpaceSettings.controls(model))
                .frame(maxWidth: 340, maxHeight: .infinity)
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }
}

struct PathPicker: View {
    var panel: any Panel
    var model: any Model

    var path: [Reference] { model.session.navigation.path(for: selection, in: model.session.workspace) }
    var selection: Selection { model.session.selection }
    var surface: AnySurface { .init(panel: panel, model: model) }

    @State private var presented = false
    @State private var hovered = false
    @State private var text = ""

    private var query: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var matches: [Reference] {
        guard !query.isEmpty else { return [] }

        return Runtime.shared.all(as: Space.self)
            .map { $0.0 }
            .filter { $0.descriptor.name.localizedCaseInsensitiveContains(query) }
            .sorted { $0.descriptor.name.localizedCaseInsensitiveCompare($1.descriptor.name) == .orderedAscending }
    }

    private func parent(of ref: Reference) -> String? {
        (Space.with(ref, { $0.space }) ?? nil)?.descriptor.name
    }

    var body: some View {
        if let ref = path.last {
            Button { presented.toggle() } label: {
                HStack(alignment: .center) {
                    Iconography.icon(for: ref, size: 13.5)
                    Text(ref.descriptor.name).font(.system(size: 13.5, weight: .medium))

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(Style.Foreground.faint)
                        .frame(width: 9)
                        .opacity(hovered || presented ? Style.Opacity.full : .zero)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .onHover { isHovered in
                withAnimation(.smooth(duration: Style.Duration.interaction)) { hovered = isHovered }
            }
            .popover(isPresented: $presented) {
                VStack(spacing: 8) {
                    Filter(text: $text)

                    if query.isEmpty {
                        surface.render(surface, AssistantNavigator.parameters(model), AssistantNavigator.controls(model))
                    } else if matches.isEmpty {
                        EmptyState(title: "No Matches")
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(matches, id: \.self) { match in
                                    ListLink(
                                        name: match.descriptor.name,
                                        detail: parent(of: match),
                                        ref: match,
                                        image: "",
                                        selected: selection.selected(match)
                                    ) {
                                        model.select(match)
                                        model.focus(match)
                                    }
                                }
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .frame(width: 260, height: 280)
                .padding(.top, 8)
            }
            .onChange(of: presented) { _, shown in if !shown { text = "" } }
            .onChange(of: model.session.selection) { presented = false }
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
