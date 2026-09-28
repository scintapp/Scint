import SwiftUI
import ScintRuntime
import ScintComponents


struct ItemPicker: View {
    let value: String
    let items: [ItemParams]
    let onChange: (ItemParams) -> Void

    var body: some View {
        let selected = items.first { ($0.value ?? "") == value }

        SwiftUI.Menu {
            ForEach(items) { item in
                if let tint = item.tint, !item.image.isEmpty {
                    // A toggle keeps the checkmark in the menu's own column, leaving the icon slot for the tint.
                    Toggle(isOn: Binding(get: { item == selected }, set: { _ in onChange(item) })) {
                        Label { Text(item.name) } icon: { Image(nsImage: Self.tinted(item.image, tint)) }
                    }
                } else {
                    Button { onChange(item) } label: {
                        Text(item.name)
                        if item == selected { Image(systemName: "checkmark") }
                    }
                }
            }
        } label: {
            HStack(alignment: .center) {
                Spacer()
            }
            .frame(maxWidth: 24, maxHeight: 24, alignment: .center)
            .overlay {
                Image(systemName: "chevron.up.chevron.down")
                    .frame(maxWidth: 24, maxHeight: 24, alignment: .center)
            }
        }
        .frame(maxWidth: 24, maxHeight: 24, alignment: .center)
        .menuStyle(.button)
        .buttonStyle(.borderless)
        .menuIndicator(.hidden)
    }

    /// Menus draw SwiftUI images as templates, so a colored symbol has to arrive as a non-template image.
    private static func tinted(_ symbol: String, _ tint: Color) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(paletteColors: [NSColor(tint)])
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
        image.isTemplate = false
        return image
    }
}

struct ItemDatePicker: View {
    let value: String
    var components: DatePickerComponents = [.date, .hourAndMinute]
    let onChange: (String) -> Void

    private var selection: Binding<Date> {
        Binding(
            get: { Value.formatter.date(from: value) ?? .now },
            set: { onChange(Value.formatter.string(from: $0)) }
        )
    }

    var body: some View {
        DatePicker("", selection: selection, displayedComponents: components)
            .datePickerStyle(.stepperField)
            .labelsHidden()
            .font(.system(size: 12))
            .foregroundStyle(Style.Foreground.secondary)
            .fixedSize()
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
        HStack(spacing: 8) {
            Spacer(minLength: 0)

            let step = step(for: Self.track)

            ZStack(alignment: .leading) {
                Capsule().fill(Style.Background.selection)

                ForEach(Array(items.indices), id: \.self) { notch in
                    Circle()
                        .fill(Style.Foreground.secondary)
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

struct TranscriptPicker: View {
    var model: any Model

    @State private var hovered = false

    var body: some View {
        if let context = model.session.transcripts.first,
           let selected = model.session.transcript,
           let space = model.session.selection.structure,
           let composition = Runtime.shared.resolve(space) {
            let branches: [(ref: Reference, intent: Intent)] = Transcript.with(context, { record in
                record.entries.compactMap { entry in
                    guard case .transcript(let ref, let intent, _) = entry else { return nil }
                    return (ref, intent)
                }
            }) ?? []

            HStack(spacing: hovered ? 8 : 0) {
                if hovered || selected == context {
                    Button { model.select(context) } label: {
                        Text("Thread")
                            .font(Typography.body.weight(selected == context ? .medium : .regular))
                            .foregroundStyle(selected == context ? Style.Foreground.secondary : Style.Foreground.secondary)
                            .lineLimit(1)
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
                                .font(Typography.body.weight(transcript == selected ? .medium : .regular))
                                .foregroundStyle(
                                    enabled
                                    ? transcript == selected
                                    ? Style.Foreground.secondary
                                    : Style.Foreground.secondary
                                    : Style.Foreground.secondary
                                )
                                .lineLimit(1)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!enabled)
                    }
                }
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .fixedSize(horizontal: true, vertical: false)
            .background(Style.Shape.panel.fill(Style.Background.surface))
            .overlay(Style.Shape.panel.stroke(Style.Border.hairline, lineWidth: 1))
            .contentShape(Style.Shape.panel)
            .onHover { isHovered in withAnimation(.smooth(duration: 0.2)) { hovered = isHovered } }
            .animation(.smooth(duration: 0.2), value: hovered)
        }
    }
}

struct ContentPicker: View {
    @Environment(ScintModel.self) var scint
    var content: ContentPanel { scint.studio.content }
    var navigator: StudioNavigator { scint.studio.navigator }

    var selection: Binding<ContentPanel.PanelSurface> {
        Binding(get: { content.surface }, set: { content.surface = $0 })
    }

    var body: some View {
        Picker("Content", selection: selection) {
            ForEach(ContentPanel.PanelSurface.allCases) { surface in
                Text(surface.label).tag(surface)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.secondary)
        .tint(Style.Background.selection)
    }
}

struct NavigatorPicker: View {
    @Environment(ScintModel.self) var scint
    var navigator: StudioNavigator { scint.studio.navigator }

    var selection: Binding<StudioNavigator.PanelSurface> {
        Binding(get: { navigator.surface }, set: { navigator.surface = $0 })
    }

    var body: some View {
        Picker("Content", selection: selection) {
            ForEach(StudioNavigator.PanelSurface.allCases) { surface in
                Image(systemName: surface.image).tag(surface)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .foregroundStyle(Style.Foreground.primary, Style.Foreground.primary, Style.Foreground.secondary)
        .tint(Style.Background.selection)
    }
}
