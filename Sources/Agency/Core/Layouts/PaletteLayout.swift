import SwiftUI


private struct ActionsIndexComponent: Identifiable {
    let component: ComponentParams
    let startIndex: Int

    var id: AnyHashable { component.id }

    static func index(_ components: [ComponentParams]) -> [ActionsIndexComponent] {
        var offset = 0
        return components.map { component in
            defer { offset += component.items.count }
            return ActionsIndexComponent(component: component, startIndex: offset)
        }
    }
}

private struct ActionsRow: View {
    let item: ItemParams
    let isSelected: Bool
    let onTap: () -> Void

    @ViewBuilder private var icon: some View {
        if let ref = item.ref {
            Iconography.Icon(
                symbol: Iconography.symbol(for: ref),
                tint: Iconography.accent(for: ref),
                sizing: 20,
                selected: isSelected
            )
        } else {
            Iconography.Icon(
                symbol: item.image.isEmpty ? "square.stack.3d.up" : item.image,
                tint: Design.Tint.active,
                sizing: 20,
                selected: isSelected
            )
        }
    }

    var body: some View {
        HStack(alignment: .center) {
            icon
                .frame(width: 34, height: 34, alignment: .center)
                .padding(.leading, 2)
                .padding(.trailing, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 16, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(
                        isSelected
                        ? Design.Foreground.primary
                        : Design.Foreground.secondary
                    )
                    .lineLimit(1)

                if !item.description.isEmpty {
                    Text(item.description)
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
                    ? Design.Foreground.quaternary.opacity(0.3)
                    : Color.clear
                )
        )
    }
}

private struct ActionsInput: View {
    @Binding var value: String
    @FocusState private var focused: Bool

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

private struct ActionsComponent: View {
    let component: ComponentParams
    let startIndex: Int
    let selectedIndex: Int
    let controls: Controls
    let onSelectIndex: (Int) -> Void

    var body: some View {
        if !component.items.isEmpty {
            if component.header && !component.name.isEmpty {
                Text(component.name)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.top, 12)
                    .padding(.bottom, 6)
            }

            ForEach(Array(component.items.enumerated()), id: \.element.id) { offset, item in
                let absoluteIndex = startIndex + offset
                ActionsRow(
                    item: item,
                    isSelected: absoluteIndex == selectedIndex,
                    onTap: {
                        onSelectIndex(absoluteIndex)
                        controls.onSelect?(item)
                    }
                )
                .id(item.id)
            }
        }
    }
}

struct ActionsSurface<S: Surface>: View {
    let surface: S
    let params: Params
    let panel: PanelParams
    let controls: Controls

    @State private var selectedIndex = 0

    private var items: [ItemParams] { params.components.flatMap(\.items) }

    @ViewBuilder var body: some View {
        switch panel.layout {
            case .fixed: Builder.build(surface, params, controls)
            case .float: Builder.build(surface, controls, view: AnyView(view))
        }
    }

    private var view: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let input = panel.input {
                ActionsInput(
                    value: inputBinding(input),
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
                        ForEach(ActionsIndexComponent.index(params.components)) { indexed in
                            ActionsComponent(
                                component: indexed.component,
                                startIndex: indexed.startIndex,
                                selectedIndex: selectedIndex,
                                controls: controls,
                                onSelectIndex: { selectedIndex = $0 }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
                .onChange(of: selectedIndex) { _, newIndex in
                    guard items.indices.contains(newIndex) else { return }
                    proxy.scrollTo(items[newIndex].id, anchor: .center)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onChange(of: panel.input?.value) { _, _ in selectedIndex = 0 }
        .onChange(of: panel.selection?.id) { _, _ in selectedIndex = 0 }
        .background { shortcuts }
    }

    private var shortcuts: some View {
        ZStack {
            ForEach(Array(panel.items.prefix(9).enumerated()), id: \.element.id) { index, target in
                Button { selectSurface(target) } label: { EmptyView() }
                    .keyboardShortcut(
                        KeyEquivalent(Character(String(index + 1))),
                        modifiers: .command
                    )
            }
        }
        .frame(width: 0, height: 0)
        .opacity(0)
    }

    private func inputBinding(_ input: ItemParams) -> Binding<String> {
        Binding(
            get: { input.value ?? "" },
            set: { controls.onValueChange?(input, $0) }
        )
    }

    private func move(_ delta: Int) {
        guard !items.isEmpty else { return }
        selectedIndex = (selectedIndex + delta + items.count) % items.count
    }

    private func commit() {
        guard items.indices.contains(selectedIndex) else { return }
        let item = items[selectedIndex]
        if let onAction = controls.onAction { onAction(item) }
        else { controls.onSelect?(item) }
    }

    private func cycleSurface() -> KeyPress.Result {
        guard panel.items.count > 1 else { return .ignored }
        let currentIndex = panel.items.firstIndex { $0.id == panel.selection?.id } ?? 0
        let next = panel.items[(currentIndex + 1) % panel.items.count]
        selectSurface(next)
        return .handled
    }

    private func selectSurface(_ target: ItemParams) {
        controls.onChange?(panel.selection ?? target, target)
    }
}
