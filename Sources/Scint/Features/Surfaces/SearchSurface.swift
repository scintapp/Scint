import SwiftUI


struct PanelRow: View {
    let name: String
    let description: String
    let image: String
    let tint: Color
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            Iconography.Icon(
                symbol: image.isEmpty ? "square.stack.3d.up" : image,
                tint: tint,
                sizing: 20,
                selected: isSelected
            )
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected
                        ? Design.Foreground.primary
                        : Design.Foreground.secondary
                    )
                    .lineLimit(1)

                if !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundStyle(Design.Foreground.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if isSelected {
                Image(systemName: "return")
                    .padding(.trailing, 8)
                    .font(.system(size: 13))
                    .foregroundStyle(Design.Foreground.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .animation(.easeOut(duration: 0.1), value: isSelected)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(
                    isSelected
                    ? Design.Foreground.accent.opacity(0.6)
                    : Color.clear
                )
        )
    }
}

struct PanelInput: View {
    @Binding var value: String
    @FocusState var focused: Bool

    let image: String
    let placeholder: String
    var onUpArrow: () -> KeyPress.Result = { .ignored }
    var onDownArrow: () -> KeyPress.Result = { .ignored }
    var onReturn: () -> KeyPress.Result = { .ignored }
    var onTab: () -> KeyPress.Result = { .ignored }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 16) {
                Image(systemName: image)
                    .frame(height: 48, alignment: .center)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 26, weight: .light))

                TextField(placeholder, text: $value)
                    .frame(height: 48, alignment: .center)
                    .padding(.bottom, 2)
                    .foregroundStyle(Design.Foreground.tertiary)
                    .font(.system(size: 28, weight: .light))
                    .textFieldStyle(.plain)
                    .onKeyPress(.upArrow) { onUpArrow() }
                    .onKeyPress(.downArrow) { onDownArrow() }
                    .onKeyPress(.return) { onReturn() }
                    .onKeyPress(.tab) { onTab() }
                    .focused($focused)
            }
            .frame(height: 48)

            Rectangle()
                .frame(maxWidth: .infinity, maxHeight: 0.5)
                .padding(.horizontal, 4)
                .opacity(0.17)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
        .onAppear { focused = true }
        .onChange(of: placeholder) { _, _ in focused = true }
    }
}

struct SearchSurface: Surface {
    var panel: any Panel
    let model: any Model

    private var search: SearchPanel { panel as! SearchPanel }

    var body: some View {
        let search = self.search
        let params = panel.parameters(model)
        let controls = panel.controls(model)
        let items = params.components.flatMap(\.items)
        let surfaces = params.panel?.items ?? []
        let selection = params.panel?.selection
        let surfaceIndex = surfaces.firstIndex { $0.id == selection?.id } ?? 0

        func move(_ delta: Int) {
            guard !items.isEmpty else { return }
            panel.state.index = (panel.state.index + delta + items.count) % items.count
        }

        func commit() {
            guard items.indices.contains(panel.state.index) else { return }
            let item = items[panel.state.index]
            if let onAction = controls.onAction { onAction(item) }
            else { controls.onSelect?(item) }
        }

        func selectSurface(_ index: Int) {
            guard surfaces.indices.contains(index) else { return }
            let target = surfaces[index]
            controls.onChange?(selection ?? target, target)
        }

        func cycleSurface() -> KeyPress.Result {
            guard surfaces.count > 1 else { return .ignored }
            selectSurface((surfaceIndex + 1) % surfaces.count)
            return .handled
        }

        return VStack(alignment: .leading, spacing: 0) {
            if let input = params.panel?.input {
                PanelInput(
                    value: Binding(
                        get: { panel.state.query },
                        set: { controls.onValueChange?(input, $0) }
                    ),
                    image: input.image,
                    placeholder: input.name,
                    onUpArrow: { move(-1); return .handled },
                    onDownArrow: { move(+1); return .handled },
                    onReturn: { commit(); return .handled },
                    onTab: cycleSurface
                )
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(params.components.enumerated()), id: \.element.id) { componentIndex, component in
                            if !component.items.isEmpty {
                                if component.header && !component.name.isEmpty {
                                    Text(component.name)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.top, 12)
                                        .padding(.bottom, 6)
                                }

                                let startIndex = params.components.prefix(componentIndex).reduce(0) { $0 + $1.items.count }
                                ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                                    let absoluteIndex = startIndex + offset
                                    PanelRow(
                                        name: item.name,
                                        description: item.description,
                                        image: item.image,
                                        tint: item.tint ?? Design.Tint.active,
                                        isSelected: absoluteIndex == panel.state.index,
                                        onTap: {
                                            panel.state.index = absoluteIndex
                                            controls.onSelect?(item)
                                        }
                                    )
                                    .id(item.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: panel.state.index) { _, newIndex in
                    guard items.indices.contains(newIndex) else { return }
                    proxy.scrollTo(items[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: panel.state.query) { _, _ in panel.state.index = 0 }
        .onChange(of: search.mode) { _, _ in panel.state.index = 0 }
        .background {
            ZStack {
                ForEach(0..<min(surfaces.count, 9), id: \.self) { index in
                    Button { selectSurface(index) } label: { EmptyView() }
                        .keyboardShortcut(
                            KeyEquivalent(Character(String(index + 1))),
                            modifiers: .command
                        )
                }
            }
            .frame(width: 0, height: 0)
            .opacity(0)
        }
    }
}
