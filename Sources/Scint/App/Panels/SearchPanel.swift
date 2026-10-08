import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SearchDetail: Surface {
    var ref: Reference
    var host: any Host
    var model: any Model

    enum Verb: String, CaseIterable {
        case open, execute, insert

        var image: String {
            switch self {
                case .open: "arrow.up.forward.square"
                case .execute: "play"
                case .insert: "text.insert"
            }
        }
    }

    var kind: String { ref.type.map { "\($0)" } ?? "Unknown" }
    var updated: String { ref.descriptor.updated.formatted(date: .abbreviated, time: .shortened) }
    var tags: String { ref.descriptor.tags.sorted().joined(separator: ", ") }
    var verbs: [Verb] { ref.type is Space.Type ? Verb.allCases : [.open, .insert] }

    var body: some View {
        PanelDetail(ref) {
            VStack(spacing: 0) {
                PanelHeader(name: "About")
                PanelRow(name: "Kind", description: kind) { }
                PanelRow(name: "Updated", description: updated) { }
                if !tags.isEmpty { PanelRow(name: "Tags", description: tags) { } }
            }

            VStack(spacing: 0) {
                PanelHeader(name: "Actions")
                ForEach(verbs, id: \.self) { verb in
                    PanelRow(name: verb.rawValue.capitalized, image: verb.image) {
                        switch verb {
                            case .open: model.open(ref)
                            case .execute: model.compose(ref)
                            case .insert: Space.with(model.session.projects, { $0 })?.add(ref)
                        }
                    }
                }
            }
        }
    }
}

struct SearchContent: View {
    var host: SearchPanel
    var model: any Model

    var state: StateContainer { host.state }
    var surface: SearchPanel.PanelSurface { host.surface }
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
        host.surface = surfaces[index]
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
                SearchDetail(ref: selection.ref, host: host, model: model)
            } else {
                PanelInput(
                    value: host.bindable.query,
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

final class SearchPanel: Panel {
    var state: StateContainer = .init()

    var surface: PanelSurface {
        get { PanelSurface(rawValue: state.surface) ?? .everything }
        set { state.surface = newValue.rawValue }
    }

    enum PanelSurface: String, CaseIterable {
        case everything, content, interfaces, projects

        var label: String { self.rawValue.capitalized }
        var placeholder: String { label }
        var limit: Int { self == .everything ? 50 / 3 : 50 }

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .projects: "cube.transparent"
            }
        }

        var groups: [(name: String, filter: String)] {
            switch self {
                case .everything: [("Content", "document"), ("Interfaces", "interface"), ("Workspace", "structure")]
                case .content: [("", "document")]
                case .interfaces: [("Artifacts", "artifact"), ("Commands", "command"), ("Harnesses", "harness")]
                case .projects: [("", "structure")]
            }
        }
    }

    func parameters(_ model: Model) -> Params {
        .init(
            id: PanelKey.search.id,
            panel: .init(
                key: .search,
                sizing: .init(size: .init(width: 640, height: 480)),
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            )
        )
    }

    func surface(_ model: any Model) -> some View { SearchContent(host: self, model: model) }
}
