import SwiftUI


struct SearchSurface<S: Surface>: View {
    @State private var selectedIndex = 0
    private var items: [ItemParams] { params.components.flatMap(\.items) }
    let surface: S
    let params: Params
    let panel: PanelParams
    let controls: Controls

    @ViewBuilder var body: some View {
        switch panel.layout {
            case .fixed: Builder.build(surface, params, controls)
            case .float: Builder.build(surface, controls, view: AnyView(view))
        }
    }

    private var view: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let input = panel.input {
                PaletteInput(
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
                        ForEach(PaletteIndexComponent.index(params.components)) { indexed in
                            PaletteComponent(
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
