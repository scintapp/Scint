import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SearchContent: View {
    var panel: SearchPanel
    var model: any Model

    var state: PanelState { panel.state }
    var surface: SearchPanel.PanelSurface { panel.surface }
    var surfaces: [SearchPanel.PanelSurface] { SearchPanel.PanelSurface.allCases }

    var groups: [(name: String, results: [SearchResult])] {
        surface.groups
            .map { (name: $0.name, results: model.search(state.query, filters: [$0.filter], limit: surface.limit).all) }
            .filter { !$0.results.isEmpty }
    }

    private func open(_ ref: Reference) {
        if ref.type is any ScintRuntime.Material.Type { model.open(ref) }
        else { model.select(ref) }
    }

    private func change(_ index: Int) {
        panel.surface = surfaces[index]
        state.query = ""
        state.cursor = nil
    }

    var body: some View {
        let groups = self.groups
        let results = groups.flatMap(\.results)
        let cursor = state.cursor ?? results.first?.ref
        let selection = results.first { $0.ref == cursor }

        let move: (Int) -> KeyPress.Result = { delta in
            guard !results.isEmpty else { return .handled }
            let current = results.firstIndex { $0.ref == cursor } ?? 0
            state.cursor = results[(current + delta + results.count) % results.count].ref
            return .handled
        }

        PanelView {
            if state.detail, let selection {
                SearchDetail(ref: selection.ref, model: model)
            } else {
                PanelInput(
                    value: panel.bindable.query,
                    image: surface.image,
                    placeholder: surface.placeholder,
                    onUpArrow: { move(-1) },
                    onDownArrow: { move(+1) },
                    onReturn: {
                        if let selection { open(selection.ref) }
                        return .handled
                    },
                    onTab: {
                        guard selection != nil else { return .ignored }
                        state.detail.toggle()
                        return .handled
                    }
                )

                PanelModes(modes: surfaces.map { ($0.label, $0.image) }, selection: surfaces.firstIndex(of: surface) ?? 0) { change($0) }

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(groups, id: \.name) { group in
                                VStack(spacing: 0) {
                                    if !group.name.isEmpty { PanelHeader(name: group.name) }
                                    ForEach(group.results) { result in
                                        let icon = Iconography.icon(for: result.ref)
                                        PanelRow(
                                            name: result.name,
                                            description: result.description,
                                            image: icon.symbol,
                                            tint: icon.tint,
                                            active: result.ref == cursor || model.session.selection.selected(result.ref)
                                        ) {
                                            state.cursor = result.ref
                                            open(result.ref)
                                        }
                                        .id(result.ref)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                    }
                    .scrollEdgeEffectStyle(.soft, for: .vertical)
                    .onChange(of: cursor) { _, ref in
                        guard let ref else { return }
                        proxy.scrollTo(ref, anchor: .center)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .scintPanelEscape)) { escape in
            guard state.detail else { return }
            (escape.object as? PanelEscapeEvent)?.handled = true
            state.detail = false
        }
        .onChange(of: state.query) { _, _ in state.cursor = nil }
        .background { PanelShortcuts(count: surfaces.count) { change($0) } }
    }
}
