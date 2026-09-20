import Foundation
import SwiftUI
import ScintRuntime
import ScintComponents


struct SearchDetail: Query {
    enum Verb: String { case open, execute, insert }

    static func parameters(_ item: ItemParams) -> Params {
        guard let ref = item.ref else { return .init() }
        let structural = ref.type is Space.Type

        func about() -> SectionParams {
            var items: [ItemParams] = [
                .init(key: "kind", name: "Kind", trailingKind: .value, value: ref.type.map { "\($0)" } ?? "Unknown"),
                .init(key: "updated", name: "Updated", trailingKind: .value, value: ref.descriptor.updated.formatted(date: .abbreviated, time: .shortened))
            ]
            if !ref.descriptor.tags.isEmpty {
                items.append(.init(key: "tags", name: "Tags", trailingKind: .value, value: ref.descriptor.tags.sorted().joined(separator: ", ")))
            }
            return .init(id: "about", name: "About", items: items)
        }

        func contents() -> SectionParams {
            let refs = Space.with(ref, { $0.spaces + $0.documents })
            ?? Document.with(ref, { $0.blocks.compactMap { block in
                if case .document(let child) = block { return child }
                if case .command(let child) = block { return child }
                if case .artifact(let child) = block { return child }
                return nil
            }}) ?? []

            return .init(
                id: "contents",
                name: "Contents",
                items: refs.map { child in
                    let icon = Iconography.icon(for: child)
                    return .init(ref: child, name: child.descriptor.name, image: icon.symbol, tint: icon.tint.bright)
                }
            )
        }

        func actions() -> SectionParams {
            var verbs: [Verb] = [.open]
            if structural { verbs.append(.execute) }
            verbs.append(contentsOf: [.insert])

            return .init(
                id: "actions",
                name: "Actions",
                items: verbs.map { verb in
                        .init(
                            ref: ref,
                            key: verb.rawValue,
                            name: verb.rawValue.capitalized,
                            image: image(verb),
                            trailingKind: .button
                        )
                }
            )
        }

        func image(_ verb: Verb) -> String {
            switch verb {
                case .open: "arrow.up.forward.square"
                case .execute: "play"
                case .insert: "text.insert"
            }
        }

        return .init(
            ref: ref,
            name: ref.descriptor.name,
            description: ref.descriptor.description,
            sections: [about(), actions()].filter { !$0.items.isEmpty }
        )
    }

    static func perform(_ item: ItemParams, _ model: any Model) {
        guard let ref = item.ref, let key = item.key, let verb = Verb(rawValue: key) else { return }

        switch verb {
            case .open: model.open(ref)
            case .execute: _ = Runtime.shared.start(ref)
            case .insert:
                Space.with(model.session.space, { $0 })?.add(ref)
        }
    }
}

@Observable final class SearchPanel: Panel {
    var mode: Modality = .fixed
    var state: PanelState = .init()

    var surface: PanelSurface {
        get { PanelSurface(rawValue: state.surface) ?? .everything }
        set { state.surface = newValue.rawValue }
    }

    enum PanelSurface: String, CaseIterable {
        case everything, content, interfaces, space

        var label: String { self.rawValue.capitalized }
        var placeholder: String { label }

        var image: String {
            switch self {
                case .everything: "magnifyingglass"
                case .content: "command"
                case .interfaces: "switch.2"
                case .space: "cube.transparent"
            }
        }

        var query: any Query.Type {
            switch self {
                case .everything: EverythingSearch.self
                case .content: ContentSearch.self
                case .interfaces: InterfaceSearch.self
                case .space: WorkspaceSearch.self
            }
        }
    }

    func controls(_ model: Model) -> Controls { surface.query.controls(model) }

    func parameters(_ model: Model) -> Params {
        let content = surface.query.parameters(model)
        let surfaces = PanelSurface.allCases.map { ItemParams(key: $0.rawValue, name: $0.label, image: $0.image) }

        return .init(
            id: PanelKey.search.id,
            layout: content.layout,
            header: content.header,
            panel: .init(
                key: .search,
                sizing: .init(size: .init(width: 640, height: 480)),
                input: .init(key: "query", name: surface.placeholder, image: surface.image),
                items: surfaces,
                selection: surfaces.first { $0.key == surface.rawValue },
                dismissal: [.escape, .outsideClick],
                movable: true,
                resizable: false,
                pinnable: false
            ),
            sections: content.sections
        )
    }

    func surface(_ model: any Model) -> some View { AnySurface(panel: self, model: model) }
}
